# 切换到脚本所在目录
Set-Location $PSScriptRoot

# 创建临时目录
if (-not (Test-Path "temp_build")) { 
    New-Item -ItemType Directory -Path "temp_build" | Out-Null 
    Copy-Item "code_lfa-1.6.1" "temp_build\code_lfa-1.6.1" -Recurse -Force
}

# 复制 overrides 下的 pubspec_overrides.yaml
Copy-Item "overrides\pubspec_overrides.yaml" "temp_build\pubspec_overrides.yaml" -Force

# 复制 overrides\assets 到 temp_build\assets（覆盖式复制）
Copy-Item "overrides\assets\*" "temp_build\assets" -Recurse -Force

# 复制 overrides\lib 到 temp_build\lib（覆盖式复制）
Copy-Item "overrides\lib\*" "temp_build\lib" -Recurse -Force

# 写入Android SDK路径
"sd`k.dir=$env:ANDROID_HOME" | Out-File "temp_build\android\local.properties" -Encoding UTF8 -Force

# 进入项目目录构建
Set-Location "temp_build"
flutter clean
flutter pub get --no-example
flutter build apk --release

# 复制APK到输出目录
if ($LASTEXITCODE -eq 0) {
    if (-not (Test-Path "../../build_output")) { New-Item -ItemType Directory -Path "../../build_output" | Out-Null }
    Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "../../build_output/AstrBot-$(Get-Date -Format yyyyMMdd).apk" -Force
    Write-Host "`nAPK构建并复制成功！" -ForegroundColor Green
} else {
    Write-Host "`n构建失败！" -ForegroundColor Red
}

# 回到原目录并暂停
Set-Location $PSScriptRoot
Read-Host "按Enter退出"