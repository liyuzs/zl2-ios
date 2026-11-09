# 本地模拟 CI 的装配流程
#
# 目的：GitHub Actions 跑一次要几分钟到十几分钟，而装配步骤里最容易出的是
# 「路径不对 / 目录不存在 / strip 层数错 / 漏拷」这类问题 —— 这些在本机就能验。
#
# 覆盖两段：
#   ① JRE 17/21/25 从 jre/*.tar.xz 解到 java_runtimes/（--strip-components=2）
#   ② Bundle runtime & frameworks：
#        Frameworks 动态库 / *.js / log4j 补丁 / **libs 三个目录**（含断言）
#   ③ 关键文件校验，对应 CI 里的 test -f 断言

$ErrorActionPreference = 'Continue'
$d = 'D:\ios-zl2'
$work = 'D:\ci-simulate'

Write-Output "=== 模拟 CI 装配流程 ==="
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
$appRoot = Join-Path $work 'Payload\ZL2.app'
New-Item -ItemType Directory -Force -Path $appRoot | Out-Null

$ok = 0
$fail = 0

# ---------- ① JRE ----------
Write-Output ""
Write-Output "--- ① JRE 17 / 21 / 25 ---"
foreach ($JV in 17, 21, 25) {
    $DEST = Join-Path $appRoot "java_runtimes\java-$JV-openjdk"
    New-Item -ItemType Directory -Force -Path $DEST | Out-Null

    $archive = Join-Path $d "jre\jre$JV-ios-aarch64.tar.xz"
    if (-not (Test-Path $archive)) {
        Write-Output ("  JRE " + $JV + " : 仓库内资源不存在")
        $fail++
        continue
    }

    Push-Location $d
    $null = & tar -xf "jre\jre$JV-ios-aarch64.tar.xz" -C $DEST --strip-components=2 2>&1
    Pop-Location

    $jli = Join-Path $DEST 'lib\libjli.dylib'
    if (Test-Path $jli) {
        $size = [math]::Round((Get-ChildItem $DEST -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
        Write-Output ("  JRE " + $JV + " : OK  " + $size + " MB  libjli " + [math]::Round((Get-Item $jli).Length/1KB) + " KB")
        $ok++
    } else {
        Write-Output ("  JRE " + $JV + " : 失败 —— 解出来没有 lib\libjli.dylib（strip 层数不对？）")
        $fail++
    }
}

# ---------- ② Frameworks / js / log4j / libs ----------
Write-Output ""
Write-Output "--- ② Bundle runtime & frameworks ---"

# 2.1 Frameworks
$fwSrc = Join-Path $d 'core\resources\Frameworks'
$fwDst = Join-Path $appRoot 'Frameworks'
New-Item -ItemType Directory -Force -Path $fwDst | Out-Null
if (Test-Path $fwSrc) {
    Copy-Item (Join-Path $fwSrc '*') $fwDst -Recurse -Force
    $n = (Get-ChildItem $fwDst -File | Measure-Object).Count
    Write-Output ("  Frameworks : OK  " + $n + " 个文件")
    $ok++
} else {
    Write-Output "  Frameworks : 失败 —— core\resources\Frameworks 不存在"
    $fail++
}

# 2.2 *.js
$js = Get-ChildItem (Join-Path $d 'core\resources') -Filter '*.js' -File -ErrorAction SilentlyContinue
foreach ($f in $js) {
    Copy-Item $f.FullName $appRoot -Force
}
Write-Output ("  JIT 脚本 : " + $js.Count + " 个")

# 2.3 log4j 补丁
$lg = Get-ChildItem (Join-Path $d 'core\resources') -Filter 'log4j-rce-patch-*.xml' -File -ErrorAction SilentlyContinue
foreach ($f in $lg) {
    Copy-Item $f.FullName $appRoot -Force
}
Write-Output ("  log4j 补丁 : " + $lg.Count + " 个")

# 2.4 libs 三个目录 —— 对应 CI 里那段带 exit 1 的循环
foreach ($lname in @('libs', 'libs_caciocavallo', 'libs_caciocavallo17')) {
    $src = Join-Path $d "core\resources\$lname"
    $dst = Join-Path $appRoot $lname
    if (-not (Test-Path $src)) {
        Write-Output ("  " + $lname + " : 失败 —— 目录不存在（CI 会 ::error:: 并 exit 1）")
        $fail++
        continue
    }
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $src $dst -Recurse -Force
    $n = (Get-ChildItem $dst -File -Filter '*.jar' | Measure-Object).Count
    $mb = [math]::Round((Get-ChildItem $dst -File | Measure-Object Length -Sum).Sum / 1MB, 2)
    Write-Output ("  " + $lname + " : OK  " + $n + " 个 jar  " + $mb + " MB")
    $ok++
}

# ---------- ③ 关键文件校验（对应 CI 的 test -f） ----------
Write-Output ""
Write-Output "--- ③ 关键文件校验 ---"
$checks = @(
    @('libs\launcher.jar',                     'Java 侧启动器主类所在'),
    @('libs\lwjgl3-minecraft.jar',             'LWJGL 绑定'),
    @('libs_caciocavallo17\cacio-tta-1.18-SNAPSHOT.jar', 'AWT 工具包（Java 17+）'),
    @('UniversalJIT26.js',                     'JIT 脚本'),
    @('log4j-rce-patch-1.12.xml',              'log4j 补丁配置'),
    @('java_runtimes\java-17-openjdk\lib\libjli.dylib', 'JRE 17'),
    @('java_runtimes\java-21-openjdk\lib\libjli.dylib', 'JRE 21'),
    @('java_runtimes\java-25-openjdk\lib\libjli.dylib', 'JRE 25')
)
foreach ($c in $checks) {
    $p = Join-Path $appRoot $c[0]
    if (Test-Path $p) {
        Write-Output ("  OK  " + $c[0])
        $ok++
    } else {
        Write-Output ("  缺失 " + $c[0] + "   （" + $c[1] + "）")
        $fail++
    }
}

# ---------- 汇总 ----------
Write-Output ""
$totalMB = [math]::Round((Get-ChildItem $appRoot -Recurse -File | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Output ("=== app 总体积（不含主程序）: " + $totalMB + " MB ===")
Write-Output ("结果: " + $ok + " 项成功, " + $fail + " 项失败")

if ($fail -gt 0) {
    Write-Output ""
    Write-Output "有失败项 —— 照上面的名字去修，别等推送到 Actions 才发现。"
    exit 1
}
exit 0
