# 推送并取回 IPA（一条命令解决「推不上去」）
#
# 为什么有这个脚本：
#   这个项目卡在「本地有 120+ 个提交，线上还停在 build-235」已经八十多轮了。
#   阻断点只是一件事 —— GitHub 不再接受密码认证，必须有 token。
#   而拿到 token 之后要做的事有四五步（推、等构建、下载、校验、替换交付包 IPA），
#   每步都可能因为记错命令而卡住。所以把它做成一条命令。
#
# 用法：
#   .\推送并取回IPA.ps1 -Token "github_pat_xxxxx"
#   .\推送并取回IPA.ps1 -Token "..." -NoProxy          # 没开 Clash 时
#   .\推送并取回IPA.ps1 -Token "..." -TimeoutMinutes 40
#
# 它做什么：
#   1. 检查工作区干净（脏的话先提示，不硬推）
#   2. 推 master → 线上 main
#   3. 轮询 GitHub Actions，等 iOS Build 结束
#   4. 下载 artifact 里的 ZL2.ipa
#   5. 校验体积（< 100MB 视为 JRE 没打进去，直接失败，不覆盖旧包）
#   6. 备份并替换交付包里的 ZL2.ipa，更新交付包「项目状态-当前.md」

param(
    [Parameter(Mandatory = $true)]
    [string]$Token,

    [string]$Repo        = "liyuzs/zl2-ios",
    [string]$LocalRepo   = "D:\ios-zl2",
    [string]$DeliveryDir = "D:\ZL2-iOS交付包",
    [string]$Proxy       = "http://127.0.0.1:7897",
    [int]$TimeoutMinutes = 45,   # 与 CI 的 timeout-minutes: 45 对齐
    [int]$MinIpaMB       = 100,
    [switch]$NoProxy
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # Invoke-WebRequest 不带进度条会快很多

function Write-Step($n, $text) { Write-Host "`n[$n] $text" -ForegroundColor Cyan }
function Write-Ok($text)      { Write-Host "    OK  $text" -ForegroundColor Green }
function Write-Warn2($text)   { Write-Host "    !   $text" -ForegroundColor Yellow }

$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) {
    $candidate = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $candidate) { $git = $candidate } else { throw "找不到 git，请先安装 Git for Windows" }
}

$proxyArg = @()
if (-not $NoProxy) { $proxyArg = @("-c", "http.proxy=$Proxy") }

# ---------- 1. 工作区必须干净 ----------
Write-Step 1 "检查工作区"
$dirty = & $git -C $LocalRepo status --porcelain
if ($dirty) {
    Write-Warn2 "工作区有未提交的改动："
    $dirty | ForEach-Object { Write-Host "        $_" }
    throw "先提交或 stash，再运行本脚本（避免把半成品推上去）"
}
$ahead = (& $git -C $LocalRepo rev-list --count HEAD).Trim()
Write-Ok "干净，本地共 $ahead 个提交"

# ---------- 2. 推送 ----------
Write-Step 2 "推送 master → 线上 main"
$url = "https://${Token}@github.com/$Repo.git"
# 用 -c 传 token 而不是改 remote，避免 token 落进 .git/config
& $git -c "http.proxy=$Proxy" -C $LocalRepo push $url master:main 2>&1 |
    ForEach-Object { Write-Host "    $_" }
if ($LASTEXITCODE -ne 0) {
    if ($NoProxy) { throw "推送失败（已按 -NoProxy 直连）。检查 token 权限：Contents = Read and write" }
    throw "推送失败。检查 token 权限（Contents: Read and write），或网络/代理是否可用（当前 $Proxy）"
}
Write-Ok "推送完成"

# ---------- 3. 等 Actions ----------
Write-Step 3 "等待 GitHub Actions「iOS Build」"
$apiHeaders = @{
    Authorization          = "Bearer $Token"
    Accept                 = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}
$ireq = @{ Uri = "https://api.github.com/repos/$Repo/actions/runs?per_page=5"; Headers = $apiHeaders }
if (-not $NoProxy) { $ireq.Proxy = $Proxy }

$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
$run = $null
while ((Get-Date) -lt $deadline) {
    try {
        $runs = Invoke-RestMethod @ireq
        $cand = $runs.workflow_runs | Where-Object { $_.head_branch -eq "main" } | Select-Object -First 1
        if ($cand) {
            $run = $cand
            Write-Host "    run #$($run.run_number)  $($run.status) / $($run.conclusion)"
            if ($run.status -eq "completed") { break }
        } else {
            Write-Host "    还没看到 main 分支的 run，等 20 秒…"
        }
    } catch {
        Write-Host "    查询失败，稍后重试：$($_.Exception.Message)"
    }
    Start-Sleep -Seconds 20
}

