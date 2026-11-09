. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
$f = Join-Path $d 'src\ZLStrings.swift'
$c = Get-Content $f -Raw -Encoding UTF8

$open  = ([regex]::Matches($c, '\{')).Count
$close = ([regex]::Matches($c, '\}')).Count
$quote = ([regex]::Matches($c, '"')).Count

Write-Output "=== 文件完整性 ==="
Write-Output ("ZLStrings.swift  { = $open   } = $close   quote = $quote")
if ($open -eq $close) { Write-Output "括号平衡 OK" } else { Write-Output "括号不平衡!" }
if ($quote % 2 -eq 0) { Write-Output "引号成对 OK" } else { Write-Output "引号不成对!" }

Write-Output ""
Write-Output "=== 改动确认 ==="
$keys = @('专为 iOS', 'Amethyst 作为', '跟随系统外观', '图形后端', 'Metal 后端')
foreach ($k in $keys) {
    $hit = Select-String -Path $f -Pattern $k -Encoding UTF8
    if ($hit) {
        Write-Output ("  OK  " + $k + "  ->  行 " + $hit.LineNumber)
    } else {
        Write-Output ("  MISS " + $k)
    }
}

Write-Output ""
Write-Output "=== 残留 Android 文案 ==="
$bad = Select-String -Path $f -Pattern 'Android 设备|Android 12|Adreno|Turnip' -Encoding UTF8
if ($bad) {
    foreach ($b in $bad) { Write-Output ("  行 " + $b.LineNumber + ": " + $b.Line.Trim()) }
} else {
    Write-Output "  已全部清理"
}
