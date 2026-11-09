. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
Write-Output "=== 第 7 轮：死代码清理 + 孤儿组件启用 ==="
Write-Output ""

Write-Output "[1] 挂载验证"
$checks = @(
    @{ n = 'SplashScreen 挂载';  f = 'src\ZL2App.swift'; p = 'SplashScreen {' },
    @{ n = 'WelcomeScreen 挂载'; f = 'src\ZL2App.swift'; p = 'WelcomeScreen {' },
    @{ n = 'mainStack 提取';     f = 'src\ZL2App.swift'; p = 'private var mainStack' }
)
foreach ($c in $checks) {
    $p = Join-Path $d $c.f
    $h = Select-String -Path $p -Pattern ([regex]::Escape($c.p)) -SimpleMatch -ErrorAction SilentlyContinue
    if ($h) { Write-Output ("  OK   " + $c.n) } else { Write-Output ("  MISS " + $c.n) }
}

Write-Output ""
Write-Output "[2] 死代码是否已清除"
$dead = @(
    @{ n = 'ModsScreen';     f = 'src\ModsScreen.swift' },
    @{ n = 'AssetInfoSheet'; f = 'src\ExtraScreens.swift'; p = 'AssetInfoSheet' },
    @{ n = 'LayoutInfoSheet'; f = 'src\ControlEditor.swift'; p = 'LayoutInfoSheet' }
)
foreach ($x in $dead) {
    $p = Join-Path $d $x.f
    if (-not (Test-Path $p)) { Write-Output ("  OK   " + $x.n + " 文件已删除"); continue }
    if ($x.p) {
        $h = Select-String -Path $p -Pattern $x.p -ErrorAction SilentlyContinue
        if ($h) { Write-Output ("  仍在 " + $x.n + " (行 " + $h[0].LineNumber + ")") }
        else { Write-Output ("  OK   " + $x.n + " 已移除") }
    }
}

Write-Output ""
Write-Output "[3] 项目规模"
$sw = Get-ChildItem "$d\src" -Filter '*.swift'
$lines = ($sw | Get-Content | Measure-Object -Line).Lines
Write-Output ("  Swift 文件: " + $sw.Count + " 个")
Write-Output ("  代码行数:   " + $lines + " 行")
$docs = Get-ChildItem "$d\docs" -Filter '*.md'
Write-Output ("  文档:       " + $docs.Count + " 篇")
