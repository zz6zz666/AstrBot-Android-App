import 'package:global_repository/global_repository.dart';
import 'config.dart';
import 'generated/l10n.dart';

// proot distro，ubuntu path
String prootDistroPath = '${RuntimeEnvir.usrPath}/var/lib/proot-distro';
String ubuntuPath = '$prootDistroPath/installed-rootfs/ubuntu-noble';
String ubuntuName = Config.ubuntuFileName.replaceAll(RegExp('-pd.*'), '');

// 通用环境变量和函数模块 - 提供环境配置、进度更新和屏幕操作功能
String common = '''
# 环境变量配置
export TMPDIR=${RuntimeEnvir.tmpPath}
export BIN=${RuntimeEnvir.binPath}
export HOME=/root
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
export PROOT_LOADER=/data/data/com.astrobot.code_lfa/files/proot
export PROOT_LOADER_LIBPATH=/data/data/com.astrobot.code_lfa/files/lib
export LD_LIBRARY_PATH=/data/data/com.astrobot.code_lfa/files/lib
export UBUNTU_PATH=$ubuntuPath
export UBUNTU=${Config.ubuntuFileName}
export UBUNTU_NAME=$ubuntuName
export PORT=${Config.port}
export ASTRBOT_FILE=${Config.astrBotFileName}

# 进度更新函数 - 更新安装进度和描述信息
bump_progress() {
  # 获取当前进度值，默认为0
  current=0
  if [ -f "/data/data/com.astrobot.code_lfa/app_flutter/progress" ]; then
    current=$(cat "/data/data/com.astrobot.code_lfa/app_flutter/progress" 2>/dev/null || echo 0)
  fi
  
  # 计算下一个进度值
  next=$((current + 1))
  
  # 更新进度文件
  printf "$next" > "/data/data/com.astrobot.code_lfa/app_flutter/progress"
  
  # 更新进度描述
  echo "$1" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  
  # 输出日志便于调试
  echo "[进度] $next - $1"
}

# 清空行函数 - 清理终端输出的两行内容
clear_lines() {
  printf "\033[1A" # 光标上移一行
  printf "\033[K"  # 清空该行
  printf "\033[1A" # 光标再次上移一行
  printf "\033[K"  # 清空该行
}

# 进度输出函数 - 以醒目颜色输出进度信息并更新进度描述
progress_echo() {
  # 以红色输出信息
  echo -e "\033[31m- \$@\033[0m"
  
  # 更新进度描述文件
  echo "\$@" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
}
''';

// 切换到清华源模块 - 配置清华大学镜像源以加速软件包安装和更新
String changeUbuntuSource = r'''
# 配置Ubuntu源为清华大学镜像源并设置DNS
change_ubuntu_source(){
  progress_echo "正在配置Ubuntu源..."
  
  # 检查Ubuntu路径是否存在
  if [ ! -d "$UBUNTU_PATH/etc/apt" ]; then
    echo "Ubuntu路径不存在或结构不完整"
    return 1
  fi
  
  # 创建源配置文件
  cat <<EOF > $UBUNTU_PATH/etc/apt/sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
# Defaultly commented out source mirrors to speed up apt update, uncomment if needed
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-backports main restricted universe multiverse

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
# The following security update software sources include both official and mirror configurations, modify comments to switch if needed
# deb http://ports.ubuntu.com/ubuntu-ports/ noble-security main restricted universe multiverse
# deb-src http://ports.ubuntu.com/ubuntu-ports/ noble-security main restricted universe multiverse

# 预发布软件源，不建议启用
# The following pre-release software sources are not recommended to be enabled
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-proposed main restricted universe multiverse
# # deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ noble-proposed main restricted universe multiverse
EOF
  
  if [ $? -ne 0 ]; then
    echo "写入源配置文件失败"
    return 1
  fi
  
  # 设置DNS
  echo 'nameserver 8.8.8.8' > $UBUNTU_PATH/etc/resolv.conf
  
  if [ $? -ne 0 ]; then
    echo "设置DNS失败"
    return 1
  fi
  
  echo "Ubuntu源配置完成，已切换至清华大学镜像源并配置DNS"
  return 0
}''';

