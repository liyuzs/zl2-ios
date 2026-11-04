#!/bin/bash
# CraftLauncher 一键安装助手（macOS）
# 非官方 iOS 移植版 Minecraft Java 启动器

set -e
BOLD='\033[1m'; BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo ""
echo -e "${BOLD}============================================${NC}"
echo -e "${BOLD}    CraftLauncher 一键安装助手${NC}"
echo -e "    非官方 iOS 移植版  Minecraft Java 启动器"
echo -e "${BOLD}============================================${NC}"
echo ""
echo " 这个脚本会帮你准备好安装环境。"
echo " 全程免费，只需要你的 Apple ID。"
echo ""

# 1. 检查 Xcode 命令行工具（AltServer 需要）
echo -e "${BLUE}[1/4]${NC} 检查环境..."
if ! xcode-select -p &>/dev/null; then
    echo -e "  ${YELLOW}[!]${NC} 缺少 Xcode 命令行工具"
    echo "  正在安装（会弹出对话框，点「安装」）..."
    xcode-select --install || true
    echo ""
    echo "  安装完成后，重新运行这个脚本。"
    exit 1
fi
echo -e "  ${GREEN}[OK]${NC} Xcode 命令行工具已安装"

# 2. 检查 iPhone 连接
echo ""
echo -e "${BLUE}[2/4]${NC} 检查 iPhone 连接..."
DEVICES=$(system_profiler SPUSBDataType 2>/dev/null | grep -c "iPhone" || true)
if [ "$DEVICES" -eq 0 ]; then
    echo -e "  ${YELLOW}[!]${NC} 没有检测到 iPhone"
    echo "  请用数据线连接，并在手机上点「信任」"
    echo ""
    read -p "  连好后按回车继续..."
fi
echo -e "  ${GREEN}[OK]${NC} 设备就绪"

# 3. 下载并安装 SideStore
echo ""
echo -e "${BLUE}[3/4]${NC} 准备 SideStore..."
DL="$HOME/Downloads/CraftLauncher-Setup"
mkdir -p "$DL"
cd "$DL"

echo "  正在下载 iLoader..."
if curl -L --fail --retry 3 -o iLoader.dmg \
    "https://github.com/SideStore/iLoader/releases/latest/download/iLoader-macOS.dmg" 2>/dev/null; then
    echo -e "  ${GREEN}[OK]${NC} 下载完成: $DL/iLoader.dmg"
    echo ""
    echo "  接下来手动操作："
    echo "    1. 打开 $DL/iLoader.dmg"
    echo "    2. 把 iLoader 拖到 Applications"
    echo "    3. 运行 iLoader，点「Install SideStore」"
    echo ""
    read -p "  完成后按回车继续..."
else
    echo -e "  ${YELLOW}[!]${NC} 自动下载失败"
    echo "  请手动打开: https://github.com/SideStore/iLoader/releases"
    echo "  下载 macOS 版并安装"
    echo ""
    read -p "  完成后按回车继续..."
fi

# 4. 提示手机端操作
echo ""
echo -e "${BLUE}[4/4]${NC} 手机上的操作"
echo ""
echo -e "${BOLD}============================================${NC}"
echo "  1. 打开 SideStore"
echo "  2. 用你的 Apple ID 登录（免费账号即可）"
echo "  3. 点 Sources → 添加源"
echo "  4. 填入这个地址："
echo ""
echo -e "     ${GREEN}https://liyuzs.github.io/zl2-ios/source/apps.json${NC}"
echo ""
echo "  5. 找到 CraftLauncher，点安装"
echo -e "${BOLD}============================================${NC}"
echo ""
echo " 安装包位置："
echo "   https://github.com/liyuzs/zl2-ios/releases"
echo ""
echo " 有问题去 GitHub 提 issue。"
echo ""
