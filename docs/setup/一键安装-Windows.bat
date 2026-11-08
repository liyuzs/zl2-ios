@echo off
chcp 65001 >nul
title CraftLauncher 一键安装助手
color 0B

echo.
echo  ============================================
echo      CraftLauncher 一键安装助手
echo      非官方 iOS 移植版  Minecraft Java 启动器
echo  ============================================
echo.
echo  这个脚本会帮你准备好安装环境。
echo  全程免费，只需要你的 Apple ID。
echo.

echo  [1/4] 检查 iTunes / Apple 驱动...
reg query "HKLM\SOFTWARE\Apple Inc.\Apple Mobile Device Support" >nul 2>&1
if %errorlevel% neq 0 (
    echo  [!] 没有检测到 Apple 驱动
    echo.
    echo  请先安装 iTunes（微软商店或苹果官网都行）
    echo  安装完再运行这个脚本
    echo.
    pause
    start https://www.apple.com/itunes/
    exit /b
) else (
    echo  [OK] Apple 驱动已安装
)
echo.

echo  [2/4] 检查数据线连接...
echo.
echo  请用数据线把 iPhone 连到电脑
echo  然后在手机上点「信任此电脑」
echo.
pause
echo  [OK] 继续
echo.

echo  [3/4] 下载 SideStore 安装器...
echo.
set "DL=%USERPROFILE%\Downloads\CraftLauncher-Setup"
if not exist "%DL%" mkdir "%DL%"
cd /d "%DL%"

echo  正在下载 iLoader（用于安装 SideStore）...
powershell -Command "& {$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri 'https://github.com/SideStore/iLoader/releases/latest/download/iLoader-Windows.zip' -OutFile 'iLoader.zip' -UseBasicParsing; Write-Host '[OK] 下载完成' } catch { Write-Host '[!] 下载失败，请手动到 GitHub 搜索 iLoader' }}"

if exist "iLoader.zip" (
    echo  正在解压...
    powershell -Command "Expand-Archive -Path 'iLoader.zip' -DestinationPath '.' -Force"
    echo.
    echo  [OK] 已解压到: %DL%
    echo.
    echo  接下来：
    echo    1. 打开这个文件夹里的 iLoader
    echo    2. 点「Install SideStore」
    echo    3. 按屏幕提示操作
) else (
    echo.
    echo  [!] 自动下载失败，请手动操作：
    echo      打开 https://github.com/SideStore/iLoader/releases
    echo      下载 Windows 版，解压后运行
)

echo.
echo  [4/4] 装完之后...
echo.
echo  ============================================
echo   手机上的操作：
echo.
echo   1. 打开 SideStore
echo   2. 用你的 Apple ID 登录（免费账号即可）
echo   3. 点 Sources → 添加源
echo   4. 填入这个地址：
echo.
echo      https://liyuzs.github.io/zl2-ios/source/apps.json
echo.
echo   5. 找到 CraftLauncher，点安装
echo  ============================================
echo.
echo  安装包位置：
echo    https://github.com/liyuzs/zl2-ios/releases
echo.
echo  有问题去 GitHub 提 issue。
echo.
pause
