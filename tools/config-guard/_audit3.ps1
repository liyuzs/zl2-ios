$d = 'D:\ios-zl2'
$settingsFile = Join-Path $d 'src\ZLSettings.swift'
$screenFile   = Join-Path $d 'src\SettingsScreen.swift'

$txt = Get-Content $settingsFile -Raw -Encoding UTF8
$keys = [regex]::Matches($txt, '\.init\(key:\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

$sc = Get-Content $screenFile -Raw -Encoding UTF8
$blk = [regex]::Match($sc, 'enum ZLUnsupportedSettings[\s\S]*?static let platformOnly[\s\S]*?static let notWired[\s\S]*?\]')
# 收集所有"已标注"分组
$declared = @()
foreach ($grp in @('platformOnly','notWired','renderOnly','launcherLook')) {
    $pat = 'static let ' + $grp + ':\s*Set<String>\s*=\s*\[([\s\S]*?)\n    \]'
    $m = [regex]::Match($sc, $pat)
    if ($m.Success) {
        $declared += [regex]::Matches($m.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    }
}
$declared = $declared | Sort-Object -Unique

# 全部源文件（排除设置定义与设置界面）
$others = Get-ChildItem "$d\src" -Filter '*.swift' | Where-Object { $_.Name -notin @('SettingsScreen.swift','ZLSettings.swift') }
$allText = ($others | ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 }) -join "`n"

Write-Output "=== 设置项使用情况（改进版审计）==="
Write-Output ("  定义 " + $keys.Count + " 项 | 已标注 " + $declared.Count + " 项")

$live = @(); $decl = @(); $leak = @()
foreach ($k in $keys) {
    # 三种读取方式都算：
    #   1) UserDefaults.standard.xxx(forKey: "k")
    #   2) boolValue("k") / intValue("k") / stringValue("k")
    #   3) ZLSettings.def("k")
    #   4) 直接写入后由别处读取（forKey: "k" 出现在非设置文件里）
    $used = $false
    if ($allText -match ('forKey:\s*"' + [regex]::Escape($k) + '"')) { $used = $true }
    if ($allText -match ('(boolValue|intValue|stringValue)\("' + [regex]::Escape($k) + '"')) { $used = $true }
    if ($allText -match ('ZLSettings\.def\("' + [regex]::Escape($k) + '"\)')) { $used = $true }
    if ($allText -match ('readSettingBool\("' + [regex]::Escape($k) + '"')) { $used = $true }
    if ($allText -match ('object\(forKey:\s*"' + [regex]::Escape($k) + '"\)')) { $used = $true }

    if ($used) { $live += $k }
    elseif ($declared -contains $k) { $decl += $k }
    else { $leak += $k }
}

Write-Output ("`n  真正被使用: " + $live.Count)
Write-Output ("  已正确标注为不可用: " + $decl.Count)
Write-Output ("  漏网（只写不读且未标注）: " + $leak.Count)
if ($leak.Count -gt 0) {
    Write-Output "`n  === 漏网清单 ==="
    $leak | ForEach-Object { Write-Output ("    " + $_) }
}
