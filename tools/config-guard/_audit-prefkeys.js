// PLPreferences 键存在性审计
//
// PLPreferences.m 的 setObject:value: 逻辑是：
//   if 键在 instancePref 里 → 写 instance
//   else if 键在 globalPref 里 → 写 global
//   else → NSLog("Setter could not find preference X") 然后 return NO
//
// 也就是说：**往一个没预定义的键写值，是静默失败的**。
// 这解释了为什么"写了设置却不生效"这类 bug 这么难查——日志里只有一行。
//
// 这个脚本把三件事对撞：
//   A. PLPreferences 的默认字典里定义了哪些键（可用键的白名单）
//   B. Swift / ObjC 里 setPref* 写了哪些键
//   C. ObjC 里 getPref* / resolveKey 读了哪些键

const fs = require('fs');
const path = require('path');

const CORE = 'D:\\ios-zl2\\core';
const SRC = 'D:\\ios-zl2\\src';

function readFiles(dir, exts) {
  const out = [];
  for (const f of fs.readdirSync(dir)) {
    const full = path.join(dir, f);
    if (fs.statSync(full).isDirectory()) continue;
    if (!exts.some(e => f.endsWith(e))) continue;
    out.push({ name: f, text: fs.readFileSync(full, 'utf8') });
  }
  return out;
}

const coreFiles = readFiles(CORE, ['.m', '.h']);
const swiftFiles = readFiles(SRC, ['.swift']);

// ---- A. 从 PLPreferences.m 的默认字典里抽键 ----
// 结构形如：@"section": @{ @"key": value, ... }
const prefSrc = coreFiles.find(f => f.name === 'PLPreferences.m');
if (!prefSrc) { console.log('找不到 PLPreferences.m'); process.exit(1); }

