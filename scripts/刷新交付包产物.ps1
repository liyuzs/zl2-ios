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
& $git -C $LocalRepo bundle create $bundle --all
if ($LASTEXITCODE -ne 0) { throw "git bundle create 失败" }

Write-Host "[3/3] 生成源码 zip（HEAD 快照）…"
if (Test-Path $zip) { Remove-Item $zip -Force }
& $git -C $LocalRepo archive --format=zip --output=$zip HEAD
if ($LASTEXITCODE -ne 0) { throw "git archive 失败" }

# 自检：bundle 里的 HEAD 必须就是刚才那个（不信"看起来成功了"）
$heads = & $git -C $LocalRepo bundle list-heads $bundle
$line = $heads | Where-Object { $_ -match "\sHEAD$" } | Select-Object -First 1
if (-not $line) { throw "bundle 里读不到 HEAD" }
if ($line -notmatch [regex]::Escape($head)) { throw "bundle 的 HEAD 和仓库不一致：$line" }

$bmb = [math]::Round((Get-Item $bundle).Length / 1MB, 1)
$zmb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host ("完成：bundle {0} MB · 源码 zip {1} MB · HEAD {2}" -f $bmb, $zmb, $head.Substring(0, 7)) -ForegroundColor Green
Write-Host "下一步：node tools\config-guard\_check-delivery-docs.js 应当不再报"落后"。" -ForegroundColor Green
