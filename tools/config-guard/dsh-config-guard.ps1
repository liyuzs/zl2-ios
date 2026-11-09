#Requires -Version 5.1
<#
    DSH 配置守护 (dsh-config-guard)
    ------------------------------------------------------------
    作用：监视 ~/.dsh/profiles/*/cordis.patch.yml
          一旦发现文件被 DSH 设置界面重写导致「体积骤减 / 关键块丢失」，
          自动用最近一份健康快照还原，并留下日志与坏版本备份。

    还原源优先级：
      1. 本脚本自己维护的基线目录   _baseline\cordis.patch.yml.<profile>
      2. DSH 自己的 recovery\<时间戳>\cordis.patch.yml（取最大的那份）
      3. profiles\<profile>\cordis.patch.yml.bak-* （取最大的那份）

    用法：
      Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','本脚本.ps1' -WindowStyle Hidden
      加 -Once 参数则只检查一轮就退出（给计划任务用）
#>
param(
    [int]$IntervalSeconds = 20,
    [switch]$Once,
    [switch]$Verbose2
)

$ErrorActionPreference = 'Stop'

# ---------- 路径 ----------
$DshHome      = Join-Path $env:USERPROFILE '.dsh'
$ProfilesRoot = Join-Path $DshHome 'profiles'
$GuardRoot    = Join-Path $DshHome 'config-guard'
$BaselineDir  = Join-Path $GuardRoot 'baseline'
$BadDir       = Join-Path $GuardRoot 'bad'
$LogFile      = Join-Path $GuardRoot 'guard.log'

foreach ($d in @($GuardRoot, $BaselineDir, $BadDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

# ---------- 日志 ----------
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    if ($Verbose2) { Write-Host $line }
    # 日志超过 2MB 就截断，防止无限增长
    if ((Get-Item $LogFile -ErrorAction SilentlyContinue).Length -gt 2MB) {
        $tail = Get-Content $LogFile -Tail 2000
        Set-Content -Path $LogFile -Value $tail -Encoding UTF8
    }
}

# ---------- 健康判定 ----------
# 这些关键词一旦同时缺失多个，就判定配置被设置界面清洗过
$CriticalKeys = @(
    'opencode-go',
    'custom-opencode-go',
    'OC_GO_KEY',
    'llm-pi-ai',
    'agent-default-model'
)

function Get-HealthReport {
    param([string]$Path)

    $bytes = (Get-Item $Path).Length
    $text  = Get-Content -Path $Path -Raw -Encoding UTF8

    $missing = @()
    foreach ($k in $CriticalKeys) {
        if ($text -notmatch [regex]::Escape($k)) { $missing += $k }
    }

    [pscustomobject]@{
        Path      = $Path
        Bytes     = $bytes
        Missing   = $missing
        MissingN  = $missing.Count
        HasLlmPi  = ($text -match 'llm-pi-ai')
        Sha       = (Get-FileHash $Path -Algorithm SHA256).Hash
    }
}

# 判定要还原：缺 2 个以上关键块 且 体积比基线小一半以上
function Test-NeedsRestore {
    param($Report, [int]$BaselineBytes)

    if ($Report.MissingN -ge 2) { return $true }
    if ($BaselineBytes -gt 0 -and $Report.Bytes -lt ($BaselineBytes * 0.5)) { return $true }
    return $false
}

# ---------- 找还原源 ----------
function Find-RestoreSource {
    param([string]$Profile, [string]$ProfileDir)

    $candidates = @()

    # 1. 自己的基线
    $own = Join-Path $BaselineDir ("cordis.patch.yml.{0}" -f $Profile)
    if (Test-Path $own) {
        $candidates += Get-Item $own
    }

    # 2. DSH recovery 快照
    $recRoot = Join-Path $DshHome 'recovery'
    if (Test-Path $recRoot) {
        Get-ChildItem $recRoot -Recurse -Filter 'cordis.patch.yml' -ErrorAction SilentlyContinue |
            Where-Object { $_.Length -gt 1000 } |
            ForEach-Object { $candidates += $_ }
    }

    # 3. profile 目录下的 bak
    Get-ChildItem $ProfileDir -Filter 'cordis.patch.yml.bak-*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 1000 -and $_.Name -notmatch '坏' } |
        ForEach-Object { $candidates += $_ }

    if ($candidates.Count -eq 0) { return $null }

    # 挑最新且体积最大的
    $best = $candidates | Sort-Object -Property @{Expression={$_.Length};Descending=$true},
                                                 @{Expression={$_.LastWriteTime};Descending=$true} |
            Select-Object -First 1
    return $best
}

# ---------- 处理单个 profile ----------
function Invoke-GuardForProfile {
    param([string]$ProfileDir)

    $profile = Split-Path $ProfileDir -Leaf
    $live    = Join-Path $ProfileDir 'cordis.patch.yml'
    if (-not (Test-Path $live)) { return }

    $baselinePath = Join-Path $BaselineDir ("cordis.patch.yml.{0}" -f $profile)
    $baselineBytes = 0
    if (Test-Path $baselinePath) { $baselineBytes = (Get-Item $baselinePath).Length }

    try {
        $rep = Get-HealthReport -Path $live
    } catch {
        Write-Log "读取失败 $live : $($_.Exception.Message)" 'WARN'
        return
    }

    # 健康：若还没有基线，或当前比基线更完整，就更新基线
    if (-not (Test-NeedsRestore -Report $rep -BaselineBytes $baselineBytes)) {
        if ($rep.Bytes -gt 0 -and ($rep.Bytes -ge $baselineBytes -or -not (Test-Path $baselinePath))) {
            if (-not (Test-Path $baselinePath) -or $rep.Sha -ne (Get-FileHash $baselinePath -Algorithm SHA256).Hash) {
                Copy-Item $live $baselinePath -Force
                Write-Log "[$profile] 基线已更新 ($($rep.Bytes) 字节)"
            }
        }
        return
    }

    # ---- 需要还原 ----
    Write-Log "[$profile] 检测到配置被清空/损坏：当前 $($rep.Bytes) 字节，缺失关键块 [$($rep.Missing -join ', ')]" 'ALERT'

    $src = Find-RestoreSource -Profile $profile -ProfileDir $ProfileDir
    if (-not $src) {
        Write-Log "[$profile] 找不到任何可用的健康快照，放弃还原！" 'ERROR'
        return
    }

    # 备份坏版本
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $badPath = Join-Path $BadDir ("cordis.patch.yml.{0}.bad-{1}" -f $profile, $stamp)
    Copy-Item $live $badPath -Force
    Write-Log "[$profile] 坏版本已留档：$badPath"

    # 还原
    try {
        Copy-Item $src.FullName $live -Force
        $after = Get-HealthReport -Path $live
        Write-Log "[$profile] 已从 $($src.FullName) 还原 → $($after.Bytes) 字节，sha=$($after.Sha.Substring(0,16))" 'RESTORED'

        if ($after.MissingN -gt 0) {
            Write-Log "[$profile] 警告：还原后仍缺 [$($after.Missing -join ', ')]，可能需要人工检查" 'WARN'
        }

        # 更新基线
        Copy-Item $live $baselinePath -Force

        # 桌面通知（body 里放一条醒目的提示）
        $msg = "DSH 配置被重写，已于 $(Get-Date -Format 'HH:mm:ss') 自动还原（$profile）"
        Write-Log "[$profile] $msg" 'NOTIFY'
    } catch {
        Write-Log "[$profile] 还原失败：$($_.Exception.Message)" 'ERROR'
    }
}

# ---------- 主循环 ----------
Write-Log "===== 守护启动 (间隔 ${IntervalSeconds}s, Once=$Once) ====="

# 单实例：用互斥量防止重复启动
$mutexName = 'Global\DshConfigGuard'
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew -and -not $Once) {
    Write-Log "已有守护进程在跑，本次退出" 'WARN'
    return
}

$round = 0
try {
    do {
        $round++
        if (Test-Path $ProfilesRoot) {
            Get-ChildItem $ProfilesRoot -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch 'node_modules|\.' } |
                ForEach-Object { Invoke-GuardForProfile -ProfileDir $_.FullName }
        }

        # 心跳：每 15 轮（约 5 分钟）写一次，证明还活着
        if (-not $Once -and ($round % 15 -eq 1)) {
            Write-Log "心跳 #$round 守护正常运行"
        }

        if (-not $Once) { Start-Sleep -Seconds $IntervalSeconds }
    } while (-not $Once)

    if ($Once) { Write-Log "单轮检查完成" }
}
finally {
    if ($mutex) { try { $mutex.ReleaseMutex() } catch {} ; $mutex.Dispose() }
}
