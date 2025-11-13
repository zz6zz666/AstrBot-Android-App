#!/bin/bash

export UV_LINK_MODE=copy
export UV_DEFAULT_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"
export UV_PYTHON_INSTALL_MIRROR="https://ghfast.top/https://github.com/astral-sh/python-build-standalone/releases/download"

progress_echo(){
  echo -e "\033[31m- $@\033[0m"
  echo "$@" > "$TMPDIR/progress_des"
}

bump_progress(){
  current=0
  if [ -f "$TMPDIR/progress" ]; then
    current=$(cat "$TMPDIR/progress" 2>/dev/null || echo 0)
  fi
  next=$((current + 1))
  printf "$next" > "$TMPDIR/progress"
}

install_sudo_curl_git(){
  curl_path=`which curl`
  if [ -z "$curl_path" ]; then
    progress_echo "curl $L_NOT_INSTALLED, $L_INSTALLING..."
    apt-get update
    apt-get install -y sudo
    sudo apt-get install -y curl git
  else
    progress_echo "curl $L_INSTALLED"
  fi
}

function network_test() {
    local timeout=10
    local status=0
    local found=0
    target_proxy=""
    echo "开始网络测试: Github..."

    proxy_arr=("https://ghfast.top" "https://gh.wuliya.xin" "https://gh-proxy.com" "https://github.moeyy.xyz")
    check_url="https://raw.githubusercontent.com/NapNeko/NapCatQQ/main/package.json"

    for proxy in "${proxy_arr[@]}"; do
        echo "测试代理: ${proxy}"
        status=$(curl -k -L --connect-timeout ${timeout} --max-time $((timeout*2)) -o /dev/null -s -w "%{http_code}" "${proxy}/${check_url}")
        curl_exit=$?
        if [ $curl_exit -ne 0 ]; then
            echo "代理 ${proxy} 测试失败或超时 (错误码: $curl_exit)"
            continue
        fi
        if [ "${status}" = "200" ]; then
            found=1
            target_proxy="${proxy}"
            echo "将使用Github代理: ${proxy}"
            break
        fi
    done

    if [ ${found} -eq 0 ]; then
        echo "警告: 无法找到可用的Github代理，将尝试直连..."
        status=$(curl -k --connect-timeout ${timeout} --max-time $((timeout*2)) -o /dev/null -s -w "%{http_code}" "${check_url}")
        if [ $? -eq 0 ] && [ "${status}" = "200" ]; then
            echo "直连Github成功，将不使用代理"
            target_proxy=""
        else
            echo "警告: 无法连接到Github，请检查网络。将继续尝试安装，但可能会失败。"
        fi
    fi
}

install_uv(){
  INSTALL_DIR="$HOME/.local/bin"
  if [ ! -x "$INSTALL_DIR/uv" ]; then
    progress_echo "uv $L_NOT_INSTALLED，$L_INSTALLING..."
    network_test
    APP_NAME="uv"
    APP_VERSION="0.9.9"
    ARCHIVE_FILE="uv-aarch64-unknown-linux-gnu.tar.gz"
    DOWNLOAD_URL="${target_proxy:+${target_proxy}/}https://github.com/astral-sh/uv/releases/download/${APP_VERSION}/${ARCHIVE_FILE}"

    # 检查必要命令
    for cmd in tar mkdir cp chmod mktemp rm curl; do
      if ! command -v $cmd >/dev/null 2>&1; then
        echo "错误：缺少必要命令 $cmd，无法安装 $APP_NAME"
        exit 1
      fi
    done

    # 创建安装目录和临时目录
    mkdir -p $INSTALL_DIR
    TMP_DIR=$(mktemp -d)
    TMP_ARCHIVE="$TMP_DIR/$ARCHIVE_FILE"

    # 下载并解压（失败直接退出，不使用return）
    echo "正在下载 $APP_NAME $APP_VERSION..."
    if ! curl -fL $DOWNLOAD_URL -o $TMP_ARCHIVE; then
      echo "下载失败"
      rm -rf $TMP_DIR
      exit 1
    fi
    echo "正在解压 $APP_NAME..."
    if ! tar xf $TMP_ARCHIVE --strip-components 1 -C $TMP_DIR; then
      echo "解压失败"
      rm -rf $TMP_DIR
      exit 1
    fi

    # 安装并授权
    cp $TMP_DIR/uv $TMP_DIR/uvx $INSTALL_DIR/
    chmod +x $INSTALL_DIR/uv $INSTALL_DIR/uvx

    # 自动配置 PATH（写入 Ubuntu root 的 bashrc）
    if ! grep -q "$INSTALL_DIR" $HOME/.bashrc; then
      echo "export PATH=$INSTALL_DIR:\$PATH" >> $HOME/.bashrc
      source $HOME/.bashrc
      echo "已自动配置 $APP_NAME 路径到环境变量"
    fi

    # 清理临时文件
    rm -rf $TMP_DIR
  else
    progress_echo "uv $L_INSTALLED"
  fi
}