const defined = new Set();
{
  const text = prefSrc.text;
  // 逐个 section 块解析：@"xxx": @{ ... }.mutableCopy 或 @{ ... }
  const sectionRe = /@"([a-zA-Z_]+)"\s*:\s*@\{/g;
  let m;
  while ((m = sectionRe.exec(text)) !== null) {
    const section = m[1];
    // 从 @{ 之后开始，括号配对找到块尾
    let i = m.index + m[0].length - 1;   // 指向 '{'
    let depth = 0, start = i + 1;
    for (; i < text.length; i++) {
      if (text[i] === '{') depth++;
      else if (text[i] === '}') { depth--; if (depth === 0) break; }
    }
    const body = text.slice(start, i);
    // 块内的 @"key": 形式的键（只取第一层的，靠简单缩进/嵌套过滤：
    // 默认字典里没有更深嵌套到会影响判断的情况，除了 java_homes 那种子字典）
    const keyRe = /@"([a-zA-Z0-9_]+)"\s*:/g;
    let km;
    while ((km = keyRe.exec(body)) !== null) {
      defined.add(`${section}.${km[1]}`);
    }
  }
}

// ---- A2. 第二块写法：defaults[@"段"] = @{ ... } 与 defaults[@"段"][@"键"] = ... ----
// PLPreferences.m 在 `if (global)` 里用这种写法补了 debug / warnings / internal 等段，
// 只认第一块的 `@"段": @{` 会把这些全误报成"未定义"。
{
  const text = prefSrc.text;
  // defaults[@"X"] = @{ ... }
  const re1 = /defaults\[@"([a-zA-Z0-9_]+)"\]\s*=\s*@\{/g;
  let m;
  while ((m = re1.exec(text)) !== null) {
    const section = m[1];
    let i = m.index + m[0].length - 1;
    let depth = 0, start = i + 1;
    for (; i < text.length; i++) {
      if (text[i] === '{') depth++;
      else if (text[i] === '}') { depth--; if (depth === 0) break; }
    }
    const body = text.slice(start, i);
    const keyRe = /@"([a-zA-Z0-9_]+)"\s*:/g;
    let km;
    while ((km = keyRe.exec(body)) !== null) defined.add(`${section}.${km[1]}`);
  }
  // defaults[@"X"][@"Y"] = ...
  const re2 = /defaults\[@"([a-zA-Z0-9_]+)"\]\[@"([a-zA-Z0-9_]+)"\]\s*=/g;
  while ((m = re2.exec(text)) !== null) defined.add(`${m[1]}.${m[2]}`);
  // [defaults[@"X"] addEntriesFromDictionary:@{ @"k": ... }]
  const re3 = /\[defaults\[@"([a-zA-Z0-9_]+)"\]\s+addEntriesFromDictionary:\s*@\{([\s\S]*?)\}\]/g;
  while ((m = re3.exec(text)) !== null) {
    const section = m[1], body = m[2];
    const keyRe = /@"([a-zA-Z0-9_]+)"\s*:/g;
    let km;
    while ((km = keyRe.exec(body)) !== null) defined.add(`${section}.${km[1]}`);
  }
  // 先存进局部变量再合并：NSDictionary *g = @{ @"k": ... }; ... addEntriesFromDictionary:g]
  // PLPreferences.m 里 general 段就是这么写的，不处理会误报一堆。
  {
    const varRe = /NSDictionary\s*\*\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*@\{/g;
    let vm;
    while ((vm = varRe.exec(text)) !== null) {
      const varName = vm[1];
      let i = vm.index + vm[0].length - 1;
      let depth = 0, start = i + 1;
      for (; i < text.length; i++) {
        if (text[i] === '{') depth++;
        else if (text[i] === '}') { depth--; if (depth === 0) break; }
      }
      const body = text.slice(start, i);
      // 找这个变量被合并进了哪个段
      // 逐行找 `[defaults[@"段"] addEntriesFromDictionary:变量名]`，不用动态正则（转义太容易出错）
      const uses = [];
      text.split('\n').forEach(line => {
        if (!line.includes('addEntriesFromDictionary:')) return;
        if (!new RegExp('\\b' + varName + '\\b').test(line)) return;
        const sm = line.match(/\[defaults\[@"([A-Za-z0-9_]+)"\]/);
        if (sm) uses.push(sm[1]);
      });
      uses.forEach(section => {
        const keyRe = /(@"([a-zA-Z0-9_]+)")\s*:/g;
        let km;
        while ((km = keyRe.exec(body)) !== null) defined.add(`${section}.${km[2]}`);
      });
    }
  }
}

// java_homes 的子键（0/8/17/21/25 与 tag）也算已定义
['java.java_homes', 'video.renderer', 'control.default_ctrl'].forEach(k => defined.add(k));

// 已知的"动态字典"键：默认值是空字典，代码整体写入后再按子路径读。
// 这类子路径不 pre-define，但 setObject 找得到父键，所以能用。
const DYNAMIC_PREFIXES = ['internal.latest_version.'];
function isDynamic(key) { return DYNAMIC_PREFIXES.some(p => key.startsWith(p)); }

// ---- B. 写入的键 ----
const writes = new Map();
function addWrite(key, where) {
  if (!writes.has(key)) writes.set(key, []);
  writes.get(key).push(where);
}
for (const f of [...swiftFiles, ...coreFiles]) {
  f.text.split('\n').forEach((line, i) => {
    let m;
    const re = /setPref(?:Object|Bool|Int|Float)\(\s*@?"([^"]+)"/g;
    while ((m = re.exec(line)) !== null) addWrite(m[1], `${f.name}:${i + 1}`);
  });
}

// ---- C. 读取的键 ----
const reads = new Map();
function addRead(key, where) {
  if (!reads.has(key)) reads.set(key, []);
  reads.get(key).push(where);
}
for (const f of [...swiftFiles, ...coreFiles]) {
  f.text.split('\n').forEach((line, i) => {
    let m;
    const re1 = /getPref(?:Object|Bool|Int|Float)\(@?"([^"]+)"/g;
    while ((m = re1.exec(line)) !== null) addRead(m[1], `${f.name}:${i + 1}`);
  });
}

// resolveKey 的别名（PLProfiles.m:50 的 prefDefaults）
const ALIAS = {
  'defaultTouchCtrl': 'control.default_ctrl',
  'defaultGamepadCtrl': 'control.default_gamepad_ctrl',
  'javaArgs': 'java.java_args',
  'renderer': 'video.renderer',
};

console.log(`默认字典里定义的键：${defined.size} 个`);
console.log(`代码里写入的键：${writes.size} 个`);
console.log(`代码里读取的键：${reads.size} 个`);
console.log('');

let bad = 0;

// 检查 1：写入的键必须已定义（否则静默失败）
const undefWrites = [...writes.keys()].filter(k => !defined.has(k) && !isDynamic(k));
if (undefWrites.length) {
  bad += undefWrites.length;
  console.log(`✗ 写入未定义的键（会静默失败）${undefWrites.length} 个：`);
  undefWrites.forEach(k => console.log(`    ${k}  ← ${writes.get(k).join(', ')}`));
} else {
  console.log('✓ 所有写入的键都已预定义');
}
console.log('');

// 检查 2：读取的键应该已定义（否则永远拿到 nil）
const undefReads = [...reads.keys()].filter(k => !defined.has(k) && !isDynamic(k));
if (undefReads.length) {
  console.log(`⚠ 读取未定义的键（永远拿到 nil）${undefReads.length} 个：`);
  undefReads.forEach(k => console.log(`    ${k}  ← ${reads.get(k).join(', ')}`));
} else {
  console.log('✓ 所有读取的键都已预定义');
}
console.log('');

// 检查 3：setPref 用的键，其别名对应的读取键是否也覆盖到（信息性）
console.log('（别名表：resolveKey 找不到 profile 值时会去读右边这个键）');
Object.entries(ALIAS).forEach(([k, v]) => {
  const w = writes.has(v) ? '已写' : '未写';
  const d = defined.has(v) ? '已定义' : '未定义';
  console.log(`    ${k} -> ${v}   [${w}] [${d}]`);
});

process.exit(bad === 0 ? 0 : 1);
