. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
# 真正可疑的：名字明确是「弹层」的，且赋值了但既没 sheet 也没 if 渲染
$targets = @(
    @{ f = 'AccountScreen.swift';       v = 'showAddAccount' },
    @{ f = 'ControlEditor.swift';       v = 'showLayerList' },
    @{ f = 'ControlManageScreen.swift'; v = 'showImporter' },
    @{ f = 'FileManagerScreen.swift';   v = 'showNewFolder' },
    @{ f = 'FileSelectorScreen.swift';  v = 'showNewFolder' },
    @{ f = 'ModifyVersionScreen.swift'; v = 'showResult' },
    @{ f = 'VersionContentScreen.swift'; v = 'showDeleteConfirm' },
    @{ f = 'VersionManageScreens.swift'; v = 'showCreate' },
    @{ f = 'VersionManageScreens.swift'; v = 'showDeleteConfirm' },
    @{ f = 'VersionManageScreens.swift'; v = 'showRename' }
)

Write-Output "=== 逐个核实（看这些标志到底有没有被使用）==="
foreach ($t in $targets) {
    $p = Join-Path $d ('src\' + $t.f)
    if (-not (Test-Path $p)) { continue }
    $hits = Select-String -Path $p -Pattern ([regex]::Escape($t.v)) -ErrorAction SilentlyContinue
    Write-Output ""
    Write-Output ("--- " + $t.f + " / " + $t.v + "  （共 " + $hits.Count + " 处）---")
    foreach ($h in $hits) {
        Write-Output ("    行 " + $h.LineNumber + ": " + $h.Line.Trim())
    }
}
