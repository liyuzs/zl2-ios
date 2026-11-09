. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
$model = Join-Path $d 'src\ControlLayoutModel.swift'
$export = Join-Path $d 'src\CoreLayoutExport.swift'

$modelText = Get-Content $model -Raw -Encoding UTF8

# 从 CoreLayoutExport.swift 里抽出所有对控件属性的访问（btn.xxx / txt.xxx / joy.xxx / s.xxx / size.xxx）
$exportText = Get-Content $export -Raw -Encoding UTF8
$accessors = [regex]::Matches($exportText, '\b(?:btn|txt|joy|s|size|style|cfg|js|ev|sub|text)\."?([a-zA-Z][a-zA-Z0-9_]*)') |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

Write-Output "=== 检查这些属性是否在模型里定义 ==="
$missing = @()
foreach ($a in $accessors) {
    # 在模型文件里找 `var <name>` 或 `let <name>` 或 `func <name>`
    $hit = $modelText -match ('(var|let|func)\s+' + [regex]::Escape($a) + '\b')
    if (-not $hit) {
        Write-Output ("  ?? " + $a)
        $missing += $a
    }
}
if ($missing.Count -eq 0) { Write-Output "  全部属性都能在模型里找到" }
else { Write-Output ("  共 " + $missing.Count + " 个未在模型里找到（可能是我用错了，也可能是工具自带的）") }

Write-Output ""
Write-Output "=== 括号检查 ==="
$o = ([regex]::Matches($exportText, '\{')).Count
$c = ([regex]::Matches($exportText, '\}')).Count
Write-Output ("  { = $o   } = $c")
