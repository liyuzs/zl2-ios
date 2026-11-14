// ZLSettings.type 与 UserDefaults 读取方法/转换类型必须匹配（第163轮）
//
// 与 `_check-type-control.js`（第152轮）互补：
//   · 152 轮查**写侧**：type 决定 UI 用什么控件（用错控件 → 存错类型）
//   · 本轮查**读侧**：type 决定 `UserDefaults` 用什么读法（用错读法 → **静默读到默认值**）
//
// `UserDefaults` 的类型读法**错了不报错**：
//   · `integer(forKey:)` 遇到存成 String 的值 → 返回 0
//   · `bool(forKey:)`   遇到存成 String "true" → 返回 false
//   · `object(forKey:) as? Int` 类型不符 → nil
// 用户改了设置但**完全不生效**，没有任何提示（第151轮那个"分辨率 asInt 读不到"就是这类）。
//
// **允许的写法**（不算错）：
//   · `object(forKey:) as? Bool ?? true` —— 标准桥接（存 Bool 时底层是 NSNumber）
//   · `object(forKey:) == nil`           —— 判断"有没有设置过"（区分"没设过"和"设成 false"）
//
// **局限**：
// · 只查硬编码 key 的 `forKey: "xxx"`。用变量拼 key 查不到。
// · `object(forKey:)` 后面若换行写 `as? X`（不同一行），查不到。
// · 只认 ZLSettings 里声明过的 key（孤儿键由 `_check-orphan-keys.js` 管）。
const fs = require('fs');
const path = require('path');

const { SRC } = require('./_paths');

const settingsSrc = fs.readFileSync(path.join(SRC, 'ZLSettings.swift'), 'utf8');
const defs = new Map();
for (const m of settingsSrc.matchAll(/\.init\(key:\s*"([^"]+)"[^)]*?type:\s*\.(\w+)/g)) {
  defs.set(m[1], m[2]);
}

// type → 允许的直接读取方法（object 通用，另由 as? 目标把关）
const ALLOWED_METHOD = {
  bool:       ['bool', 'object'],
  int:        ['integer', 'double', 'object'],
  long:       ['integer', 'double', 'object'],
  string:     ['string', 'object'],
  enumValue:  ['string', 'object'],
  stringList: ['stringArray', 'array', 'object'],
  parcelable: ['string', 'object', 'dictionary'],
};

// type → 允许的 `as?` 目标类型
const AS_TARGET = {
  bool:       ['Bool', 'NSNumber'],
  int:        ['Int', 'NSNumber', 'Double', 'Int64'],
  long:       ['Int', 'Int64', 'NSNumber'],
  string:     ['String', 'NSString', 'NSNumber'],
  enumValue:  ['String', 'NSString'],
  stringList: ['[String]', 'NSArray'],
  parcelable: ['String', 'NSString', 'NSDictionary'],
};

const files = fs.readdirSync(SRC).filter(f => f.endsWith('.swift'));
const problems = [];
let checked = 0;

for (const f of files) {
  const src = fs.readFileSync(path.join(SRC, f), 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (line.trim().startsWith('//')) return;
    const t = line.trim();
    if (!/UserDefaults/.test(t)) return;

    for (const m of t.matchAll(/\.(bool|integer|float|double|string|stringArray|array|dictionary|url)\(\s*forKey:\s*"([^"]+)"/g)) {
      const method = m[1], key = m[2];
      const ty = defs.get(key);
      if (!ty) continue;
      checked++;
      if (!(ALLOWED_METHOD[ty] || []).includes(method)) {
        problems.push({ file: f, line: i + 1, key, type: ty, why: '用了 ' + method + '(forKey:)' });
      }
    }

    for (const m of t.matchAll(/object\(\s*forKey:\s*"([^"]+)"\s*\)\s*as\?\s*([\w\[\]<>\.]+)/g)) {
      const key = m[1], target = m[2];
      const ty = defs.get(key);
      if (!ty) continue;
      checked++;
      if (!(AS_TARGET[ty] || []).includes(target)) {
        problems.push({ file: f, line: i + 1, key, type: ty, why: 'as? ' + target + ' 与 .' + ty + ' 不符' });
      }
    }
  });
}

console.log('检查了 ' + checked + ' 处 UserDefaults 读取（key 在 ZLSettings 里）');
console.log('');

if (problems.length === 0) {
  console.log('✓ 所有读取方法 / 转换类型都与 ZLSettings.type 匹配');
  process.exit(0);
}

console.log('⚠ ' + problems.length + ' 处不匹配（会**静默读到默认值**）：');
for (const p of problems) console.log('  ' + p.file + ':' + p.line + '  ' + p.key + '（.' + p.type + '）—— ' + p.why);
console.log('');
console.log('为什么危险：UserDefaults 的类型读法**错了不报错** —— 用户改了设置但完全不生效，无任何提示。');
console.log('修法：按 type 换读法（bool→bool() · int→integer() · string→string()），或用 object(forKey:) as? 正确类型。');
process.exit(1);
