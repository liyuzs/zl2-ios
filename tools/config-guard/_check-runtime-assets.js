// 运行时资源完整性检查
//
// 核心（ObjC）在启动游戏时会去 bundle 里读一堆东西：
//   <bundle>/libs/*.jar                  Java 侧启动器（net.kdt.pojavlaunch.PojavLauncher）
//   <bundle>/libs/patchjna_agent.jar     -javaagent，无条件添加
//   <bundle>/libs_caciocavallo17/*.jar   AWT 工具包（-Xbootclasspath/a）
//   <bundle>/java_runtimes/java-N-openjdk/lib/libjli.dylib
//   <bundle>/UniversalJIT26.js
//   <bundle>/Frameworks/*.dylib          渲染 / 声音 / 认证
//
// 少任何一个，表现都是「点了启动没反应」或闪退，而且报错藏在 JVM 的 stderr 里。
// 这个脚本把这些路径从核心源码里抽出来，逐个检查仓库 / IPA 里有没有。
//
// **局限**（不查什么）：
//   · **只认 `bundlePath` 拼接这一种写法**。核心若改用 `[[NSBundle mainBundle] pathForResource:ofType:]`
//     或 `NSBundle.mainBundle.URLForResource`，它抓不到那些路径。
//   · **靠读 CMakeLists 的 `add_library(... SHARED)` 名单排除"现场编译的库"**。写法一变
//     （`add_library(x MODULE)`、或改用 `set(SOURCES ...)` 间接定义），排除失效 → **把现场编译的库误报成缺文件**。
//   · **只对撞"仓库里有没有这个文件"**，不查**打好包之后 IPA 里有没有** —— 装配那一段归
//     `_simulate-ci.ps1`（15 项断言）。
//   · **判不了"路径对但指向了错的文件"**：文件在同名位置、内容却是别的东西（比如拿旧版 jar 顶替），完全看不出来。

const fs = require('fs');
const path = require('path');
const { REPO } = require('./_paths');
const CORE = path.join(REPO, 'core');

let pass = 0, fail = 0;
const missing = [];

function need(label, relPaths, hint) {
  const found = relPaths.filter(p => fs.existsSync(path.join(REPO, p)));
  if (found.length > 0) { pass++; console.log(`  ✓ ${label}`); }
  else { fail++; missing.push({ label, hint }); console.log(`  ✗ ${label} —— ${hint}`); }
}

console.log('=== ① Java 侧启动器（classpath / javaagent / bootclasspath）===');
// 核心 JavaLauncher.m 会拼这些路径：
//   -cp <bundle>/libs/*            主类 net.kdt.pojavlaunch.PojavLauncher
//   -javaagent <bundle>/libs/patchjna_agent.jar（现在是存在性判断，缺了只是跳过）
//   -Xbootclasspath/a:<bundle>/libs_caciocavallo17/*.jar
const LIBS_DIR = path.join(CORE, 'resources', 'libs');
const CACHO_DIR = path.join(CORE, 'resources', 'libs_caciocavallo17');
const CACHO8_DIR = path.join(CORE, 'resources', 'libs_caciocavallo');

function listJars(dir) {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.jar'));
}

const libsJars = listJars(LIBS_DIR);
const cachoJars = listJars(CACHO_DIR);
const cacho8Jars = listJars(CACHO8_DIR);

// 必需：主类所在的 launcher.jar
if (libsJars.includes('launcher.jar')) {
  pass++; console.log('  ✓ libs/launcher.jar（含 net.kdt.pojavlaunch.PojavLauncher）');
} else {
  fail++;
  console.log('  ✗ libs/launcher.jar —— -cp 里没有主类，JVM 会 ClassNotFoundException');
  missing.push({ label: 'libs/launcher.jar', hint: '从上游 PojavLauncher_iOS 发布包提取，见 docs/缺失组件-Java启动器jar.md' });
}

// 必需：caciocavallo17（Java 17+ 的 AWT 工具包）
if (cachoJars.length > 0) {
  pass++; console.log(`  ✓ libs_caciocavallo17/（${cachoJars.length} 个 jar）`);
} else {
  fail++;
  console.log('  ✗ libs_caciocavallo17/ —— AWT 起不来，-Dawt.toolkit 的类找不到');
  missing.push({ label: 'libs_caciocavallo17', hint: 'Java 17+ 的 Caciocavallo 实现' });
}

// 可选：Java 8 的 caciocavallo（我们只带 17/21/25，一般用不到）
if (cacho8Jars.length > 0) {
  pass++; console.log(`  ✓ libs_caciocavallo/（${cacho8Jars.length} 个 jar，Java 8 用）`);
} else {
  console.log('  · libs_caciocavallo/ 缺失（Java 8 才需要，可忽略）');
}