if (-not $run) { throw "超过 $TimeoutMinutes 分钟没等到构建，去 $Repo/actions 看看（CI 自身上限也是 45 分钟）" }
if ($run.conclusion -ne "success") {
    # **先分清「额度/队列取消」和「真的编译失败」** —— 两者的 conclusion 都不是 success，
    # 但提示必须不同：一次从来没跑过的构建，让人去看 "Static checks" 的日志等于把人送进死胡同
    # （那一步的日志根本不存在，拉下来是 404）。第519轮总结的判据：
    #   job 的 steps 数为 0 且 runner_name 为空 → 一条都没跑过 = 平台层问题。
    $jobsReq = @{ Uri = "https://api.github.com/repos/$Repo/actions/runs/$($run.id)/jobs"; Headers = $apiHeaders }
    if (-not $NoProxy) { $jobsReq.Proxy = $Proxy }
    $jobInfo = $null
    try { $jobInfo = @((Invoke-RestMethod @jobsReq).jobs)[0] } catch { }
    $neverRan = $false
    if ($jobInfo) {
        if ((@($jobInfo.steps).Count -eq 0) -and (-not $jobInfo.runner_name)) { $neverRan = $true }
    }
    if ($neverRan) {
        throw ("这次构建被取消了，而且那个 job 一条步骤都没跑过（steps = 0、runner_name 为空）—— 这不是代码问题。" +
               "最可能是 GitHub Actions 的 macOS 额度用完了（macOS 按 10 倍计费，额度每月 1 日刷新，见 STATUS 第七点五节）。" +
               "另两条路：改用 Codemagic（codemagic.yaml 已就绪），或等额度刷新后重跑本脚本。")
    }
    throw ("构建没成功（conclusion = $($run.conclusion)）。可能是编译前的静态检查没过。" + "打开 $($run.html_url) 先看 `"Static checks`" 那一步的日志")
}
Write-Ok "构建成功：$($run.html_url)"

# ---------- 4. 下载 artifact ----------
Write-Step 4 "下载 IPA"
$areq = @{ Uri = "https://api.github.com/repos/$Repo/actions/runs/$($run.id)/artifacts"; Headers = $apiHeaders }
if (-not $NoProxy) { $areq.Proxy = $Proxy }
$arts = Invoke-RestMethod @areq
$art = $arts.artifacts | Where-Object { $_.name -eq "ZL2-build" } | Select-Object -First 1
if (-not $art) {
    $names = ($arts.artifacts | ForEach-Object { $_.name }) -join ", "
    throw "这次构建没有可下载的产物（有：$names）"
}

$tmpZip = Join-Path $env:TEMP "zl2-artifact-$($run.run_number).zip"
$dreq = @{ Uri = $art.archive_download_url; Headers = $apiHeaders; OutFile = $tmpZip }
if (-not $NoProxy) { $dreq.Proxy = $Proxy }
Invoke-RestMethod @dreq
Write-Ok "已下载 $($art.name)（$([math]::Round((Get-Item $tmpZip).Length/1MB,1)) MB 压缩包）"

$unzip = Join-Path $env:TEMP "zl2-artifact-$($run.run_number)"
if (Test-Path $unzip) { Remove-Item $unzip -Recurse -Force }
Expand-Archive -Path $tmpZip -DestinationPath $unzip -Force
$ipa = Get-ChildItem $unzip -Filter *.ipa -Recurse | Sort-Object Length -Descending | Select-Object -First 1
if (-not $ipa) { throw "解压后没找到 .ipa" }

# ---------- 5. 体积校验 ----------
Write-Step 5 "校验体积"
$mb = [math]::Round($ipa.Length / 1MB, 1)
if ($mb -lt $MinIpaMB) {
    throw "IPA 只有 $mb MB（应大于 $MinIpaMB MB）。这说明 JRE 没打进包里 —— 不要用它替换交付包。"
}
Write-Ok "$mb MB，符合预期"

# ---------- 5.5 内容核对 ----------
# 体积只是个粗代理：缺一整套 JRE 也还有 100 MB 出头，可那个版本的 MC 直接起不来。
# 所以下载完再核一遍内容（条目 / 主程序 / 渲染库 / 三套 JRE / 启动器 jar / log4j / JIT / 版本号）。
Write-Step "5.5" "核对 IPA 内容"
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { throw "找不到 node —— 无法核对 IPA 内容（请先装 Node.js）" }
& $node (Join-Path $LocalRepo "scripts\verify-ipa.js") $ipa.FullName
if ($LASTEXITCODE -ne 0) {
    throw "IPA 内容不对（缺运行时 / 渲染库 / 启动器 jar / 版本号）—— 不要用它替换交付包，先看上面哪一项失败。"
}

# ---------- 6. 替换交付包 ----------
Write-Step 6 "替换交付包里的旧 IPA"
$target = Join-Path $DeliveryDir "ZL2.ipa"
if (Test-Path $target) {
    $bak = Join-Path $DeliveryDir ("ZL2.旧-build235-" + (Get-Date -Format "yyyyMMdd-HHmm") + ".ipa")
    Move-Item $target $bak
    Write-Ok "旧的已备份为 $(Split-Path $bak -Leaf)"
}
Copy-Item $ipa.FullName $target
Write-Ok "已放入 $target"

# 交付包状态里记一笔
$statusPath = Join-Path $DeliveryDir "项目状态-当前.md"
if (Test-Path $statusPath) {
    $line = "`n> 交付包 IPA 已更新：$(Get-Date -Format 'yyyy-MM-dd HH:mm')，来自 run #$($run.run_number)（$mb MB）`n"
    Add-Content -Path $statusPath -Value $line -Encoding UTF8
    Write-Ok "已记录到 项目状态-当前.md"
}

Write-Host ""
Write-Host "全部完成。下一步：把 D:\ZL2-iOS交付包\ZL2.ipa 发给朋友，让他按「真机验证清单」走一遍。" -ForegroundColor Green
Write-Host "           重点看启动前预检那张卡片有没有红色的。" -ForegroundColor Green
