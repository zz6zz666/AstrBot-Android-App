#!/bin/bash
# 复制覆盖文件到子项目
cp -r overrides/lib/* code_lfa-1.6.1/lib/
# 复制assets文件
if [ -d "overrides/assets" ]; then
  cp -r overrides/assets/* code_lfa-1.6.1/assets/
fi

# 进入子项目目录并构建
cd code_lfa
flutter build apk

# 返回根目录
cd ..