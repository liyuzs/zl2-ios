. "$PSScriptRoot\_paths.ps1"
$d = $ZL2Repo
# 1. 从 ZLUnsupportedSettings 取出已标注的
$sf = Join-Path $d 'src\SettingsScreen.swift'
$src = Get-Content $sf -Raw -Encoding UTF8
$block = [regex]::Match($src, 'enum ZLUnsupportedSettings[\s\S]*?static let keys:\s*Set<String>\s*=\s*\[([\s\S]*?)\]')
$declared = @()
if ($block.Success) {
    $declared = [regex]::Matches($block.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
}
Write-Output ("已标注 unsupported 的设置项: " + $declared.Count + " 个")

# 2. 找出设置页里所有会写入的 key
$allSwift = Get-ChildItem "$d\src" -Filter '*.swift'
$settingKeys = @()
Get-Content $sf -Encoding UTF8 | ForEach-Object {
    $m = [regex]::Matches($_, 'key:\s*"([^"]+)"')
    foreach ($x in $m) { $settingKeys += $x.Groups[1].Value }
}
$settingKeys = $settingKeys | Sort-Object -Unique
Write-Output ("设置页里出现的 key 总数: " + $settingKeys.Count)

# 3. 逐个判断：这个 key 有没有在任何地方被「读取」（排除 SettingsScreen 自己）
Write-Output ""
Write-Output "=== 只写不读、且未标注的设置项 ==="
$leak = 0
foreach ($k in $settingKeys) {
    if ($declared -contains $k) { continue }   # 已标注，跳过

    $readCount = 0
    foreach ($f in $allSwift) {
        if ($f.Name -eq 'SettingsScreen.swift') { continue }
        $hits = Select-String -Path $f.FullName -Pattern ([regex]::Escape('"' + $k + '"')) -ErrorAction SilentlyContinue
        foreach ($h in $hits) {
            if ($h.Line -match '\.(string|integer|bool|double|object|array)\(forKey') { $readCount++ }
        }
    }
    if ($readCount -eq 0) {
        Write-Output ("  LEAK  " + $k)
        $leak++
    }
}
if ($leak -eq 0) { Write-Output "  无遗漏" } else { Write-Output ("  共 " + $leak + " 个漏网") }
