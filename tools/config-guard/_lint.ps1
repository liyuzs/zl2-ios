. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
Write-Output "=== 括号平衡全量检查 ==="
$bad = 0
Get-ChildItem "$d\src" -Filter '*.swift' | ForEach-Object {
    $c = Get-Content $_.FullName -Raw -Encoding UTF8
    $o = ([regex]::Matches($c, '\{')).Count
    $cl = ([regex]::Matches($c, '\}')).Count
    $po = ([regex]::Matches($c, '\(')).Count
    $pc = ([regex]::Matches($c, '\)')).Count
    if ($o -ne $cl -or $po -ne $pc) {
        Write-Output ("  BAD  " + $_.Name + "  {=" + $o + "  }=" + $cl + "  (=" + $po + "  )=" + $pc)
        $bad++
    }
}
if ($bad -eq 0) { Write-Output "  全部 61 个文件括号平衡 OK" } else { Write-Output ("  共 " + $bad + " 个文件不平衡") }

Write-Output ""
Write-Output "=== 新增文件检查 ==="
$newFile = Join-Path $d 'src\VersionIconPicker.swift'
if (Test-Path $newFile) {
    $c = Get-Content $newFile -Raw -Encoding UTF8
    Write-Output ("  VersionIconPicker.swift  行数: " + (Get-Content $newFile | Measure-Object -Line).Lines)
    Write-Output ("  {=" + ([regex]::Matches($c, '\{')).Count + "  }=" + ([regex]::Matches($c, '\}')).Count)
} else {
    Write-Output "  文件不存在"
}

Write-Output ""
Write-Output "=== 类型重名检查 ==="
$types = @{}
Get-ChildItem "$d\src" -Filter '*.swift' | ForEach-Object {
    $fn = $_.Name
    Get-Content $_.FullName -Encoding UTF8 | Select-String -Pattern '^(?:public |private |internal )?(?:final )?(?:struct|class|enum|actor|protocol) ([A-Za-z_][A-Za-z0-9_]*)' | ForEach-Object {
        $name = [regex]::Match($_.Line, '(?:struct|class|enum|actor|protocol) ([A-Za-z_][A-Za-z0-9_]*)').Groups[1].Value
        if (-not $types.ContainsKey($name)) { $types[$name] = @() }
        $types[$name] += $fn
    }
}
$dup = $types.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
if ($dup) {
    foreach ($x in $dup) { Write-Output ("  DUP " + $x.Key + " -> " + ($x.Value -join ', ')) }
} else {
    Write-Output ("  无重名，共 " + $types.Count + " 个类型定义")
}
