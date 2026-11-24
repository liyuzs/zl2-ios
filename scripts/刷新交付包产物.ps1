# 刷新交付包的源码类产物（bundle + 源码 zip），让它们和当前 HEAD 对齐
#
# 为什么有这个脚本：交付包里的 `zl2-ios-完整仓库.bundle` 与 `zl2-ios-源码.zip`
# 是 build-243 那天生成的，之后仓库往前走了十几个提交，而文档还写着"全部提交历史"。
# 这两个文件随时能重新生成，落后没有任何理由。`_check-delivery-docs.js` 会拿
# bundle 里的 HEAD 和 zip 里的 CHANGELOG.md 对撞，落后就报（第534轮加的）。
#
# 用法：
#   .\scripts\刷新交付包产物.ps1
#   .\scripts\刷新交付包产物.ps1 -DeliveryDir "E:\别的交付包"
param(
    [string]$LocalRepo   = "D:\ios-zl2",
    [string]$DeliveryDir = "D:\ZL2-iOS交付包"
)
$ErrorActionPreference = "Stop"

$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if (-not $git) {
    $candidate = "C:\Program Files\Git\cmd\git.exe"
    if (Test-Path $candidate) { $git = $candidate } else { throw "找不到 git" }
}

$head = (& $git -C $LocalRepo rev-parse HEAD).Trim()
Write-Host "[1/3] 当前 HEAD = $head"

$dirty = & $git -C $LocalRepo status --porcelain
if ($dirty) {
    Write-Host "工作区有未提交的改动 —— bundle/zip 只包含已提交的内容（HEAD）。确认不是半成品：" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "    $_" }
}

$bundle = Join-Path $DeliveryDir "zl2-ios-完整仓库.bundle"
$zip    = Join-Path $DeliveryDir "zl2-ios-源码.zip"
if (-not (Test-Path $DeliveryDir)) { throw "交付包目录不存在：$DeliveryDir" }

Write-Host "[2/3] 生成 bundle（全部历史）…"
# **不要用 --all**：本机还留着 `remote-main-backup`（第10轮那个独立起源的远端历史），
# 它的父提交在这台机器上不全 —— 打进去之后 `git bundle verify` 仍说"完整"，
# 但 `git clone` 会失败：`Failed to traverse parents of commit ...`（第534轮实测）。
# 所以只打真正的历史线：master。
& $git -C $LocalRepo bundle create $bundle master
if ($LASTEXITCODE -ne 0) { throw "git bundle create 失败" }

Write-Host "[3/3] 生成源码 zip（HEAD 快照）…"
if (Test-Path $zip) { Remove-Item $zip -Force }
& $git -C $LocalRepo archive --format=zip --output=$zip HEAD
if ($LASTEXITCODE -ne 0) { throw "git archive 失败" }

# 自检：bundle 里的 HEAD 必须就是刚才那个（不信"看起来成功了"）
# 只打 master 的 bundle 里没有名为 HEAD 的 ref —— 所以判「有没有当前 HEAD」：
# 任何一条 ref 的 sha 等于仓库 HEAD 即可（`git bundle verify` 通过不代表能克隆，下一段还要真克隆一次）。
$heads = & $git -C $LocalRepo bundle list-heads $bundle
if (-not ($heads -match [regex]::Escape($head))) { throw "bundle 里没有当前 HEAD（$($head.Substring(0,7))）：$heads" }

# 自检二：**真的克隆一次**。`git bundle verify` 通过不代表能克隆（第534轮实测）。
$tmp = Join-Path $env:TEMP ("zl2-bundle-check-" + (Get-Date -Format "HHmmss"))
try {
    & $git clone --no-checkout --quiet $bundle $tmp 2>$null
    if ($LASTEXITCODE -ne 0) { throw "bundle 克隆失败 —— 这个 bundle 不能交付" }
    $cloneHead = (& $git -C $tmp rev-parse HEAD).Trim()
    if ($cloneHead -ne $head) { throw "克隆出来的 HEAD 是 $cloneHead，与仓库 $head 不一致" }
    $cloneCount = (& $git -C $tmp rev-list --count HEAD).Trim()
    Write-Host "      克隆自检通过：$cloneCount 个提交，HEAD $($cloneHead.Substring(0,7))" -ForegroundColor Green
} finally {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
$bmb = [math]::Round((Get-Item $bundle).Length / 1MB, 1)
$zmb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host ("完成：bundle {0} MB · 源码 zip {1} MB · HEAD {2}" -f $bmb, $zmb, $head.Substring(0, 7)) -ForegroundColor Green
Write-Host "下一步：node tools\config-guard\_check-delivery-docs.js 应当不再报"落后"。" -ForegroundColor Green
