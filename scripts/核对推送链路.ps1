# 核对"推送 → 构建"这条链路是否还通（12-01 前随时可以先验一遍）
#
# 为什么有这个脚本：唯一的外部阻塞是 GitHub Actions 的 macOS 额度。
# 额度一恢复，"能不能立刻开工"取决于三件小事有没有坏：
#   ① token 还有效吗   ② 代理通不通   ③ 远端还接受 fast-forward 吗
# 这三件坏任何一件，12-01 那天才发现就要多等一天。
# 本脚本**只做只读 + dry-run**：不会推送、不会触发构建、不改远端任何东西。
#
# 用法：
#   .\scripts\核对推送链路.ps1
#   .\scripts\核对推送链路.ps1 -Proxy "http://127.0.0.1:7897"
param(
    [string]$LocalRepo = "D:\ios-zl2",
    [string]$Repo      = "liyuzs/zl2-ios",
    [string]$Proxy     = "http://127.0.0.1:7897"
)

# 注意：git 会把正常输出（Everything up-to-date、To ...）写到 stderr，
# 所以这里**不能**用 Stop —— 否则 dry-run 成功也会被当成异常抛出。
$ErrorActionPreference = "Continue"

$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) {
    $candidate = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $candidate) { $git = $candidate } else { throw "找不到 git" }
}

# ---------- 1. token ----------
$credFile = Join-Path $env:TEMP "gh-cred.txt"
if (-not (Test-Path $credFile)) { throw "请先把 token 放到 $credFile（一行，40 字符）" }
$token = (Get-Content $credFile -Raw).Trim()
if (-not $token) { throw "$credFile 是空的" }
Write-Host ("[1/3] token 就绪（长度 " + $token.Length + "，正文不打印）")

# ---------- 2. dry-run 推送（只读）----------
$url = "https://liyuzs:" + $token + "@github.com/" + $Repo + ".git"
$head = (& $git -C $LocalRepo rev-parse --short HEAD).Trim()
Write-Host ("[2/3] dry-run 推送（本地 HEAD " + $head + "，不会真的推）")
$out = & $git -c ("http.proxy=" + $Proxy) push --dry-run $url master:main 2>&1
$code = $LASTEXITCODE
$out | ForEach-Object { "    " + ($_ -replace [regex]::Escape($token), "***") }
if ($code -ne 0) {
    Write-Host "    ✗ 失败 —— token / 代理 / 远端 三者之一坏了（代理没开的话先 Start-Process 'C:\Program Files\Clash Verge\clash-verge.exe' 等 25 秒再跑）" -ForegroundColor Red
    exit 1
}
Write-Host "    OK  远端接受这次推送" -ForegroundColor Green

# ---------- 3. 最近几次构建的状态（判断额度是否恢复）----------
Write-Host "[3/3] 最近 3 次 workflow 运行"
$headers = @{
    Authorization = "Bearer " + $token
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}
try {
    $runs = Invoke-RestMethod -Uri ("https://api.github.com/repos/" + $Repo + "/actions/runs?per_page=3") -Headers $headers -Proxy $Proxy -TimeoutSec 30
} catch {
    Write-Host ("    !  查不到运行记录：" + $_.Exception.Message) -ForegroundColor Yellow
    exit 0
}

$okCount = 0; $badCount = 0; $queuedOld = 0; $queuedNew = 0
foreach ($r in $runs.workflow_runs) {
    # GitHub 返回的是 ISO8601 字符串；RoundtripKind 保住 UTC 语义，避免差 8 小时
    $created = [datetime]::Parse($r.created_at, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
    $age = [int][math]::Round(((Get-Date).ToUniversalTime() - $created.ToUniversalTime()).TotalMinutes)
    $conc = $r.conclusion
    if (-not $conc) { $conc = "-" }
    "    #{0}  {1} / {2}  {3}  {4} 分钟前" -f $r.run_number, $r.status, $conc, $r.head_sha.Substring(0,7), $age | Write-Host
    if ($r.status -eq "queued") {
        if ($age -ge 10) { $queuedOld++ } else { $queuedNew++ }
    } elseif ($conc -eq "success") { $okCount++ }
    elseif ($conc -eq "cancelled" -or $conc -eq "failure") { $badCount++ }
}

Write-Host ""
if ($okCount -gt 0) {
    Write-Host "结论：有成功的构建 —— 额度正常，可以真跑一次。" -ForegroundColor Green
    Write-Host "      下一步：.\scripts\推送并取回IPA.ps1 -Token <token>"
} elseif ($queuedOld -gt 0) {
    Write-Host "结论：有构建在队列里排了 10 分钟以上还没拿到 macOS runner —— 额度仍然紧张。" -ForegroundColor Yellow
    Write-Host "      链路本身没问题（上面 dry-run 已过）。等 12-01 额度刷新，或改用 Codemagic。"
} elseif ($badCount -eq 3) {
    Write-Host "结论：最近 3 次全被取消/失败 —— 额度大概率还没恢复（12-01 刷新）。" -ForegroundColor Yellow
    Write-Host "      链路本身没问题（上面 dry-run 已过），只是没有 macOS runner 可用。"
} else {
    Write-Host "结论：最近的运行刚触发（还在队列前段），过几分钟再跑一次本脚本看看。" -ForegroundColor Yellow
}
