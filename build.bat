@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: 获取脚本所在目录
set "PSScriptRoot=%~dp0"
cd /d "%PSScriptRoot%"

:: 创建临时目录
if not exist "temp_build" (
    mkdir temp_build
    xcopy "code_lfa-1.6.1" "temp_build" /E /I /Y
)

:: 复制 overrides\pubspec_overrides.yaml
copy /Y "overrides\pubspec_overrides.yaml" "temp_build\pubspec_overrides.yaml"

:: 复制 overrides\assets 到 code_lfa-1.6.1\assets（覆盖式复制）
if exist "overrides\assets" (
    xcopy "overrides\assets\*" "temp_build\assets" /E /I /Y
)

:: 复制 overrides\lib 到 code_lfa-1.6.1\lib（覆盖式复制）
if exist "overrides\lib" (
    xcopy "overrides\lib\*" "temp_build\lib" /E /I /Y
)

:: 写入Android SDK路径
echo sdk.dir=%ANDROID_HOME% > "temp_build\android\local.properties"

:: 进入项目目录构建
cd temp_build

call flutter clean
call flutter pub get --no-example
call flutter build apk --release

:: 检查构建是否成功
if %errorlevel% equ 0 (
    if not exist "..\..\build_output" mkdir ..\..\build_output
    for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (
        set "mm=%%a"
        set "dd=%%b"
        set "yyyy=%%c"
    )
    set "today=!yyyy!!mm!!dd!"
    copy /Y "build\app\outputs\flutter-apk\app-release.apk" "..\..\build_output\AstrBot-!today!.apk"
    echo.
    echo APK构建并复制成功！
) else (
    echo.
    echo 构建失败！
)

:: 回到原目录
cd /d "%PSScriptRoot%"
pause