// 可选：patchjna_agent.jar —— JavaLauncher.m 已改成存在性判断
if (libsJars.includes('patchjna_agent.jar')) {
  pass++; console.log('  ✓ libs/patchjna_agent.jar');
} else {
  console.log('  ⚠ libs/patchjna_agent.jar 缺失 —— 已在 JavaLauncher.m 里改成存在性判断，');
  console.log('     JVM 仍能启动，只是 JNA 补丁不生效。上游 2.2 的包就没有这个 jar。');
}

console.log(`  合计：libs ${libsJars.length} 个 jar / caciocavallo17 ${cachoJars.length} 个`);
console.log('');
console.log('=== ② JRE ===');
['java-17', 'java-21', 'java-25'].forEach(v => {
  const rel = `jre/jre${v.replace('java-', '')}-ios-aarch64.tar.xz`;
  need(`${v} 压缩包`, [rel], 'CI 从这里装配运行时');
});

console.log('');
console.log('=== ③ 渲染 / JIT 资源 ===');
need('UniversalJIT26.js', ['core/resources/UniversalJIT26.js'], 'iOS 上跑 Java 必需');
need('Frameworks 目录', ['core/resources/Frameworks'], '渲染与认证动态库');
// 注意：渲染库有两种来源，不能一律当成"仓库里必须有的文件" ——
//   · libgl4es_114 / libOSMesa.8 是预编译好的，放在 core/resources/Frameworks/
//   · libtinygl4angle 是 CMake 用 add_library(... SHARED) 现场编译出来的
//     （见 core/CMakeLists.txt:57，源文件 external/gl4es/tinygl4angle.c），
//     CI 最后用 `cp -R core/build/*.dylib $APP/Frameworks/` 拷进去。
// 把后者也当成"资源文件"会误报。
const cmake = fs.readFileSync(path.join(CORE, 'CMakeLists.txt'), 'utf8');
const builtLibs = new Set();
{
  const re = /add_library\(\s*([A-Za-z0-9_]+)\s+SHARED/g;
  let m;
  while ((m = re.exec(cmake)) !== null) builtLibs.add(m[1]);
}
console.log(`  CMake 现场编译的动态库：${[...builtLibs].sort().join(', ') || '（无）'}`);

[
  ['libgl4es_114.dylib', 'gl4es'],
  ['libtinygl4angle.dylib', 'tinygl4angle'],
  ['libOSMesa.8.dylib', 'OSMesa'],
].forEach(([lib, cmakeName]) => {
  if (builtLibs.has(cmakeName)) {
    pass++;
    console.log(`  ✓ ${lib}（CMake 构建产物，不需要在仓库里）`);
  } else {
    need(`  ${lib}`, [`core/resources/Frameworks/${lib}`], '渲染后端缺了会回落到别的或崩');
  }
});

console.log('');
console.log('=== ④ 核心从源码里硬编码的其它路径 ===');
// JavaLauncher.m / SurfaceViewController.m 里出现的 <bundle>/xxx 形式
const coreSrc = [];
(function collect(dir) {
  if (!fs.existsSync(dir)) return;
  for (const f of fs.readdirSync(dir)) {
    const full = path.join(dir, f);
    const st = fs.statSync(full);
    if (st.isDirectory()) collect(full);
    else if (/\.(m|h)$/.test(f)) coreSrc.push(full);
  }
})(CORE);

const bundlePaths = new Set();
for (const f of coreSrc) {
  const text = fs.readFileSync(f, 'utf8');
  // bundlePath ... stringByAppendingPathComponent:@"X"
  const re = /bundlePath\]\s*stringByAppendingPathComponent:@?"([^"]+)"/g;
  let m;
  while ((m = re.exec(text)) !== null) bundlePaths.add(m[1]);
  // %@/libs / %@/libs_caciocavallo17 之类
  const re2 = /NSBundle\.mainBundle\.bundlePath[^;]*@"\/([A-Za-z0-9_.]+)"/g;
  while ((m = re2.exec(text)) !== null) bundlePaths.add(m[1]);
}
console.log(`  核心引用的 bundle 子路径：${[...bundlePaths].sort().join(', ') || '（无）'}`);

console.log('');
if (fail === 0) {
  console.log(`✓ 全部就位（${pass} 项）`);
  process.exit(0);
} else {
  console.log(`✗ ${fail} 项缺失（通过 ${pass} 项）`);
  console.log('');
  console.log('缺失详情：');
  missing.forEach(m => console.log(`  · ${m.label}\n    ${m.hint}`));
  process.exit(1);
}
