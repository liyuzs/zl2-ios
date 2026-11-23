// UserDefaults 的键必须是 ZL2 设置项或已登记的内部键（第158轮）
//
// `applyUserSettings()` 用硬编码键名读设置。如果键名拼错、或指向一个已删的设置项，
// 就会**永远读到 nil**，而代码看起来完全正常 —— 设置不生效且无任何提示。
//
// 判据：扫所有含 `UserDefaults` 的行里的 `forKey: "xxx"`：
//   · 带点号的跳过（`debug.debug_always_attached_jit` 之类是核心自己的 pref 键）
//   · 在 ZLSettings 定义里 → OK
//   · 在 INTERNAL 白名单里 → OK（每个都写明为什么）
//   · 否则 → 孤儿键
//
// **局限**：
// · 只认 `forKey:` 这一种写法。用变量拼键名（`forKey: someVar`）查不到。
// · 只扫 UserDefaults 行 —— KVC 的 `value(forKey:)` 不是 UserDefaults 键
//   （第158轮第一版就把它误报成孤儿：`host.value(forKey: "ctrlView")`）。
// · INTERNAL 白名单人工维护，新增内部键要登记（保守方向：不登记就报）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const defined = new Set();
for (const m of settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"/g)) defined.add(m[1]);

// 不是 ZL2 设置项、也不是"孤儿"的键（每个都要写明为什么）
//
// **两类**：
//   ① 核心 pref 的记账本（`control_layout` / `defaultTouchCtrl`）—— 不带点
//   ② App 自己的 `zl.` 命名空间 —— 第259轮才真正开始检查（原来 `k.includes('.')` 一律跳过，
//      所以下面那些 `zl.*` 其实从没被看见过，白名单是这次补的）
//
// 这个 Map 现在是 **App 内部键的权威清单**：以后新增 `zl.xxx` 必须在这里登记，
// 否则检查会报 —— 这正是我们想要的（拼错一个 `zl.` 键会导致设置静默不生效）。
const INTERNAL = new Map([
  ['zl.authlib.server', '外置登录：皮肤站地址（AccountScreen 写，ZLYggdrasil 读）'],
  ['zl.authlib.uuid', '外置登录：角色 UUID'],
  ['lastLaunchDate', '最近一次启动时间（recordGameLaunch 写，首页 / App Group 读）'],
  ['firstLaunchDate', '首次启动时间'],
  ['control_layout', '**核心读的**布局文件名；ZL2 的设置项叫 controlLayout（见 CoreLayoutExport 注释）'],
  ['defaultTouchCtrl', '**核心 pref（control.default_ctrl）的记账本**，不是 ZL2 设置项（见 ZLLayerSwitcher 注释）'],

  // ── App 自己的 zl.* 命名空间（第259轮登记）────────────────────────────
  ['zl.assets.favorites', '收藏的资源项目 id 列表（AssetInfoScreen 写，AssetsScreen 读）'],
  ['zl.currentControlLayout', '当前生效的控制布局名（ControlEditor 保存时写，CoreBridge 启动前读）'],
  ['zl.currentUsername', '当前账号名（AccountStore 写，CoreBridge 读）'],
  ['zl.milestoneSeen', '**第259轮加的彩蛋记账**：已经庆祝到第几次启动，保证同一个里程碑只弹一次（HomeScreen 读写）'],
  ['zl.theme.name', '主题名（Theme 读写，用户可切换）'],
  ['zl.theme.dark', '是否深色（Theme 读写，跟随系统外观）'],
  ['zl.pinned.versions', '置顶的版本 id 列表（VersionListScreen 读写）'],
  ['zl.game.instance', '当前游戏实例名（VersionRepository 读写）'],
  ['zl.welcomeShown', '欢迎页是否已经看过（ZL2App 读写；看过就永不再显示）'],
  ['zl.pendingLaunch', '快捷指令的"启动游戏"意图（ZLiOSExtras 写，RootView 消费）'],
  ['zl.pendingLaunchAt', '上面那条意图的时间戳，用于 2 分钟时效判定'],
]);

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const orphans = [];
let checked = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    if (!/UserDefaults/.test(line)) return;
    for (const m of line.matchAll(/forKey:\s*"([^"]+)"/g)) {
      const k = m[1];
      // 「段.键」形式是**核心 pref 的键**（如 `control.default_ctrl`），存在核心 plist 里，
      // 从来不是 App 的 UserDefaults 键 —— 跳过是对的。
      //
      // **但 `zl.` 前缀例外**：那是 App 自己的命名空间（`zl.authlib.server`、`zl.milestoneSeen`…），
      // 必须照常检查。第259轮发现原来这里是 `k.includes('.')` 一律跳过，
      // 于是所有 `zl.*` 键从来没被这条检查看见过 —— 白名单里那两条 `zl.authlib.*`
      // 实际上也是装饰性的（有没有它们都一样）。
      if (k.includes('.') && !k.startsWith('zl.')) continue;
      if (defined.has(k)) continue;
      if (INTERNAL.has(k)) continue;
      checked++;
      orphans.push({ file: f, line: i + 1, key: k });
    }
  });
}

console.log(`ZLSettings 定义 ${defined.size} 个 key · 内部键白名单 ${INTERNAL.size} 个`);
console.log(`不在两者里的 UserDefaults 键：${checked} 处`);
console.log('');

if (orphans.length === 0) {
  console.log('✓ 所有 UserDefaults 键要么是 ZL2 设置项、要么是已登记的内部键');
  process.exit(0);
}

const byKey = {};
for (const o of orphans) (byKey[o.key] ||= []).push(o.file + ':' + o.line);

console.log(`⚠ ${Object.keys(byKey).length} 个孤儿键：`);
for (const [k, where] of Object.entries(byKey)) {
  console.log(`  ${k}  ← ${where.join(' · ')}`);
}
console.log('');
console.log('可能是：①拼错的键名（读不到 → 设置永远不生效、无任何提示）②该加进 ZLSettings ③内部状态（加进白名单并写明）');
process.exit(1);