install_napcat(){
  # 检查是否已安装
  if [ ! -f "$HOME/launcher.sh" ]; then
    progress_echo "Napcat $L_NOT_INSTALLED，$L_INSTALLING..."
    rm -rf $HOME/napcat
    cd $HOME
    echo "Napcat $L_NOT_INSTALLED，$L_INSTALLING..."
    curl -o napcat.sh https://raw.githubusercontent.com/NapNeko/napcat-linux-installer/refs/heads/main/install.sh
    if ! chmod +x napcat.sh; then
      echo "设置 napcat.sh 执行权限失败"
      exit 1
    fi
    bash napcat.sh
    
  echo "写入 onebot11.json 默认配置文件"
  cat > "$HOME/napcat/config/onebot11.json" <<'EOF'
{
  "network": {
    "httpServers": [],
    "httpClients": [],
    "websocketServers": [],
    "websocketClients": [
      {
        "name": "WsClient",
        "enable": true,
        "url": "ws://localhost:6199/ws",
        "messagePostFormat": "array",
        "reportSelfMessage": false,
        "reconnectInterval": 5000,
        "token": "kasdkfljsadhlskdjhasdlkfshdlafksjdhf",
        "debug": false,
        "heartInterval": 30000
      }
    ]
  },
  "musicSignUrl": "",
  "enableLocalFile2Url": false,
  "parseMultMsg": false
}
EOF
    progress_echo "Napcat $L_INSTALLED"
  else
    progress_echo "Napcat $L_INSTALLED"
  fi

}

install_astrbot(){
  local INSTALL_DIR="$HOME/AstrBot"
  
  # 检查是否已安装
  if [ ! -d "$INSTALL_DIR" ]; then
    cd $HOME
    progress_echo "AstrBot $L_NOT_INSTALLED，$L_INSTALLING..."
    network_test

    # 克隆仓库（失败直接退出）
    echo "正在克隆 AstrBot 仓库..."
    if ! git clone ${target_proxy:+${target_proxy}/}https://github.com/AstrBotDevs/AstrBot.git $INSTALL_DIR; then
      echo "克隆 AstrBot 仓库失败"
      exit 1
    fi
    mkdir AstrBot/data
    cp cmd_config.json AstrBot/data
    echo "拷贝 cmd_config.json 默认配置文件"
  else
    progress_echo "AstrBot $L_INSTALLED"
  fi
  
  # 启动 AstrBot（失败直接退出）
  progress_echo "AstrBot 配置中"
  cd $INSTALL_DIR
  if ! $HOME/.local/bin/uv sync; then
    echo "uv 依赖同步失败"
    exit 1
  fi
  if ! $HOME/.local/bin/uv run main.py; then
    echo "AstrBot 启动失败"
    exit 1
  fi
}

install_sudo_curl_git
bump_progress
bump_progress
install_uv
bump_progress
install_napcat
bump_progress
bump_progress
bump_progress
install_astrbot
