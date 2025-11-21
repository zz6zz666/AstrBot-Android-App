import 'package:global_repository/global_repository.dart';
import 'config.dart';
import 'generated/l10n.dart';

// ubuntu path (保持原有路径结构，但不再使用 proot-distro)
// ubuntu path (keep original path structure, but no longer use proot-distro)
String prootDistroPath = '${RuntimeEnvir.usrPath}/var/lib/proot-distro';
String ubuntuPath = '$prootDistroPath/installed-rootfs/ubuntu';
String ubuntuName = Config.ubuntuFileName.replaceAll(RegExp('-pd.*'), '');

String common =
    '''
export TMPDIR=${RuntimeEnvir.tmpPath}
export BIN=${RuntimeEnvir.binPath}
export UBUNTU_PATH=$ubuntuPath
export UBUNTU=${Config.ubuntuFileName}
export UBUNTU_NAME=$ubuntuName
export L_NOT_INSTALLED=${S.current.uninstalled}
export L_INSTALLING=${S.current.installing}
export L_INSTALLED=${S.current.installed}
# proot 需要的环境变量
# Environment variables required by proot
export PROOT_LOADER=${RuntimeEnvir.binPath}/loader
export LD_LIBRARY_PATH=${RuntimeEnvir.binPath}
export PROOT_TMP_DIR=${RuntimeEnvir.tmpPath}
clear_lines(){
  printf "\\033[1A" # Move cursor up one line
  printf "\\033[K"  # Clear the line
  printf "\\033[1A" # Move cursor up one line
  printf "\\033[K"  # Clear the line
}
progress_echo(){
  echo -e "\\033[31m- \$@\\033[0m"
  echo "\$@" > "\$TMPDIR/progress_des"
}
bump_progress(){
  current=0
  if [ -f "\$TMPDIR/progress" ]; then
    current=\$(cat "\$TMPDIR/progress" 2>/dev/null || echo 0)
  fi
  next=\$((current + 1))
  printf "\$next" > "\$TMPDIR/progress"
}
''';

// 切换到清华源
// Switch to Tsinghua source
String changeUbuntuNobleSource = r'''
change_ubuntu_source(){
  cat <<EOF > "$UBUNTU_PATH/etc/apt/sources.list"
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
}
''';

String installUbuntu = r'''
install_ubuntu(){
  echo "==== install_ubuntu start ===="
  echo "[inspect] UBUNTU_PATH=$UBUNTU_PATH"
  echo "[inspect] UBUNTU archive=$HOME/$UBUNTU"
  echo "[inspect] UBUNTU_NAME=$UBUNTU_NAME"
  echo "[inspect] TMPDIR=${TMPDIR:-unknown}"

  echo "[before mkdir] ls -ld:"
  ls -ld "$UBUNTU_PATH" 2>/dev/null || echo "  -> dir missing"
  echo "[before mkdir] ls -A:"
  ls -A "$UBUNTU_PATH" 2>/dev/null || echo "  -> dir missing or empty"

  mkdir -p $UBUNTU_PATH 2>/dev/null

  echo "[after mkdir] ls -ld:"
  ls -ld "$UBUNTU_PATH" 2>/dev/null || echo "  -> dir still missing?!"
  echo "[after mkdir] ls -A:"
  ls -A "$UBUNTU_PATH" 2>/dev/null || echo "  -> dir empty"

  NEED_INSTALL=0
  if [ ! -d "$UBUNTU_PATH/bin" ]; then
    echo "[state] missing bin directory, force reinstall"
    NEED_INSTALL=1
  elif [ ! -f "$UBUNTU_PATH/usr/bin/env" ]; then
    echo "[state] missing /usr/bin/env, force reinstall"
    NEED_INSTALL=1
  elif [ ! -d "$UBUNTU_PATH/etc" ]; then
    echo "[state] missing etc directory, force reinstall"
    NEED_INSTALL=1
  fi

  if [ "$NEED_INSTALL" -eq 1 ] || [ -z "$(ls -A $UBUNTU_PATH 2>/dev/null)" ]; then
    echo "[state] $UBUNTU_PATH not ready, reinstalling"
    rm -rf "$UBUNTU_PATH"
    mkdir -p "$UBUNTU_PATH"
    if [[ "$UBUNTU" == *.tar.xz ]]; then
      TAR_ARGS="xJvf"
    elif [[ "$UBUNTU" == *.tar.gz ]]; then
      TAR_ARGS="xzvf"
    else
      TAR_ARGS="xvf"
    fi
    echo "[state] TAR_ARGS=$TAR_ARGS"
    progress_echo "Ubuntu $L_NOT_INSTALLED, $L_INSTALLING..."
    ls -l ~/$UBUNTU
    echo "[cmd] busybox tar $TAR_ARGS ~/$UBUNTU -C $UBUNTU_PATH/"
    if busybox tar $TAR_ARGS ~/$UBUNTU -C $UBUNTU_PATH/ | while read line; do
      # echo -ne "\033[2K\0337\r$line\0338"
      echo -ne "\033[2K\r$line"
    done; then
      echo
      echo "[result] tar success, moving $UBUNTU_NAME contents"
    else
      echo
      echo "[result] tar failed with exit code $?"
    fi
    if [ -d "$UBUNTU_PATH/$UBUNTU_NAME" ]; then
      mv "$UBUNTU_PATH/$UBUNTU_NAME/"* "$UBUNTU_PATH/"
      rm -rf "$UBUNTU_PATH/$UBUNTU_NAME"
    else
      echo "[warn] expected directory $UBUNTU_PATH/$UBUNTU_NAME not found after extraction"
    fi
    # 注释掉 code-server 相关的 PATH 设置
    # echo 'export PATH=/opt/code-server-$CSVERSION-linux-arm64/bin:$PATH' >> $UBUNTU_PATH/root/.bashrc
    echo 'export ANDROID_DATA=/home/' >> $UBUNTU_PATH/root/.bashrc
  else
    echo "[state] $UBUNTU_PATH not empty, skip extraction"
    VERSION=`cat $UBUNTU_PATH/etc/issue.net 2>/dev/null`
    # VERSION=`cat $UBUNTU_PATH/etc/issue 2>/dev/null | sed 's/\\n//g' | sed 's/\\l//g'`
    progress_echo "Ubuntu $L_INSTALLED -> $VERSION"
    ls -A "$UBUNTU_PATH"
  fi
  change_ubuntu_source
  echo 'nameserver 8.8.8.8' > $UBUNTU_PATH/etc/resolv.conf
  echo "==== install_ubuntu end ===="
}
''';

