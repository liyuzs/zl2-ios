. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
$settingsFile = Join-Path $d 'src\ZLSettings.swift'
$screenFile   = Join-Path $d 'src\SettingsScreen.swift'

# 1. 从 ZLSettings.swift 提取全部 key
$txt = Get-Content $settingsFile -Raw -Encoding UTF8
$keys = [regex]::Matches($txt, '\.init\(key:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
Write-Output ("ZLSettings 定义的设置项: " + $keys.Count + " 个")

# 2. 已标注 unsupported 的
$sc = Get-Content $screenFile -Raw -Encoding UTF8
$blk = [regex]::Match($sc, 'enum ZLUnsupportedSettings[\s\S]*?Set<String>\s*=\s*\[([\s\S]*?)\]')
$declared = @()
if ($blk.Success) { $declared = [regex]::Matches($blk.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } }
Write-Output ("已标注 unsupported: " + $declared.Count + " 个")

# 3. 全部源文件，排除 SettingsScreen / ZLSettings 自身
$others = Get-ChildItem "$d\src" -Filter '*.swift' | Where-Object { $_.Name -notin @('SettingsScreen.swift','ZLSettings.swift') }

$live = @(); $dead = @(); $declDead = @()
foreach ($k in $keys) {
    $pat = '"' + $k + '"'
    $read = 0
    foreach ($f in $others) {
        $hits = Select-String -Path $f.FullName -Pattern ([regex]::Escape($pat)) -SimpleMatch -ErrorAction SilentlyContinue
        foreach ($h in $hits) {
            if ($h.Line -match '\.(string|integer|bool|double|object|array)\(forKey') { $read++ }
        }
    }
    if ($read -gt 0) { $live += $k }
    elseif ($declared -contains $k) { $declDead += $k }
    else { $dead += $k }
}

Write-Output ""
Write-Output ("=== 真正被读取（生效）: " + $live.Count + " 个 ===")
$live | ForEach-Object { Write-Output ("  LIVE  " + $_) }

Write-Output ""
Write-Output ("=== 只写不读，已正确标注: " + $declDead.Count + " 个 ===")

Write-Output ""
Write-Output ("=== 只写不读，但未标注（漏网）: " + $dead.Count + " 个 ===")
$dead | ForEach-Object { Write-Output ("  LEAK  " + $_) }