// 安装 proot-distro 模块 - 部署proot-distro工具以支持Ubuntu环境
String installProotDistro = r'''
# 安装proot-distro工具，用于管理和运行Linux发行版容器
install_proot_distro(){
  bump_progress "正在安装proot-distro..."
  
  # 检查proot-distro是否已安装
  proot_distro_path=$(which proot-distro 2>/dev/null)
  if [ -z "$proot_distro_path" ]; then
    progress_echo "proot-distro 未安装，正在安装..."
    
    # 检查运行时目录是否存在
    runtime_dir="/data/data/com.astrobot.code_lfa/app_flutter/runtime"
    if [ ! -d "$runtime_dir" ]; then
      echo "运行时目录不存在: $runtime_dir"
      return 1
    fi
    
    # 检查压缩包是否存在
    if [ ! -f "$runtime_dir/proot-distro.zip" ]; then
      echo "proot-distro压缩包不存在"
      return 1
    fi
    
    # 解压并安装proot-distro
    cd "$runtime_dir" || {
      echo "切换到运行时目录失败"
      return 1
    }
    
    busybox unzip proot-distro.zip -d proot-distro || {
      echo "解压proot-distro失败"
      return 1
    }
    
    cd proot-distro || {
      echo "切换到proot-distro目录失败"
      return 1
    }
    
    chmod +x proot-distro || {
      echo "设置proot-distro执行权限失败"
      return 1
    }
    
    export PATH=$PATH:"$runtime_dir/proot-distro"
    echo "proot-distro 安装完成"
  else
    progress_echo "proot-distro 已安装: $proot_distro_path"
  fi
  
  # 验证安装是否成功
  if command -v proot-distro >/dev/null 2>&1; then
    return 0
  else
    echo "proot-distro安装验证失败"
    return 1
  fi
}''';

// 安装Ubuntu模块 - 使用proot-distro安装Ubuntu系统环境
String installUbuntu = r'''
# 安装Ubuntu系统环境
install_ubuntu(){
  bump_progress "正在安装Ubuntu系统..."
  
  # 检查proot-distro是否可用
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro命令不可用，请先安装proot-distro"
    return 1
  fi
  
  # 创建挂载目录并检查结果
  mkdir -p $UBUNTU_PATH 2>/dev/null || {
    echo "创建Ubuntu挂载目录失败"
    return 1
  }
  
  # 检查Ubuntu是否已安装
  if [ -z "$(ls -A $UBUNTU_PATH 2>/dev/null)" ]; then
    progress_echo "Ubuntu 未安装，正在安装..."
    
    # 定义Ubuntu安装包路径
    UBUNTU_TAR_PATH="/data/data/com.astrobot.code_lfa/app_flutter/runtime/ubuntu-noble-aarch64-pd-v4.18.0.tar.xz"
    
    # 检查安装包是否存在
    if [ ! -f "$UBUNTU_TAR_PATH" ]; then
      echo "Ubuntu安装包不存在: $UBUNTU_TAR_PATH"
      return 1
    fi
    
    # 开始安装Ubuntu
    proot-distro install "$UBUNTU_TAR_PATH"
    
    # 检查安装结果
    if [ $? -ne 0 ]; then
      echo "Ubuntu安装失败"
      return 1
    fi
    
    # 切换Ubuntu源以提高后续操作速度
    progress_echo "安装完成，正在配置Ubuntu源..."
    change_ubuntu_source
  else
    # 获取已安装的Ubuntu版本信息
    VERSION=$(cat "$UBUNTU_PATH/etc/issue.net" 2>/dev/null || echo "未知版本")
    progress_echo "Ubuntu 已安装 -> $VERSION"
    
    # 确保源已切换为国内镜像源
    progress_echo "确保Ubuntu源已配置为国内镜像..."
    change_ubuntu_source
  fi
  
  return 0
}
''';

// 配置网络模块 - 设置DNS和hosts文件以确保Ubuntu容器网络正常工作
String configNetwork = r'''
# 配置Ubuntu容器的网络设置
config_network(){
  bump_progress "正在配置网络..."
  
  # 检查Ubuntu路径是否存在
  if [ ! -d "$UBUNTU_PATH/etc" ]; then
    echo "Ubuntu网络配置目录不存在"
    return 1
  fi
  
  # 确保DNS配置正确 - 使用Google DNS
  echo 'nameserver 8.8.8.8' > "$UBUNTU_PATH/etc/resolv.conf" || {
    echo "设置DNS配置失败"
    return 1
  }
  
  # 确保hosts文件配置正确
  echo '127.0.0.1 localhost' > "$UBUNTU_PATH/etc/hosts" || {
    echo "设置hosts文件失败"
    return 1
  }
  echo '::1 localhost ip6-localhost ip6-loopback' >> "$UBUNTU_PATH/etc/hosts" || {
    echo "更新hosts文件失败"
    return 1
  }
  
  echo "网络配置完成"
  return 0
}
''';

