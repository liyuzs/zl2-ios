#!/usr/bin/env python3
# check_project.py —— 没有 Swift 编译器时的静态体检
# 用法：python3 scripts/check_project.py
import re, sys, glob, os, json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
problems, warnings = [], []

def read_all():
    out = {}
    for f in sorted(glob.glob(os.path.join(SRC, "*.swift"))):
        out[os.path.basename(f)] = open(f, encoding="utf-8").read()
    return out

files = read_all()
if not files:
    print("✗ src/ 下没有 Swift 文件"); sys.exit(1)

print(f"文件数: {len(files)}")

# 1. 括号平衡：字符级状态机（正确处理字符串 / 注释 / 插值）
def bracket_errors(text):
    stack = []
    in_str = in_line = in_block = esc = False
    interp = 0
    errors = []
    pair = {"}": "{", ")": "(", "]": "["}
    for i, ch in enumerate(text):
        nxt = text[i + 1] if i + 1 < len(text) else ""
        if in_line:
            if ch == "\n":
                in_line = False
            continue
        if in_block:
            if ch == "*" and nxt == "/":
                in_block = False
            continue
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == "(":
                interp += 1
            elif ch == ")" and interp > 0:
                interp -= 1
            elif ch == '"' and interp == 0:
                in_str = False
            continue
        if ch == "/" and nxt == "/":
            in_line = True
            continue
        if ch == "/" and nxt == "*":
            in_block = True
            continue
        if ch == '"':
            in_str = True
            continue
        if ch in "{([":
            stack.append((ch, i))
        elif ch in "})]":
            if not stack:
                errors.append(f"多余的 {ch}（字符位置 {i}）")
            else:
                op, pos = stack.pop()
                if pair[ch] != op:
                    errors.append(f"错配：{op}@{pos} 与 {ch}@{i}")
    if stack:
        errors.append("未闭合：" + ", ".join(f"{c}@{p}" for c, p in stack[-3:]))
    return errors

for name, text in files.items():
    for e in bracket_errors(text):
        problems.append(f"{name}: {e}")

# 2. @main 只能有一个
mains = [n for n, t in files.items() if re.search(r'^\s*@main\b', t, re.M)]
if len(mains) != 1:
    problems.append(f"@main 数量为 {len(mains)}（应为 1）: {mains}")

# 3. 顶层类型重复定义
defs = {}
for name, text in files.items():
    for m in re.finditer(r'^(?:public |private |internal )?(?:final )?(?:struct|class|enum|actor|protocol)\s+(\w+)', text, re.M):
        defs.setdefault(m.group(1), []).append(name)
for t, where in defs.items():
    if len(where) > 1:
        problems.append(f"类型 {t} 重复定义于: {where}")

# 4. 引用检查：找出所有大写开头的标识符，排除系统框架与已知类型
SYSTEM = set("""
SwiftUI UIKit Foundation Combine Swift CryptoKit DispatchCore
String Int Double Float Bool Character Void Any AnyObject Self Array Set Dictionary Optional Result Error Never
Color Text Image Button HStack VStack ZStack ScrollView ForEach Spacer Divider Circle Capsule Rectangle
RoundedRectangle Section List Toggle Slider Stepper Menu TextField NavigationStack NavigationView
GeometryReader GeometryProxy Binding State StateObject ObservedObject Published AppStorage ScenePhase
ColorScheme EdgeInsets Edge Set Alignment Axis View App Scene WindowGroup ViewBuilder ViewModifier
Identifiable Equatable Hashable Codable CaseIterable Comparable CustomStringConvertible Equatable
CharacterSet DispatchQueue UUID Date URL URLRequest URLSession HTTPURLResponse Data FileManager
JSONEncoder JSONDecoder CodingKeys CodingKey Timestamp Duration Calendar Locale Bundle
Group EmptyView ProgressView Label Link Grid LazyVGrid LazyHGrid GridItem NavigationLink
AngularGradient LinearGradient RadialGradient Material TimelineView Canvas Path Shape InsettableShape
Animation Transaction withAnimation Transition AnyTransition StrokeStyle UnitPoint Anchor Namespace
Font FontWeight FontDesign text Alignment LineLimit ContentMode SafeAreaRegions Axis
Print MARK TODO FIXME SwiftUI UIViewController NSObject NSNumber NSString
""".split())

used = set()
for text in files.values():
    for m in re.finditer(r'\b([A-Z][A-Za-z0-9_]*)\b', text):
        used.add(m.group(1))

defined = set(defs.keys())
unknown = sorted(u for u in used if u not in defined and u not in SYSTEM)
# 过滤掉注释里出现的英文单词（全大写缩写、专有名词）
noise = set("""
MARK GPL FPS MC JEI BM DSH ID UUID API JSON YAML HTTP HTTPS IP IPA JIT SDK Xcode GitHub Actions
Amethyst Zalith Launcher Minecraft Forge Fabric Quilt NeoForge Modrinth Mojang Build
Private GPL LGPL
""".split())
unknown = [u for u in unknown if len(u) > 2 and u not in noise]

if unknown:
    warnings.append("以下是未在本项目定义、也不在系统白名单里的类型（可能是拼错或外部依赖）:")
    warnings.append("  " + ", ".join(unknown[:40]))
    if len(unknown) > 40:
        warnings.append(f"  ...共 {len(unknown)} 个")

# 5. 检查 import 是否有 SwiftUI 但文件里没有 View
for name, text in files.items():
    if "import SwiftUI" in text and "View" not in text and "App" not in text:
        warnings.append(f"{name}: 导入 SwiftUI 但没用到 View/App")

# 6. project.yml 的 sources 应覆盖 src
proj = os.path.join(ROOT, "project.yml")
if os.path.exists(proj):
    p = open(proj).read()
    if "path: src" not in p:
        problems.append("project.yml 的 sources 没有指向 src/")

# 7. workflow 必须在正确路径
wf = os.path.join(ROOT, ".github/workflows/build.yml")
if not os.path.exists(wf):
    problems.append("缺少 .github/workflows/build.yml")

# 输出
print("\n=== 类型定义 ===")
print("  " + ", ".join(sorted(defined)))

if warnings:
    print("\n=== 警告 ===")
    for w in warnings: print("  ⚠ " + w)

if problems:
    print("\n=== 错误 ===")
    for p in problems: print("  ✗ " + p)
    sys.exit(1)

print("\n✓ 静态检查通过（注意：这不等于能编译，真正的验证只能靠 Xcode / GitHub Actions）")
