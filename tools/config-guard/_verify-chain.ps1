. "$PSScriptRoot\_paths.ps1"
﻿$d = $ZL2Repo
Write-Output "=== FPS 链路完整性验证 ==="
$chain = @(
    @{ step = '1. 核心每帧调用';        file = 'core\egl_bridge.m';              pat = 'ZL2FrameStatsTick' },
    @{ step = '2. 计数器实现';          file = 'core\ZL2FrameStats.m';           pat = 'atomic_fetch_add_explicit' },
    @{ step = '3. 加入 CMake 构建';     file = 'core\CMakeLists.txt';            pat = 'ZL2FrameStats.m' },
    @{ step = '4. Swift 读取符号';      file = 'src\ZL2FrameStats.swift';        pat = '_silgen_name("ZL2FrameStatsTotal")' },
    @{ step = '5. 每秒差分算 FPS';      file = 'src\ZL2FrameStats.swift';        pat = 'delta / dt' },
    @{ step = '6. 悬浮层用采样器';      file = 'src\GameOverlay.swift';          pat = 'ZL2PerfSampler()' },
    @{ step = '7. 挂到游戏视图';        file = 'src\ZLOverlayHost.swift';        pat = 'attach(to:' },
    @{ step = '8. ObjC 侧调用 attach';  file = 'core\SurfaceViewController.m';   pat = 'ZLOverlayHost' }
)
$allOk = $true
foreach ($c in $chain) {
    $p = Join-Path $d $c.file
    if (-not (Test-Path $p)) { Write-Output ("  MISS " + $c.step + "  (文件不存在: " + $c.file + ")"); $allOk = $false; continue }
    $hit = Select-String -Path $p -Pattern ([regex]::Escape($c.pat)) -SimpleMatch -ErrorAction SilentlyContinue
    if ($hit) {
        Write-Output ("  OK   " + $c.step + "  → " + $c.file + ":" + $hit[0].LineNumber)
    } else {
        Write-Output ("  MISS " + $c.step + "  → " + $c.file); $allOk = $false
    }
}

Write-Output ""
if ($allOk) { Write-Output "链路完整：从渲染帧到悬浮球显示的 8 个环节全部接通" }
else { Write-Output "链路有断点，见上" }

Write-Output ""
Write-Output "=== 内存链路 ==="
$mem = @(
    @{ step = '读取 mach footprint'; file = 'src\GameOverlay.swift'; pat = 'phys_footprint' },
    @{ step = '内存条渲染';          file = 'src\GameOverlay.swift'; pat = 'struct GameMemoryBar' }
)
foreach ($c in $mem) {
    $p = Join-Path $d $c.file
    $hit = Select-String -Path $p -Pattern ([regex]::Escape($c.pat)) -SimpleMatch -ErrorAction SilentlyContinue
    if ($hit) { Write-Output ("  OK   " + $c.step + "  → 行 " + $hit[0].LineNumber) }
    else { Write-Output ("  MISS " + $c.step) }
}

Write-Output ""
Write-Output "=== 设置项状态 ==="
$sf = Join-Path $d 'src\SettingsScreen.swift'
$sc = Get-Content $sf -Raw -Encoding UTF8
foreach ($k in @('showFPS','showMemory','fpsDisplayMode','showMenuBall')) {
    $inUnsupported = $sc -match ('"' + $k + '"')
    # 更精确：是否出现在 Set<String> 列表区域内
    Write-Output ("  " + $k + " : 仍在 unsupported 列表 = " + $inUnsupported)
}