// 安装依赖模块 - 安装AstrBot和napcat所需的系统依赖包
String installDependencies = r'''
# 安装系统依赖包
install_dependencies(){
  bump_progress "正在安装系统依赖..."
  
  # 检查proot-distro是否可用
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro命令不可用，请先安装proot-distro"
    return 1
  fi
  
  # 使用proot-distro登录Ubuntu并安装依赖
  proot-distro login ubuntu-noble -- bash -c '
    echo "更新apt源并安装系统依赖..."
    
    # 更新apt源
    apt update -y || {
      echo "apt源更新失败"
      exit 1
    }
    
    # 安装必要的系统依赖包
    apt install -y python3 python3-venv python3-pip unzip curl wget || {
      echo "依赖包安装失败"
      exit 1
    }
    
    # 升级pip到最新版本
    pip install --upgrade pip -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || {
      echo "pip升级失败"
      exit 1
    }
    
    # 清理缓存以节省空间
    apt clean
    echo "系统依赖安装完成"
    exit 0
  '
  
  # 检查安装结果
  if [ $? -eq 0 ]; then
    echo "系统依赖安装成功"
    return 0
  else
    echo "系统依赖安装失败"
    return 1
  fi
}
''';

// 准备napcat模块 - 将napcat启动脚本复制到Ubuntu容器并设置权限
String prepareNapcat = r'''
# 准备napcat启动脚本
prepare_napcat(){
  bump_progress "正在准备napcat..."
  
  # 检查napcat.sh文件是否存在
  NAPCAT_SH_PATH="/data/data/com.astrobot.code_lfa/app_flutter/runtime/napcat.sh"
  if [ ! -f "$NAPCAT_SH_PATH" ]; then
    echo "napcat.sh文件不存在: $NAPCAT_SH_PATH"
    return 1
  fi
  
  # 检查Ubuntu路径是否存在
  if [ ! -d "$UBUNTU_PATH/root" ]; then
    echo "Ubuntu容器root目录不存在"
    return 1
  fi
  
  # 复制napcat.sh到Ubuntu容器
  cp "$NAPCAT_SH_PATH" "$UBUNTU_PATH/root/" || {
    echo "复制napcat.sh失败"
    return 1
  }
  
  # 设置执行权限
  chmod +x "$UBUNTU_PATH/root/napcat.sh" || {
    echo "设置napcat.sh执行权限失败"
    return 1
  }
  
  echo "napcat准备完成"
  return 0
}
''';

// 准备AstrBot模块 - 将AstrBot压缩包复制到Ubuntu容器
String prepareAstrBot = r'''
# 准备AstrBot压缩包
prepare_astrbot(){
  bump_progress "正在准备AstrBot..."
  
  # 检查AstrBot文件是否存在
  ASTRBOT_PATH="/data/data/com.astrobot.code_lfa/app_flutter/runtime/$ASTRBOT_FILE"
  if [ ! -f "$ASTRBOT_PATH" ]; then
    echo "AstrBot文件不存在: $ASTRBOT_PATH"
    return 1
  fi
  
  # 检查Ubuntu路径是否存在
  if [ ! -d "$UBUNTU_PATH/root" ]; then
    echo "Ubuntu容器root目录不存在"
    return 1
  fi
  
  # 复制AstrBot文件到Ubuntu容器
  cp "$ASTRBOT_PATH" "$UBUNTU_PATH/root/" || {
    echo "复制AstrBot文件失败"
    return 1
  }
  
  echo "AstrBot准备完成"
  return 0
}
''';