String loginUbuntu = r'''
login_ubuntu(){
  COMMAND_TO_EXEC="$1"
  if [ -z "$COMMAND_TO_EXEC" ]; then
    COMMAND_TO_EXEC="/bin/bash -il"
  fi
  # 使用 proot 直接进入解压的 Ubuntu 根文件系统。
  # - 清理并设置 PATH，避免继承宿主 PATH 造成命令找不到或混用 busybox。
  # - 绑定常见伪文件系统与外部存储，保障交互和软件包管理工作正常。
  # 在 proot 环境中创建 /storage/emulated 目录
  mkdir -p "$UBUNTU_PATH/storage/emulated" 2>/dev/null
  exec $BIN/proot \
    -0 \
    -r "$UBUNTU_PATH" \
    --link2symlink \
    -b /dev \
    -b /proc \
    -b /sys \
    -b /dev/pts \
    -b "$TMPDIR":"$TMPDIR" \
    -b "$TMPDIR":/dev/shm \
    -b /proc/self/fd:/dev/fd \
    -b /proc/self/fd/0:/dev/stdin \
    -b /proc/self/fd/1:/dev/stdout \
    -b /proc/self/fd/2:/dev/stderr \
    -b /storage/emulated/0:/sdcard \
    -b /storage/emulated/0:/storage/emulated/0 \
    -w /root \
    /usr/bin/env -i \
      HOME=/root \
      TERM=xterm-256color \
      LANG=en_US.UTF-8 \
      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      COMMAND_TO_EXEC="$COMMAND_TO_EXEC" \
      /bin/bash -lc "echo LOGIN_SUCCESSFUL; echo TERMINAL_READY; eval \"\$COMMAND_TO_EXEC\""
}
''';

String copyFiles = r'''
copy_files(){
  mkdir -p $UBUNTU_PATH/root
  cp ~/astrbot-startup.sh $UBUNTU_PATH/root/astrbot-startup.sh
  cp ~/cmd_config.json $UBUNTU_PATH/root/cmd_config.json
}
''';

String commonScript =
    '''
$common
$changeUbuntuNobleSource
$installUbuntu
$loginUbuntu
$copyFiles
clear_lines
start_astrbot(){
  bump_progress
  install_ubuntu
  sleep 1
  bump_progress

  copy_files
  login_ubuntu "export TMPDIR='${RuntimeEnvir.tmpPath}'; export L_NOT_INSTALLED='${S.current.uninstalled}'; export L_INSTALLING='${S.current.installing}'; export L_INSTALLED='${S.current.installed}'; chmod +x /root/astrbot-startup.sh; bash /root/astrbot-startup.sh"
}
''';
