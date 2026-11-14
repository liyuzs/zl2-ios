# 统一解析仓库路径（PowerShell 版，供各 .ps1 脚本 dot-source）
#
# 与 _paths.js 同一逻辑：让工具集不依赖固定的 D:\ios-zl2。
# 用法：
#     . "$PSScriptRoot\_paths.ps1"
#     Set-Location $ZL2Repo        # 或直接用 $ZL2Repo / $ZL2Src / $ZL2Core

$script:ZL2Repo = $null

if ($env:ZL2_REPO -and (Test-Path (Join-Path $env:ZL2_REPO 'project.yml'))) {
    $script:ZL2Repo = $env:ZL2_REPO
} else {
    $root = $PSScriptRoot
    for ($i = 0; $i -lt 6; $i++) {
        if (Test-Path (Join-Path $root 'project.yml')) { break }
        $parent = Split-Path $root -Parent
        if (-not $parent -or $parent -eq $root) { break }
        $root = $parent
    }
    if (Test-Path (Join-Path $root 'project.yml')) {
        $script:ZL2Repo = $root
    } else {
        $script:ZL2Repo = 'D:\ios-zl2'   # 本机默认（工作副本向上两级不是仓库时走这里）
    }
}

$script:ZL2Src  = Join-Path $script:ZL2Repo 'src'
$script:ZL2Core = Join-Path $script:ZL2Repo 'core'
