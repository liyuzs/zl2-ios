# 单跑抽查：绕过执行器，逐个执行清单里的脚本
#
# 为什么需要它（ios-zl2 第122轮的教训）：
#   `_run-all.ps1` 报「59 项全绿」，而 `_check-links.ps1` 其实**从第96轮起就没真正跑过** ——
#   脚本第 2 行有 U+FEFF 脏字符，PowerShell 报错但不终止，退出码仍是 0，执行器只看退出码就判通过。
#   也就是说：**绿字是执行器给的结论，要验证结论就得绕开它自己看一次。**
#
# 什么时候用：
#   · 改过 `_run-all.ps1` 的判定逻辑之后
#   · 批量改过脚本（尤其跨换行/编码）之后
#   · 每过一阵子抽查一次，别只看总检查的绿字
#
# 判定（比 `_run-all.ps1` 严）：退出码 ≠ 0 **或** 输出里有 ErrorRecord，都算有问题。
#
# 用法：
#   .\_spot-check.ps1            # 抽查全部
#   .\_spot-check.ps1 -Verbose   # 连通过的也逐一列出

param([switch]$Verbose)

$ErrorActionPreference = 'Continue'
$g = $PSScriptRoot

# 从 _run-all.ps1 抽清单（三元组第一项），保证"要跑哪些"只有一个来源
$runAllPath = Join-Path $g '_run-all.ps1'
if (-not (Test-Path $runAllPath)) {
    Write-Host '✗ 找不到 _run-all.ps1（清单的唯一来源）' -ForegroundColor Red
    exit 1
}
$runAll = [System.IO.File]::ReadAllText($runAllPath)
$names = [regex]::Matches($runAll, "@\(\s*'([^']+\.(?:js|ps1))'") |
         ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

Write-Host ("单跑抽查：{0} 个脚本（绕过 _run-all.ps1 判定）`n" -f $names.Count)

$bad = @()
$okCount = 0

foreach ($n in $names) {
    $path = Join-Path $g $n
    if (-not (Test-Path $path)) {
        $bad += [pscustomobject]@{ Name = $n; Code = 'MISSING'; Errors = 0; Reason = '文件不存在' }
        continue
    }

    if ($n -like '*.js') {
        $out = & node $path 2>&1
    } else {
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    }
    $code = $LASTEXITCODE
    $errCount = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count

    if ($code -ne 0 -or $errCount -gt 0) {
        $reason = ''
        $errRec = $out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | Select-Object -First 1
        if ($errRec) {
            $reason = ("$($errRec.Exception.Message)").Split("`n")[0]
        }
        if (-not $reason) {
            $lines = @($out | Where-Object { "$_".Trim() -ne '' })
            if ($lines.Count -gt 0) { $reason = ("$($lines[-1])").Trim() }
        }
        if ($reason.Length -gt 70) { $reason = $reason.Substring(0, 70) + '…' }
        $bad += [pscustomobject]@{ Name = $n; Code = "$code"; Errors = $errCount; Reason = $reason }
    } else {
        $okCount++
        if ($Verbose) { Write-Host ("  ✓ {0}" -f $n) -ForegroundColor DarkGray }
    }
}

Write-Host ''
if ($bad.Count -eq 0) {
    Write-Host ("✓ {0} 个脚本单跑全部干净（退出码 0 且无 ErrorRecord）" -f $okCount) -ForegroundColor Green
    exit 0
}

Write-Host ("⚠ {0} 个脚本单跑有问题（{1} 个干净）：" -f $bad.Count, $okCount) -ForegroundColor Yellow
foreach ($b in $bad) {
    Write-Host ("  ✗ {0,-32} exit={1,-8} err={2}" -f $b.Name, $b.Code, $b.Errors) -ForegroundColor Yellow
    if ($b.Reason) { Write-Host ("      " + $b.Reason) -ForegroundColor DarkGray }
}
Write-Host ''
Write-Host '这类问题 `_run-all.ps1` 可能看不见（PowerShell 报错不终止时退出码仍是 0）。'
Write-Host '修法：看该脚本第一行是否有 BOM 脏字符、或有无未定义变量。'
exit 1
