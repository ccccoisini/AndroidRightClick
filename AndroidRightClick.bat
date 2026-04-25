@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 如果传入了参数，说明是通过右键菜单调用的，直接跳转去处理文件
if not "%~1"=="" goto :process_file

:menu
echo ==========================================
echo       Android 快捷安装右键菜单管理
echo ==========================================
echo 请以【管理员身份】运行此脚本！
echo.
echo [1] 安装右键菜单
echo [2] 卸载右键菜单
echo.
set /p choice="请选择 (1/2): "

if "%choice%"=="1" goto :install_menu
if "%choice%"=="2" goto :uninstall_menu
echo 无效选择，按任意键退出...
pause >nul
exit /b

:install_menu
:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo [错误] 权限不足，请关闭后右键点击此脚本，选择“以管理员身份运行”！
    pause
    exit /b
)

set "SCRIPT_PATH=%~f0"

:: 注册 .apk 右键菜单
reg add "HKCR\SystemFileAssociations\.apk\shell\AndroidInstall" /v "" /t REG_SZ /d "📲 ADB 安装 APK" /f >nul
reg add "HKCR\SystemFileAssociations\.apk\shell\AndroidInstall\command" /v "" /t REG_SZ /d "\"!SCRIPT_PATH!\" \"%%1\"" /f >nul

:: 注册 .apks 右键菜单
reg add "HKCR\SystemFileAssociations\.apks\shell\AndroidInstall" /v "" /t REG_SZ /d "📲 ADB 安装 APKS" /f >nul
reg add "HKCR\SystemFileAssociations\.apks\shell\AndroidInstall\command" /v "" /t REG_SZ /d "\"!SCRIPT_PATH!\" \"%%1\"" /f >nul

:: 注册 .xapk 右键菜单 (新增)
reg add "HKCR\SystemFileAssociations\.xapk\shell\AndroidInstall" /v "" /t REG_SZ /d "📲 ADB 安装 XAPK" /f >nul
reg add "HKCR\SystemFileAssociations\.xapk\shell\AndroidInstall\command" /v "" /t REG_SZ /d "\"!SCRIPT_PATH!\" \"%%1\"" /f >nul

:: 注册 .zip 右键菜单
reg add "HKCR\SystemFileAssociations\.zip\shell\AndroidInstall" /v "" /t REG_SZ /d "📦 KSU 安装模块" /f >nul
reg add "HKCR\SystemFileAssociations\.zip\shell\AndroidInstall\command" /v "" /t REG_SZ /d "\"!SCRIPT_PATH!\" \"%%1\"" /f >nul

echo.
echo [成功] 右键菜单已成功添加！
echo 注意：请务必将此 .bat 文件放在一个固定的位置不要移动。如果移动了文件，请重新运行此脚本安装一次。
pause
exit /b

:uninstall_menu
:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo [错误] 权限不足，请关闭后右键点击此脚本，选择“以管理员身份运行”！
    pause
    exit /b
)

reg delete "HKCR\SystemFileAssociations\.apk\shell\AndroidInstall" /f >nul 2>&1
reg delete "HKCR\SystemFileAssociations\.apks\shell\AndroidInstall" /f >nul 2>&1
reg delete "HKCR\SystemFileAssociations\.xapk\shell\AndroidInstall" /f >nul 2>&1
reg delete "HKCR\SystemFileAssociations\.zip\shell\AndroidInstall" /f >nul 2>&1

echo.
echo [成功] 右键菜单已完全卸载！
pause
exit /b

:process_file
:: 获取文件路径和后缀名
set "FILE_PATH=%~1"
set "EXT=%~x1"

if /i "!EXT!"==".apk" goto :install_apk
if /i "!EXT!"==".apks" goto :install_apks
if /i "!EXT!"==".xapk" goto :install_apks
if /i "!EXT!"==".zip" goto :install_zip

echo [错误] 不支持的文件类型: !EXT!
pause
exit /b

:install_apk
echo ==========================================
echo 正在安装 APK...
echo 文件: "%FILE_PATH%"
echo ==========================================
adb install "%FILE_PATH%"
echo.
echo 执行完毕，按任意键退出...
pause >nul
exit /b

:install_apks
echo ==========================================
echo 正在安装 APKS / XAPK...
echo 文件: "%FILE_PATH%"
echo ==========================================

:: 在系统的临时目录下创建一个带随机数的文件夹，防止冲突
set "TEMP_DIR=%TEMP%\apks_extract_%RANDOM%"
mkdir "!TEMP_DIR!"

echo [1/3] 正在本地临时解压压缩包...
:: 利用 Windows 10/11 内置的 tar 命令直接解压
tar -xf "%FILE_PATH%" -C "!TEMP_DIR!"
if !errorlevel! neq 0 (
    echo [错误] 解压失败！可能文件已损坏。
    rd /s /q "!TEMP_DIR!"
    pause
    exit /b
)

echo.
echo [2/3] 正在调用 adb install-multiple 安装所有分卷...
:: 遍历解压目录，将所有 .apk 文件路径拼接到列表中
set "APK_LIST="
for /f "delims=" %%a in ('dir /b /s "!TEMP_DIR!\*.apk"') do (
    set "APK_LIST=!APK_LIST! "%%a""
)

:: 检查是否成功提取到 apk
if "!APK_LIST!"=="" (
    echo [错误] 压缩包内没有找到任何 .apk 文件！
    rd /s /q "!TEMP_DIR!"
    pause
    exit /b
)

:: 执行多文件同步安装
adb install-multiple !APK_LIST!

echo.
echo [3/3] 正在清理本地临时文件...
rd /s /q "!TEMP_DIR!"

echo.
echo 执行完毕，按任意键退出...
pause >nul
exit /b

:install_zip
echo ==========================================
echo 正在安装 KernelSU 模块...
echo 文件: "%FILE_PATH%"
echo ==========================================
:: 生成手机上的临时存放路径 (使用原文件名)
set "REMOTE_PATH=/data/local/tmp/%~nx1"

echo [1/3] 正在将 zip 推送到手机临时目录...
adb push "%FILE_PATH%" "!REMOTE_PATH!"

echo.
echo [2/3] 正在请求 root 权限并调用 ksud 进行安装...
:: 注意这里的双引号包裹，保证路径有空格也能执行
adb shell "su -c '/data/adb/ksu/bin/ksud module install \"!REMOTE_PATH!\"'"

echo.
echo [3/3] 正在清理手机中的临时 zip 文件...
adb shell "rm \"!REMOTE_PATH!\""

echo.
echo 执行完毕，按任意键退出...
pause >nul
exit /b