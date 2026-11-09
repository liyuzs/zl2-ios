$d = 'D:\ios-zl2'

Write-Output "=== 本轮接线验证 ==="
$checks = @(
    @{ n = 'editorEnableWidgetSnap';  f = 'src\ControlEditor.swift';      p = 'readSettingBool("editorEnableWidgetSnap"' },
    @{ n = 'editorSnapInAllLayers';   f = 'src\ControlEditor.swift';      p = 'readSettingBool("editorSnapInAllLayers"' },
    @{ n = 'editorWidgetSnapMode';    f = 'src\ControlEditor.swift';      p = 'ZLSettings.def("editorWidgetSnapMode")' },
    @{ n = 'applySnap 边缘吸附';      f = 'src\ControlEditor.swift';      p = 'private func applySnap' },
    @{ n = 'currentAccount 同步';     f = 'src\AccountService.swift';     p = 'forKey: "currentAccount"' },
    @{ n = 'currentGamePathId 同步';  f = 'src\GameDirectoryStore.swift'; p = 'forKey: "currentGamePathId"' },
    @{ n = 'finishedGame 计数';       f = 'src\CoreBridge.swift';         p = 'forKey: "finishedGame"' },
    @{ n = 'recordGameLaunch 调用1';  f = 'src\CoreBridge.swift';         p = 'recordGameLaunch()' }
)
$ok = 0
foreach ($c in $checks) {
    $p = Join-Path $d $c.f
    $h = Select-String -Path $p -Pattern ([regex]::Escape($c.p)) -SimpleMatch -ErrorAction SilentlyContinue
    if ($h) { Write-Output ("  OK   " + $c.n + "  -> " + $c.f + ":" + $h[0].LineNumber); $ok++ }
    else { Write-Output ("  MISS " + $c.n) }
}
Write-Output ("`n通过 " + $ok + " / " + $checks.Count)

Write-Output ""
Write-Output "=== 剩余 notWired ==="
$sc = Get-Content (Join-Path $d 'src\SettingsScreen.swift') -Raw -Encoding UTF8
$blk = [regex]::Match($sc, 'static let notWired:\s*Set<String>\s*=\s*\[([\s\S]*?)\n    \]')
if ($blk.Success) {
    $keys = [regex]::Matches($blk.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    Write-Output ("  共 " + $keys.Count + " 项：" + ($keys -join ', '))
} else {
    Write-Output "  解析失败"
}
