// 命名合规检查（GPLv3 第 7 条附加条款）
//
// 起因：ios-zl2 的 README 明确写着合规声明——
//   依据 Zalith Launcher 2 的 GPLv3 附加条款（第 7 条）：
//     ✅ 本项目**不以** `ZalithLauncher` 或其缩写 `ZL` 作为名称
// 但第69轮在代码里发现**至少 7 处界面文字把 App 自称 "ZL2"**：
//   · 欢迎页第一页标题「欢迎使用 ZL2」
//   · 主界面引导「 welcome 使用 ZL2！」
//   · 文件管理空状态「把文件分享到 ZL2 里」
//   · JIT 提示「请在 StikDebug 里对 ZL2 启用 JIT」
//   · 诊断报告标题「=== ZL2-iOS 环境诊断 ===」
//   · 更新提示「先确认 StikDebug 里给 ZL2 开了 JIT」
//   · EasyTier 联机（系统设置里显示的名字）「ZL2 联机」
//
// **局限**（不查什么）：
//   · **不查符号名**：`ZL2App` / `ZLGlass` / `ZLTheme` / `ZLLoaderInstaller`… 全项目几百个类型都带 `ZL` 前缀，
//     但那是**代码符号，用户看不到**，所以不在范围。**这条检查只管"用户会读到的字"**。
//   · **判不了"这句算不算以 ZL 命名"**：`"ZL2.ipa"`（发布资产名）、`"不是有效的 ZL2 控制布局文件"`
//     （指上游格式）、Bonjour 服务名 `"ZL2.LanDiscovery"`（改了互相发现不到）、上游 URL（许可证要求署名）
//     —— 全靠 `ALLOW` 表逐条登记理由。**新出现一个合理用法就要人来加一条**，表越大越容易判错。
//   · **只扫 `src/`，不扫 `project.yml` 和文档**：README/STATUS 里出现 ZL2 是允许的（说明谱系）；
//     但如果 `CFBundleDisplayName` 之类写进配置，**它看不见**（那是 `_check-doc-config-sync` 的地盘）。
//   · **例外表是"知识"不是"规则"** —— 与第147轮"例外超过 3 类就放弃"同源，这里靠登记撑住，不是判据强。
//
// 也就是说：**项目自己声明的合规要求，被自己的界面违反了。**
// 这类问题不会报错、不影响功能，但属于对外声明与实现不一致。
//
// 判据：字符串字面量里出现 `ZL2` / `ZalithLauncher` 就报，**排除**：
//   · 注释（以 // 或 /// 开头）
//   · 日志前缀 NSLog(...) / print(...)
//   · 存储键（zl2.xxx）、Bundle ID、User-Agent、协议 boundary、符号名
//   · 明确的下游署名/格式名（见 ALLOW，每条都写理由）

const fs = require('fs');
const path = require('path');
const { SRC } = require('./_paths');
// 允许出现的例外：字符串片段 → 理由
const ALLOW = [
  { match: '不是有效的 ZL2 控制布局文件', why: '指的是上游的**布局文件格式**，不是 App 名称' },
  { match: '按 ZL2 Compose 界面重建',     why: '对上游项目的署名（许可证要求保留）' },
  { match: '照着安卓版 ZL2 逐像素对的',   why: '同上，指上游' },
  { match: 'github.com/liyuzs/zl2-ios',   why: '仓库地址' },
  { match: 'liyuzs/zl2-ios',              why: '仓库名' },
  { match: '----ZL2',                     why: 'multipart boundary，协议内部用' },
  { match: 'ZL2.LanDiscovery',            why: 'Bonjour 服务类型标识，改了会和旧客户端互相发现不到' },
  { match: 'github.com/ZalithLauncher/',  why: '上游项目地址（许可证要求保留署名）' },
  { match: '/releases/latest/download/ZL2.ipa', why: '发布资产的文件名，不是 App 名称' },
];

// 整行豁免：这些上下文里出现 ZL2 无害
const LINE_SKIP = [
  /^\s*\/\//,                 // 注释
  /NSLog\s*\(/,               // 日志
  /^\s*print\s*\(/,           // 日志
  /forKey:\s*"/,              // 存储键
  /static let .*=\s*"zl2\./,  // 存储键常量
  /User-Agent/,
  /providerBundleIdentifier/,
  /bundleIdentifier/,
  /domain:\s*"/,
  /@_silgen_name/,
  /^\s*private let repo/,
  /issues\/new/,
];

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let scanned = 0;

for (const name of files) {
  const lines = fs.readFileSync(path.join(SRC, name), 'utf8').split('\n');
  lines.forEach((line, i) => {
    if (!/ZL2|ZalithLauncher/.test(line)) return;
    if (LINE_SKIP.some(re => re.test(line))) return;
    if (ALLOW.some(a => line.includes(a.match))) return;
    // 只关心字符串字面量里的出现
    const lits = line.match(/"[^"]*"/g) || [];
    const hit = lits.find(s => /ZL2|ZalithLauncher/.test(s));
    if (!hit) return;
    scanned++;
    problems.push({ file: name, line: i + 1, lit: hit, text: line.trim().slice(0, 110) });
  });
}

console.log(`扫描 ${files.length} 个文件，字符串字面量里的 ZL2/ZalithLauncher 命中 ${scanned} 处`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 界面文字没有把 App 自称 ZL2（符合 README 声明的 GPLv3 第 7 条）');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处界面文字把 App 自称 ZL2：`);
for (const p of problems) {
  console.log(`\n  ${p.file}:${p.line}`);
  console.log(`    ${p.text}`);
}
console.log('');
console.log('修法：改成 CraftLauncher。若确实是"指上游项目/格式"的署名，');
console.log('      在脚本的 ALLOW 里登记并写明理由（不要默默放过）。');
process.exit(1);
