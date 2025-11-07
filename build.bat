@echo off
rem 复制覆盖文件到子项目
xcopy /Y /I overrides\lib code_lfa-1.6.1\lib
rem 复制assets文件
if exist overrides\assets\* xcopy /Y /I overrides\assets code_lfa-1.6.1\assets

rem 进入子项目目录并构建
cd code_lfa
flutter build apk

rem 返回根目录
cd ..