// 初始化和配置AstrBot模块 - 解压AstrBot并配置其运行环境
String setupAstrBot = r'''
# 初始化和配置AstrBot
setup_astrbot(){
  bump_progress "正在初始化AstrBot..."
  
  # 检查proot-distro是否可用
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro命令不可用，请先安装proot-distro"
    return 1
  fi
  
  # 登录Ubuntu并初始化AstrBot
  proot-distro login ubuntu-noble -- bash -c '
    # 确保环境变量一致
    export HOME=/root
    export PORT=$PORT
    export ASTRBOT_FILE=$ASTRBOT_FILE
    
    # 检查AstrBot文件是否存在
    if [ ! -f "/root/$ASTRBOT_FILE" ]; then
      echo "AstrBot文件不存在: /root/$ASTRBOT_FILE"
      exit 1
    fi
    
    # 准备AstrBot目录结构
    mkdir -p /root/AstrBot || {
      echo "创建AstrBot目录失败"
      exit 1
    }
    
    # 解压AstrBot文件
    echo "正在解压AstrBot文件..."
    unzip -q /root/$ASTRBOT_FILE -d /root/AstrBot || {
      echo "解压AstrBot文件失败"
      exit 1
    }
    
    # 处理嵌套目录结构（处理不同的解压结果）
    echo "正在处理目录结构..."
    if [ -d "/root/AstrBot/AstrBot" ]; then
      mv /root/AstrBot/AstrBot/* /root/AstrBot/
      rmdir /root/AstrBot/AstrBot
    elif [ -d "/root/AstrBot-4.5.4" ]; then
      # 如果解压到了带版本号的目录，重命名为不带版本号
      mv /root/AstrBot-4.5.4 /root/AstrBot_new
      mv /root/AstrBot_new/* /root/AstrBot/
      rmdir /root/AstrBot_new
    fi
    
    # 设置AstrBot文件权限
    chmod -R +x /root/AstrBot
    
    # 记录安装日志
    echo "AstrBot已成功解压到/root/AstrBot目录并处理了嵌套结构" > /root/astrbot_install.log
    
    # 进入AstrBot目录
    cd /root/AstrBot || {
      echo "进入AstrBot目录失败"
      exit 1
    }
    
    # 创建Python虚拟环境
    echo "正在创建Python虚拟环境..."
    python3 -m venv ./venv || {
      echo "创建Python虚拟环境失败"
      exit 1
    }
    
    # 激活虚拟环境并安装依赖
    echo "正在安装Python依赖..."
    source venv/bin/activate
    pip install -r requirements.txt -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple || {
      echo "安装Python依赖失败"
      exit 1
    }
    
    echo "AstrBot初始化完成"
    exit 0
  '
  
  # 检查初始化结果
  if [ $? -eq 0 ]; then
    echo "AstrBot初始化成功"
    return 0
  else
    echo "AstrBot初始化失败"
    return 1
  fi
}
}
''';

// 初始化napcat模块 - 运行napcat安装脚本进行初始化
String setupNapcat = r'''
# 初始化napcat
setup_napcat(){
  bump_progress "正在初始化napcat..."
  
  # 检查proot-distro是否可用
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro命令不可用，请先安装proot-distro"
    return 1
  fi
  
  # 登录Ubuntu并初始化napcat
  proot-distro login ubuntu-noble -- bash -c '
    # 检查napcat.sh文件是否存在
    if [ ! -f "/root/napcat.sh" ]; then
      echo "napcat.sh文件不存在"
      exit 1
    fi
    
    # 确保napcat.sh有执行权限
    chmod +x /root/napcat.sh || {
      echo "设置napcat.sh执行权限失败"
      exit 1
    }
    
    # 进入root目录
    cd /root || {
      echo "进入root目录失败"
      exit 1
    }
    
    # 运行napcat安装脚本
    echo "正在运行napcat安装脚本..."
    bash ./napcat.sh || {
      echo "运行napcat.sh失败"
      exit 1
    }
    
    echo "napcat初始化完成"
    exit 0
  '
  
  # 检查初始化结果
  if [ $? -eq 0 ]; then
    echo "napcat初始化成功"
    return 0
  else
    echo "napcat初始化失败"
    return 1
  fi
}
}
''';

// 创建启动脚本模块 - 为AstrBot和napcat创建便捷启动脚本
String createStartScripts = r'''
# 创建启动脚本
create_start_scripts(){
  bump_progress "正在创建启动脚本..."
  
  # 检查proot-distro是否可用
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro命令不可用，请先安装proot-distro"
    return 1
  fi
  
  # 登录Ubuntu并创建启动脚本
  proot-distro login ubuntu-noble -- bash -c '
    # 创建AstrBot启动脚本
    echo "正在创建AstrBot启动脚本..."
    cat > /root/start_astrbot.sh << "EOF"
#!/bin/bash
# AstrBot启动脚本
cd /root/AstrBot
source venv/bin/activate
python main.py
EOF
    
    if [ $? -ne 0 ]; then
      echo "创建AstrBot启动脚本失败"
      exit 1
    fi
    
    chmod +x /root/start_astrbot.sh || {
      echo "设置AstrBot启动脚本权限失败"
      exit 1
    }
    
    # 创建napcat启动脚本
    echo "正在创建napcat启动脚本..."
    cat > /root/start_napcat.sh << "EOF"
#!/bin/bash
# napcat启动脚本
cd /root/napcat
bash ./launcher.sh
EOF
    
    if [ $? -ne 0 ]; then
      echo "创建napcat启动脚本失败"
      exit 1
    fi
    
    chmod +x /root/start_napcat.sh || {
      echo "设置napcat启动脚本权限失败"
      exit 1
    }
    
    echo "启动脚本创建完成"
    exit 0
  '
  
  # 检查创建结果
  if [ $? -eq 0 ]; then
    echo "启动脚本创建成功"
    return 0
  else
    echo "启动脚本创建失败"
    return 1
  fi
}
}
''';

