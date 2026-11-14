// 交付包入口说明的完整性
//
// 起因：ios-zl2 第100轮发现交付包里有 11 个文件，但**没有任何一页告诉收件人该先看哪个**。
// 对朋友来说，面对 `zl2-ios-完整仓库.bundle`（93 MB）和 `脚本清单.md`，他只会懵；
// 对接手者来说，从 README 进去也看不到"这个文件夹是怎么组织的"。
//
// 所以加了 `从这里开始.md`（仓库源：docs/交付包说明-从这里开始.md，复制到交付包根目录）。
// 这个检查保证它**不会和实际文件脱节**：
//   1. 交付包里每个文件都必须在说明里出现（漏了 = 收件人不知道那是什么）
//   2. 说明里表格提到的文件必须真的存在（别指向已删的文件）
//
// **局限**（不查什么）：
//   · **只查"点到点"的存在性，不查那句描述对不对**：把 93 MB 的 `bundle` 说成"源码"、把 IPA 说成
//     "最新版"，只要文件名在，本检查照样 ✓（第 172 轮那个"IPA 是旧包文档说它是本体"就是这类）。
//   · **只认 `从这里开始.md` 一份入口**。如果给收件人的是另一条路径（比如直接发安装指南），不在范围。
//   · **只查文件名级别**：`ZL2.ipa` 出现过就算"说明里提到了"，**加没加旧包警告它看不出来**
//     （那个由 `_check-delivery-docs` 的 "IPA 比源码旧超 1 天必须有 build-N 警告" 管）。
//   · 文件内容的准确性、副本字节一致**都不归它管** —— 那是 `_check-delivery-docs` 的职责。
//   · **不校验"文档里引用的节号对不对"** —— 第231轮人工核出 `从这里开始.md` 写着「下面**第五节**有表」，
//     而**第四节**才是文件表（第五节是"两个提醒"）。这类错靠"名字相似"完全看不出来：
//     它查的是文件在不在这份说明里，**不查"说明里指向的那一节是不是那一节"**。
//     全交付包这类引用共 6 处（跨三份文档），逐个人工核过；**分母太小且跨文档，没做成检查**。
//     两个检查各管一半，**中间那块（"说明说的话是不是真的"）目前没有检查**。
//
// 这和第95轮的 `_check-script-inventory` 是同一思路 —— 清单与磁盘双向核对。

const fs = require('fs');
const path = require('path');

const { REPO } = require('./_paths');

const DELIVERY = 'D:\\ZL2-iOS交付包';
const GUIDE_NAME = '从这里开始.md';
const GUIDE_SRC = path.join(REPO, 'docs', '交付包说明-从这里开始.md');
const GUIDE_DST = path.join(DELIVERY, GUIDE_NAME);

const problems = [];

// ---- 0. 说明本身要存在（仓库源 + 交付副本） ----
if (!fs.existsSync(GUIDE_SRC)) problems.push(`仓库里缺 ${path.relative(REPO, GUIDE_SRC)}`);
if (!fs.existsSync(GUIDE_DST)) problems.push(`交付包里缺 ${GUIDE_NAME}（收件人不知道该先看哪个）`);

if (problems.length) {
  for (const p of problems) console.log('✗ ' + p);
  process.exit(1);
}

const guide = fs.readFileSync(GUIDE_DST, 'utf8');

// ---- 1. 交付包每个文件都要被说明提到 ----
const onDisk = fs.readdirSync(DELIVERY).filter(f => {
  const full = path.join(DELIVERY, f);
  return fs.statSync(full).isFile();
});

const unmentioned = onDisk.filter(f => f !== GUIDE_NAME && !guide.includes(f));
for (const f of unmentioned) {
  problems.push(`交付包里有 ${f}，但「${GUIDE_NAME}」没提到它 —— 收件人不知道这是什么`);
}

// ---- 2. 说明里提到的文件必须存在（只查带扩展名的文件名） ----
const mentioned = new Set();
for (const m of guide.matchAll(/`([^`\/]+\.(?:md|ipa|ps1|zip|bundle))`/g)) mentioned.add(m[1]);
for (const f of mentioned) {
  if (!onDisk.includes(f)) {
    problems.push(`「${GUIDE_NAME}」提到 ${f}，但交付包里没有这个文件`);
  }
}

console.log(`交付包 ${onDisk.length} 个文件 · 说明提到 ${mentioned.size} 个`);
console.log('');

if (problems.length === 0) {
  console.log('✓ 交付包的每个文件都在「从这里开始」里有交代，且指向的文件都存在');
  process.exit(0);
}

console.log(`⚠ ${problems.length} 处不一致：`);
for (const p of problems) console.log(`  · ${p}`);
console.log('');
console.log('修法：加/删文件时同步改 `docs/交付包说明-从这里开始.md`，再复制到交付包。');
process.exit(1);
