#!/bin/bash

# 切换到脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "$SCRIPT_DIR" || exit 1

# 创建临时目录
if [ ! -d "temp_build" ]; then
    mkdir -p "temp_build"
    cp -r "code_lfa-1.6.1" "temp_build"
fi


# 复制 overrides 下的 pubspec_overrides.yaml
cp -f "overrides/pubspec_overrides.yaml" "temp_build/pubspec_overrides.yaml"

# 复制 overrides/assets 到 temp_build/assets（覆盖式复制）
# 确保目标目录存在
mkdir -p "temp_build/assets"
cp -rf "overrides/assets/"* "temp_build/assets/"

# 复制 overrides/lib 到 temp_build/lib（覆盖式复制）
# 确保目标目录存在
mkdir -p "temp_build/lib"
cp -rf "overrides/lib/"* "temp_build/lib/"

# 写入Android SDK路径（检查环境变量是否存在）
if [ -z "$ANDROID_HOME" ]; then
    echo "警告：未设置 ANDROID_HOME 环境变量！"
    echo "sdk.dir=" > "temp_build/android/local.properties"
else
    echo "sdk.dir=$ANDROID_HOME" > "temp_build/android/local.properties"
fi

# 进入项目目录构建
cd "temp_build" || {
    echo "构建失败：无法进入项目目录！" >&2
    exit 1
}

# 执行Flutter构建命令
flutter clean
flutter pub get --no-example
flutter build apk --release

# 检查构建结果
if [ $? -eq 0 ]; then
    # 创建输出目录并复制APK（使用Linux格式的日期）
    OUTPUT_DIR="../../build_output"
    mkdir -p "$OUTPUT_DIR"
    APK_NAME="AstrBot-$(date +%Y%m%d).apk"
    cp -f "build/app/outputs/flutter-apk/app-release.apk" "$OUTPUT_DIR/$APK_NAME"
    
    echo -e "\n\033[32mAPK构建并复制成功！\033[0m"
    echo "输出路径：$OUTPUT_DIR/$APK_NAME"
else
    echo -e "\n\033[31m构建失败！\033[0m" >&2
    exit 1
fi

# 回到原目录并等待用户输入
cd "$SCRIPT_DIR" || exit 1
read -p "按Enter退出..."