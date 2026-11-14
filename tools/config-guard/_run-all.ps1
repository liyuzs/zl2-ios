# 一键跑完全部检查
#
# 为什么有这个：config-guard 里有 40 个脚本，其中 26 个该跑。逐个敲命令既慢又容易漏，
# 漏掉一个的代价可能是"以为全绿其实有一条红的"。
#
# 用法：
#   .\_run-all.ps1                  # 跑 25 个快速检查（不含 CI 模拟）
#   .\_run-all.ps1 -IncludeSimulate # 连 _simulate-ci.ps1 一起跑（多花 1~2 分钟）
#   .\_run-all.ps1 -Quiet           # 只输出失败的
#
# 退出码：全部通过 0，有任何失败 1。
#
# 注意：本文件必须存成 UTF-8 带 BOM，否则 PowerShell 5.1 按 GBK 解码，
# 中文乱码并且会吃掉引号，报一堆假语法错误。

param(
    [switch]$IncludeSimulate,
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
$g = 'C:\Users\21793\.dsh\config-guard'

# ---- 权威清单（与 README-脚本清单.md 保持一致）----
# 每项：名字, 类型（js/ps1）, 说明
$checks = @(
    @('swift-lint.js',              'js',  'Swift 括号配对'),
    @('_check-indentation.js',     'js',  '缩进：块内贴行首'),
    @('_check-startup-io.js',      'js',  '首屏不做递归目录扫描'),
    @('_check-hotpath-cost.js',   'js',  '渲染期不许昂贵操作'),
    @('_check-interpolation.js',    'js',  '插值里拼错的变量名'),
    @('_check-imports.js',          'js',  '框架 import 缺失（会编译失败）'),
    @('_check-error-hints.js',      'js',  '失败提示必须带 advice'),
    @('_check-error-locale.js',    'js',  '错误翻译先按错误码'),
    @('_check-guide-claims.js',    'js',  '文案教的操作必须有实现'),
    @('_check-share-claim.js',    'js',  '分享文案要有 CFBundleDocumentTypes'),
    @('_check-code-refs.js',      'js',  '注释里的行号引用还有效'),
    @('_check-call-labels.js',      'js',  '参数标签对撞（会编译失败）'),
    @('_check-duplicates.js',       'js',  '顶层类型重复声明（会编译失败）'),
    @('_audit-ui-affordance.js',    'js',  '假交互（绑了控件没人读）'),
    @('_check-orphan-views.js',     'js',  'View 写了没挂载'),
    @('_check-dead-types.js',       'js',  '零使用的顶层类型（死代码）'),
    @('_check-dead-params.js',    'js',  '死参数（签名有、函数体没用）'),
    @('_check-dead-routes.js',      'js',  '路由声明了但没人导航'),
    @('_check-pending-action.js',   'js',  '快捷指令待处理动作（写入/消费/时效）'),
    @('_check-fixed-widths.js',     'js',  '固定宽度 ≥280 必然溢出手机竖屏'),
    @('_check-a11y.js',             'js',  '图标按钮无障碍（只许降）'),
    @('_check-symbol-names.js',   'js',  'SF Symbol 名都在已验证清单'),
    @('_check-hstack-budget.js',   'js',  '一行内固定宽度之和'),
    @('_check-trademark-strings.js','js',  '界面自称 ZL2（违反 GPLv3 第7条）'),
    @('_check-license-page.js',     'js',  '许可页 ↔ 实际打包内容'),
    @('_check-readme-claims.js',    'js',  'README 声明 ↔ 代码实现'),
    @('_check-settings-audit.js',   'js',  '设置项审计文档 ↔ 代码集合'),
    @('_check-settings-wiring.js', 'js',  '设置项落地归属'),
    @('_check-settings-entry.js',  'js',  '设置项都有 UI 入口'),
    @('_check-orphan-keys.js',    'js',  'UserDefaults 键都在定义里'),
    @('_check-shortcut-types.js', 'js',  '快捷项 type 都有对应 case'),
    @('_check-orientation.js',    'js',  '方向声明与切换逻辑配对'),
    @('_check-pending-routes.js',  'js',  '待处理路由都有消费分支'),
    @('_check-silent-default.js',  'js',  '字符串 switch 的 default 要留日志'),
    @('_check-error-case-created.js','js', '错误 case 必须能被抛出'),
    @('_check-error-exhaustive.js','js', 'errorDescription 必须穷尽'),
    @('_check-state-written.js',   'js',  '@State 必须有写入路径'),
    @('_check-dup-decl.js',       'js',  '同类型内不许重复声明'),
    @('_check-dup-case.js',       'js',  'enum 内不许重复 case'),
    @('_check-dup-switch-case.js', 'js', 'switch 内不许重复 case'),
    @('_check-empty-button.js',   'js',  '按钮不能空 action'),
    @('_check-number-range.js',  'js',  '数字输入项必须有 range'),
    @('_check-type-control.js',   'js',  '设置项类型与控件匹配'),
    @('_check-type-read.js',      'js',  'type 与读取方法匹配'),
    @('_check-fallback-default.js','js', '兜底值与声明默认值一致'),
    @('_check-setting-defaults.js','js',  '设置项默认值只在一处声明'),
    @('_check-path-safety.js',      'js',  '路径拼接安全（防目录穿越）'),
    @('_check-log-secrets.js', 'js', '日志不许打印敏感数据'),
    @('_check-download-magic.js', 'js', '下载写盘须校验内容'),
    @('_check-decode-recovery.js',  'js',  '解码失败必须备份原始数据'),
    @('_check-dark-mode.js',        'js',  '深色模式是否真的生效'),
    @('_check-install-docs.js',     'js',  '三份安装文档一致性（JIT/StikDebug/孤例工具）'),
    @('_check-section-refs.js', 'js', '第N节引用要带标题'),
    @('_check-obsolete-docs.js', 'js', '失效文档必须标注'),
    @('_check-capability-claims.js', 'js', '能力边界两份文档都要说'),
    @('_check-layout-keys.js',      'js',  '布局导出键 ↔ 核心读取'),
    @('_check-destructive-confirm.js', 'js', '破坏性按钮必须先确认（数据安全）'),
    @('_check-atomic-writes.js',    'js',  '写持久化文件必须原子（防截断）'),
    @('_audit-jni-natives.js',      'js',  'JNI native 契约'),
    @('_audit-jni-classes.js',      'js',  'FindClass 目标在不在 jar 里'),
    @('_audit-env.js',              'js',  '环境变量契约'),
    @('_audit-prefkeys.js',         'js',  '偏好键是否已定义'),
    @('_audit-stores.js',           'js',  '三套存储对撞'),
    @('_check-runtime-assets.js',   'js',  '运行时资源完整性'),
    @('_audit-orphan-core.js',      'js',  '核心孤儿函数'),
    @('_check-workflow.js',         'js',  'workflow 结构'),
    @('_check-ci-contract.js',     'js',  '推送脚本 ↔ CI 契约'),
    @('_audit3.ps1',                'ps1', '设置项读写审计'),
    @('_check-links.ps1',           'ps1', '文档死链'),
    @('_check-checklist-logs.js',   'js',  '清单日志文案 ↔ 代码契约'),
    @('_check-doc-stats.js',        'js',  '文档规模数字 ↔ 仓库实际'),
    @('_check-hardcoded-stats.js','js',  '界面文案不许写死规模数字'),
    @('_check-hardcoded-versions.js', 'js', '界面不许写死版本号'),
    @('_check-script-inventory.js', 'js',  '脚本清单 ↔ 磁盘（双向）'),
    @('_check-stale-allows.js',    'js',  '白名单不许指向已删文件'),
    @('_check-check-metadata.js', 'js',  '检查要写明自己查不到什么'),
    @('_check-delivery-docs.js',    'js',  '交付包文档 ↔ 仓库（不许孤本/漏同步）'),
    @('_check-doc-config-sync.js','js', '文档配置属性与 project.yml 一致'),
    @('_check-doc-hardcoded-counts.js','js', '文档不写会变的数量'),
    @('_check-code-hardcoded-counts.js', 'js', '代码文案不写死数量'),
    @('_check-delivery-index.js',  'js',  '交付包入口说明 ↔ 文件清单')
)

$tests = @(
    @('_test-keynames.js',          'js',  '键名表 119 条'),
    @('_test-layout-contract.js',   'js',  '布局格式契约 13 条'),
    @('_test-gamedir.js',           'js',  '游戏目录对齐 6 条'),
    @('_test-java-version.js',      'js',  'Java 版本判定 50 条'),
    @('_test-jre-select.js',        'js',  'JRE 挑选链路 47 条'),
    @('_test-version.js',           'js',  '版本号比较 21 条'),
    @('_test-renderers.js',         'js',  '渲染器净化 58 条'),
    @('_test-pseudo-v2.js',         'js',  '伪键码方案'),
    @('_check-picker.js',           'js',  'picker 参数个数'),
    @('_test-glfw.js',              'js',  'GLFW 键名 23 条'),
    @('_test-joystick.js',          'js',  '摇杆键码 32 槽'),
    @('_test-preflight.js',         'js',  '启动前预检契约 11 条'),
    @('_test-msauth-poll.js',       'js',  '微软登录轮询契约 7 条'),
    @('_test-motd.js',              'js',  'MOTD 三形态解析 11 条')
)

$simulate = @('_simulate-ci.ps1', 'ps1', 'CI 完整装配 15 项断言')

# 注意：不能用 @($checks) + @($tests) —— PowerShell 的 @() 会把"数组的数组"展平，
# 单个三元组 @('a','b','c') 在 @() 里会变成 3 个独立字符串，
# 于是 $item[0] 取到的是字符 'a' 而不是第一个字段（这个坑我踩了一次）。
# 用 ArrayList 逐个 Add 最稳。
$all = New-Object System.Collections.ArrayList
foreach ($x in $checks) { [void]$all.Add($x) }
foreach ($x in $tests)  { [void]$all.Add($x) }
if ($IncludeSimulate)   { [void]$all.Add($simulate) }

$ok = 0
$failed = @()
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# ---- 清单结构自检（第124轮加）----
# 往三元组列表插新行时多留一个逗号，PowerShell 会把 `@(...),,` 解析成数组套数组，
# 然后在 Join-Path 处报「无法将 System.Object[] 转换为参数 ChildPath」——
# 错误信息离病根太远（第79/124轮各踩一次）。这里先验一遍，报出具体是哪一项。
$badShape = @()
foreach ($it in $all) {
    if ($it -isnot [array] -or @($it).Count -ne 3) { $badShape += ,$it }
}
if ($badShape.Count -gt 0) {
    Write-Host "✗ 清单结构有误：$($badShape.Count) 项不是【脚本名, 类型, 说明】三元组" -ForegroundColor Red
    Write-Host "  （多半是插入新行时多留了一个逗号，写成 ) , 结尾又加了一行）" -ForegroundColor DarkGray
    foreach ($b in $badShape) {
        $txt = if ($null -eq $b) { "(null)" } else { ($b | ForEach-Object { "$_" }) -join " / " }
        Write-Host "   • $txt" -ForegroundColor Yellow
    }
    exit 1
}
foreach ($item in $all) {
    $name = $item[0]
    $kind = $item[1]
    $desc = $item[2]
    $path = Join-Path $g $name

    if (-not (Test-Path $path)) {
        $failed += [pscustomobject]@{ Name = $name; Desc = $desc; Code = 'MISSING'; Line = '文件不存在' }
        if (-not $Quiet) { Write-Host ("✗ {0,-28} 缺失" -f $name) -ForegroundColor Red }
        continue
    }

    try {
        if ($kind -eq 'js') {
            $out = & node $path 2>&1
        } else {
            $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
        }
        $code = $LASTEXITCODE

        # **非终止错误也要算失败**（第122轮）：
        # PowerShell 脚本里某一行报错（比如变量名带脏字符）但不终止时，
        # 整个脚本仍会跑完并返回 0 —— 于是 `_check-links.ps1` 明明跑不起来，
        # 这里却一直报"✓"。判据要同时看输出里有没有 ErrorRecord。
        $hadError = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count
        if ($code -eq 0 -and $hadError -gt 0) { $code = "ERR($hadError)" }
    } catch {
        $out = @("$($_.Exception.Message)")
        $code = 'THROW'
    }

    $lines = @($out | Where-Object { "$_".Trim() -ne '' })
    $last = if ($lines.Count -gt 0) { "$($lines[-1])".Trim() } else { '' }
    if ($last.Length -gt 70) { $last = $last.Substring(0, 70) + '…' }

    if ($code -eq 0) {
        $ok++
        if (-not $Quiet) {
            Write-Host ("✓ {0,-28} {1}" -f $name, $desc) -ForegroundColor Green
        }
    } else {
        $failed += [pscustomobject]@{ Name = $name; Desc = $desc; Code = $code; Line = $last }
        Write-Host ("✗ {0,-28} exit={1}  {2}" -f $name, $code, $last) -ForegroundColor Red
    }
}

$sw.Stop()

Write-Host ''
Write-Host ("=== {0} 项通过，{1} 项失败，用时 {2:N1} 秒 ===" -f $ok, $failed.Count, $sw.Elapsed.TotalSeconds)

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host '失败明细：' -ForegroundColor Red
    foreach ($f in $failed) {
        Write-Host ("  {0}  ({1})  exit={2}" -f $f.Name, $f.Desc, $f.Code) -ForegroundColor Red
        if ($f.Line) { Write-Host ("      $($f.Line)") }
    }
    Write-Host ''
    Write-Host '（结果不满意的脚本，单独跑一次看完整输出）'
    exit 1
}

Write-Host '全部通过。'
exit 0
