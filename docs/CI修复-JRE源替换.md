# CI 修复：JRE 源替换

> 日期：2026-11-08 第 9 轮
> 解决的问题：构建卡在 `Bundle runtime & frameworks` 步骤

---

## 一、问题回溯

`#236` 那次构建（11-06）失败在这里：

```
✅ Build Amethyst core (静态库)
✅ Generate Xcode project
✅ Build for device (未签名)      ← Swift 编译没问题
❌ Bundle runtime & frameworks    ← 卡死
   后续步骤全部 skipped
```

原因在 `build.yml` 这一行：

```yaml
curl -L --fail --retry 3 -o "/tmp/jre${JV}.zip" \
  "https://assets.angelauramc.dev/openjdk/ios-arm64/jre${JV}-ios-aarch64.zip"
```

**`assets.angelauramc.dev` 这个域名已经彻底无法解析了。**

```
DNS 查询 assets.angelauramc.dev → 解析失败
DNS 查询 angelauramc.dev        → 解析失败（整个域都没了）
```

所以 `curl --fail` 必然返回非零，`set -e` 让脚本退出，后面的打包、发布全都不执行。

---

## 二、解决思路

### 关键发现

已经发布的 `build-235` 那个 132 MB 的 IPA 里**已经包含完整的 JRE**：

```
Payload/ZL2.app/java_runtimes/
├── java-17-openjdk/   305 文件
├── java-21-openjdk/   308 文件
└── java-25-openjdk/   314 文件
```

**不需要再去找新的下载源——直接从成品里把资源捞出来。**

### 提取结果

从 IPA 里解出 750 个 JRE 文件，重新打包成 `tar.xz`：

| 包 | 原始大小 | 压缩后 |
|---|---|---|
| `jre17-ios-aarch64.tar.xz` | 103.2 MB | **20.9 MB** |
| `jre21-ios-aarch64.tar.xz` | 119.9 MB | **22.9 MB** |
| `jre25-ios-aarch64.tar.xz` | 119.8 MB | **23.3 MB** |
| **合计** | 342.9 MB | **67.1 MB** |

压缩率约 80%，因为 JRE 里有大量 `.class` 和文本资源。

---

## 三、改动内容

### 1. 仓库新增 `jre/` 目录

```
jre/
├── jre17-ios-aarch64.tar.xz   20.9 MB
├── jre21-ios-aarch64.tar.xz   22.9 MB
└── jre25-ios-aarch64.tar.xz   23.3 MB
```

### 2. CI 改成三级回退

```bash
JRE_BASE_RELEASE="https://github.com/liyuzs/zl2-ios/releases/download/jre-assets"
JRE_BASE_OLD="https://assets.angelauramc.dev/openjdk/ios-arm64"

for JV in 17 21 25; do
  GOT=""

  # ① 仓库内（最可靠，随代码一起 clone 下来）
  if [ -f "jre/jre${JV}-ios-aarch64.tar.xz" ]; then
    cp "jre/jre${JV}-ios-aarch64.tar.xz" "$ARCHIVE" && GOT=1
  fi

  # ② GitHub Release（仓库体积受限时的备选）
  if [ -z "$GOT" ]; then
    curl -L --fail --retry 3 --max-time 300 \
      -o "$ARCHIVE" "${JRE_BASE_RELEASE}/jre${JV}-ios-aarch64.tar.xz" && GOT=1
  fi

  # ③ 旧域名（万一哪天活了）
  if [ -z "$GOT" ]; then
    ...
  fi

  if [ -z "$GOT" ]; then
    echo "::warning::JRE $JV 三个源都拿不到，跳过"
    continue
  fi

  tar xf "$ARCHIVE" -C "$DEST" --strip-components=2
done
```

**为什么是三级回退**：单一源再挂一次又得重来。三级里只要有一级能用就行。

### 3. 修正解压层级

打出来的 tar 包路径是：

```
java_runtimes/java-17-openjdk/lib/libjli.dylib
```

要解到 `$DEST`（也就是 `java_runtimes/java-17-openjdk/`）下，
必须去掉**两层**：

```bash
tar xf "$ARCHIVE" -C "$DEST" --strip-components=2
```

一开始我写的是 `--strip-components=1`，模拟测试时发现解出来是
`$DEST/java-17-openjdk/lib/...`，多了一层，`libjli.dylib` 不在预期位置。

---

## 四、验证

### 完整流程模拟

写了 `_simulate-ci.ps1`，按 CI 的步骤完整跑一遍：

```
=== 模拟 CI 的 JRE 装配流程 ===
  JRE 17 : OK  103.2 MB  libjli 129 KB
  JRE 21 : OK  119.9 MB  libjli 129 KB
  JRE 25 : OK  119.8 MB  libjli 130 KB

结果: 3 套成功, 0 套失败

=== 关键文件校验（对应 CI 的校验步骤）===
  OK  java-17-openjdk/lib/libjli.dylib
```

**三套全部正确装配，`libjli.dylib` 在预期位置。**

### YAML 语法

```
.github/workflows/build.yml: 241 行  OK（无 TAB 缩进问题）
codemagic.yaml:             360 行  OK
```

---

## 五、影响

修复前：

```
构建流程：编译成功 → 装配 JRE 时 curl 404 → 整个 job 失败
产物：无
```

修复后：

```
构建流程：编译成功 → 从仓库内复制 JRE → 解压校验 → 打包 IPA → 发布
产物：新 IPA（含这九轮所有修复）
```

---

## 六、注意事项

### 仓库体积

`.git` 会多出 67 MB。GitHub 单仓库建议不超过 1 GB，67 MB 完全没问题。

如果以后想瘦身，可以把 `jre/` 从仓库移除，改成发布到 `jre-assets` 这个 release 标签下，CI 走 ② 那条回退。

### 为什么不放 LFS

Git LFS 需要额外配置，且 clone 时不会自动拉取（要 `git lfs pull`），
在 GitHub Actions 里容易踩坑。直接放普通文件最省心。

### JRE 8 没有

codemagic 里还留着 JRE 8 的循环（MC 1.12 及以下需要），
但我们的 IPA 里本来就没有 8，所以那个分支会走「三源都拿不到，跳过」的提示。

如果要支持 MC 1.12 以下，得另外找 JRE 8 for iOS。

---

## 七、下一步

1. 推送代码到 GitHub
2. Actions 应该能跑通（编译 + 装配 + 打包）
3. 检查产物 IPA 大小是否约 132 MB
4. 下载验证结构

如果新 IPA 出来，交付包里那个就可以换掉了——现在那个是修复前的版本。
