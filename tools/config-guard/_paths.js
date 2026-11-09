// 统一解析仓库路径（让工具集可移植）
//
// 起因：ios-zl2 第96轮的发现 —— 第95轮把工具集拷进了仓库 `tools/config-guard/`，
// 但**53 个脚本仍然写死 `D:\ios-zl2`**，所以"入仓"只是把文件搬了进去，
// 换一台机器（或换个目录）照样跑不了。文档承诺了可移植性，实际没有。
//
// 解析顺序：
//   1. 环境变量 ZL2_REPO（显式指定，最可靠）
//   2. 从脚本自身位置向上找：看到含 `project.yml` 的目录就是仓库根
//      （适用于仓库副本 `<repo>/tools/config-guard/`，也适用于任何位置的检出）
//   3. 本机默认值 D:\ios-zl2（工作副本在 config-guard 里，向上两级不是仓库，走这里兜底）
//
// 用法：
//   const { REPO, SRC, CORE, GUARD } = require('./_paths');
//
// 注意：这个文件是**唯一**允许出现默认绝对路径的地方。

const fs = require('fs');
const path = require('path');

function findRepo() {
  // 1) 显式指定
  const env = process.env.ZL2_REPO;
  if (env && fs.existsSync(path.join(env, 'project.yml'))) return env;

  // 2) 从脚本目录向上找 project.yml
  let dir = __dirname;
  for (let i = 0; i < 6; i++) {
    if (fs.existsSync(path.join(dir, 'project.yml'))) return dir;
    const up = path.dirname(dir);
    if (up === dir) break;
    dir = up;
  }

  // 3) 本机默认
  return 'D:\\ios-zl2';
}

const REPO = findRepo();

module.exports = {
  REPO,
  SRC: path.join(REPO, 'src'),
  CORE: path.join(REPO, 'core'),
  DOCS: path.join(REPO, 'docs'),
  GUARD: __dirname,
  // 工作副本位置（只在需要对照两份时用）；仓库副本里它就是 __dirname
  WORKING_GUARD: 'C:\\Users\\21793\\.dsh\\config-guard',
};