// 启动服务模块 - 启动AstrBot和napcat服务并保持容器运行
String startServices = r'''
# 启动服务
start_services(){
  bump_progress "正在启动服务..."
  
  # 检查proot-distro是否可用
  if ! command -v proot-distro >/dev/null 2>&1; then
    echo "proot-distro命令不可用，请先安装proot-distro"
    return 1
  fi
  
  # 登录Ubuntu并启动服务
  proot-distro login ubuntu-noble -- bash -c '
    # 检查启动脚本是否存在
    if [ ! -f "/root/start_astrbot.sh" ]; then
      echo "AstrBot启动脚本不存在"
      exit 1
    fi
    
    if [ ! -f "/root/start_napcat.sh" ]; then
      echo "napcat启动脚本不存在"
      exit 1
    fi
    
    # 启动AstrBot服务
    echo "正在启动AstrBot服务..."
    nohup /root/start_astrbot.sh > /root/astrbot.log 2>&1 &
    ASTRBOT_PID=$!
    echo "AstrBot服务启动，PID: $ASTRBOT_PID"
    
    # 等待一段时间确保服务启动
    sleep 3
    
    # 启动napcat服务
    echo "正在启动napcat服务..."
    nohup /root/start_napcat.sh > /root/napcat.log 2>&1 &
    NAPCAT_PID=$!
    echo "napcat服务启动，PID: $NAPCAT_PID"
    
    # 等待一段时间确保服务启动
    sleep 3
    
    # 记录服务状态
    echo "服务启动时间: $(date)" > /root/services_status.log
    echo "AstrBot PID: $ASTRBOT_PID" >> /root/services_status.log
    echo "napcat PID: $NAPCAT_PID" >> /root/services_status.log
    
    echo "所有服务启动完成"
    
    # 启动监控服务器以避免容器退出
    echo "正在启动监控服务器..."
    python3 -m http.server $PORT
  '
  
  # 由于这是一个长时间运行的进程，这里不检查返回值
  return 0
}
}
''';

// 主启动脚本 - 整合所有功能模块并按顺序执行安装流程
String start_custom_service = '''
#!/data/data/com.astrobot.code_lfa/files/busybox sh
# 导入所有功能模块
$common
$changeUbuntuSource
$installProotDistro
$installUbuntu
$configNetwork
$installDependencies
$prepareNapcat
$prepareAstrBot
$setupAstrBot
$setupNapcat
$createStartScripts

# 初始化进度文件
echo "0" > "/data/data/com.astrobot.code_lfa/app_flutter/progress"
echo "准备开始安装..." > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"

# 执行主安装流程
clear_lines
bump_progress "开始安装AstrBot和napcat环境..."
sleep 1

# 步骤1: 安装proot-distro
install_proot_distro || {
  echo "proot-distro安装失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "proot-distro安装完成"

# 步骤2: 安装Ubuntu系统
install_ubuntu || {
  echo "Ubuntu安装失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "Ubuntu安装完成"

# 步骤3: 配置网络
config_network
sleep 1
bump_progress "网络配置完成"

# 步骤4: 安装系统依赖
install_dependencies || {
  echo "系统依赖安装失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "依赖安装完成"

# 步骤5: 准备napcat文件
prepare_napcat || {
  echo "napcat文件准备失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "napcat准备完成"

# 步骤6: 准备AstrBot文件
prepare_astrbot || {
  echo "AstrBot文件准备失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "AstrBot准备完成"

# 步骤7: 初始化AstrBot
setup_astrbot || {
  echo "AstrBot初始化失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "AstrBot初始化完成"

# 步骤8: 初始化napcat
setup_napcat || {
  echo "napcat初始化失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "napcat初始化完成"

# 步骤9: 创建启动脚本
create_start_scripts || {
  echo "启动脚本创建失败" > "/data/data/com.astrobot.code_lfa/app_flutter/progress_des"
  exit 1
}
sleep 1
bump_progress "启动脚本创建完成"

# 步骤10: 启动服务
start_services
'';