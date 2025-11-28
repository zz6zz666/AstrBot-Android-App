#!/bin/bash

export UV_LINK_MODE=copy
export UV_DEFAULT_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"
export UV_PYTHON_INSTALL_MIRROR="https://ghfast.top/https://github.com/astral-sh/python-build-standalone/releases/download"

if [ -z "$TMPDIR" ]; then
  echo "错误：未检测到 TMPDIR，请在挂载共享目录时传入 TMPDIR"
  exit 1
fi

if [ ! -d "$TMPDIR" ]; then
  echo "错误：临时目录 $TMPDIR 不存在，请确认挂载已经完成"
  exit 1
fi


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
    apt --fix-broken install -y
    apt-get install -y sudo
    sudo apt-get install -y git
    sudo apt-get install -y curl
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
    TMP_DIR=$(mktemp -d 2>/dev/null || mktemp -t 'uvtmp.XXXXXX')
    if [ -z "$TMP_DIR" ]; then
      echo "创建临时目录失败"
      exit 1
    fi
    mkdir -p "$TMP_DIR"
    TMP_ARCHIVE="$TMP_DIR/$ARCHIVE_FILE"

    # 下载并解压（失败直接退出，不使用return）
    echo "正在下载 $APP_NAME $APP_VERSION..."
    if ! curl -fL $DOWNLOAD_URL -o $TMP_ARCHIVE; then
      echo "下载失败"
      rm -rf $TMP_DIR
      exit 1
    fi
    echo "正在解压 $APP_NAME..."
    if ! tar -C "$TMP_DIR" -xf "$TMP_ARCHIVE" --strip-components 1; then
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
    
    apt --fix-broken install -y

    # 备份数据目录（如果存在）
    if [ -d "$HOME/napcat/data" ]; then
      echo "备份 NapCat 数据目录..."
      cp -r "$HOME/napcat/data" "$HOME/napcat_data_backup"
    fi
    
    # 备份缓存目录（如果存在）
    if [ -d "$HOME/napcat/cache" ]; then
      echo "备份 NapCat 缓存目录..."
      cp -r "$HOME/napcat/cache" "$HOME/napcat_cache_backup"
    fi
    
    rm -rf $HOME/napcat
    cd $HOME
    echo "Napcat $L_NOT_INSTALLED，$L_INSTALLING..."
    curl -o napcat.sh https://raw.githubusercontent.com/NapNeko/napcat-linux-installer/refs/heads/main/install.sh
    if ! chmod +x napcat.sh; then
      echo "设置 napcat.sh 执行权限失败"
      exit 1
    fi
    bash napcat.sh
    
    # 恢复数据目录
    if [ -d "$HOME/napcat_data_backup" ]; then
      echo "恢复 NapCat 数据目录..."
      mkdir -p "$HOME/napcat/data"
      cp -r "$HOME/napcat_data_backup"/* "$HOME/napcat/data/"
      rm -rf "$HOME/napcat_data_backup"
    fi
    
    # 恢复缓存目录
    if [ -d "$HOME/napcat_cache_backup" ]; then
      echo "恢复 NapCat 缓存目录..."
      mkdir -p "$HOME/napcat/cache"
      cp -r "$HOME/napcat_cache_backup"/* "$HOME/napcat/cache/"
      rm -rf "$HOME/napcat_cache_backup"
    fi
    
  # 只在配置文件不存在时写入默认配置
  if [ ! -f "$HOME/napcat/config/onebot11.json" ]; then
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
  fi
    progress_echo "Napcat $L_INSTALLED"
  else
    progress_echo "Napcat $L_INSTALLED"
  fi

}

install_astrbot(){
  local INSTALL_DIR="$HOME/AstrBot"
  local CLONE_TEMP_DIR="$HOME/AstrBot_tmp"
  local BACKUP_DIR="/sdcard/Download/AstrBot"
  
  rm -rf "$CLONE_TEMP_DIR"

  # 检查是否已安装
  if [ ! -d "$INSTALL_DIR" ]; then
    cd $HOME
    progress_echo "AstrBot $L_NOT_INSTALLED，$L_INSTALLING..."
    network_test

    # 克隆仓库（失败直接退出）
    echo "正在获取 AstrBot 最新版本..."

    # 获取最新的 tag
    LATEST_TAG=$(git ls-remote --tags --sort='-v:refname' ${target_proxy:+${target_proxy}/}https://github.com/AstrBotDevs/AstrBot.git | head -n 1 | awk -F'/' '{print $3}')
    
    if [ -z "$LATEST_TAG" ]; then
      echo "警告: 无法获取最新 tag，使用 main 分支"
      CLONE_BRANCH="main"
    else
      echo "最新版本: $LATEST_TAG"
      CLONE_BRANCH="$LATEST_TAG"
    fi
    
    # 克隆到临时目录
    echo "正在克隆 AstrBot 仓库 (分支/标签: $CLONE_BRANCH)..."
    if ! git clone --depth=1 --branch "$CLONE_BRANCH" ${target_proxy:+${target_proxy}/}https://github.com/AstrBotDevs/AstrBot.git "$CLONE_TEMP_DIR"; then
      echo "克隆 AstrBot 仓库失败"
      rm -rf "$CLONE_TEMP_DIR"  # 清理失败的临时目录
      exit 1
    fi
    
    mkdir "$CLONE_TEMP_DIR/data"
    
    # 检查并恢复最新备份
    if [ -d "$BACKUP_DIR" ]; then
      echo "扫描备份目录: $BACKUP_DIR"
      LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/AstrBot-backup-*.tar.gz 2>/dev/null | head -n 1)
      
      if [ -n "$LATEST_BACKUP" ]; then
        echo "找到备份文件: $LATEST_BACKUP"
        progress_echo "恢复 AstrBot 数据备份..."
        
        # 解压备份到 data 目录
        if tar -xzf "$LATEST_BACKUP" -C "$CLONE_TEMP_DIR"; then
          echo "备份恢复成功"
          progress_echo "AstrBot 数据已从备份恢复"
          
          # 扫描所有插件的 requirements.txt 并安装到 venv
          echo "扫描插件依赖..."
          if [ -d "$CLONE_TEMP_DIR/data/plugins" ]; then
            for plugin_dir in "$CLONE_TEMP_DIR/data/plugins"/*; do
              if [ -d "$plugin_dir" ] && [ -f "$plugin_dir/requirements.txt" ]; then
                echo "发现插件依赖: $plugin_dir/requirements.txt"
                if [ -f "$HOME/.local/bin/uv" ]; then
                  cd "$CLONE_TEMP_DIR"
                  echo "安装插件依赖: $(basename "$plugin_dir")..."
                  $HOME/.local/bin/uv pip install -r "$plugin_dir/requirements.txt" 2>/dev/null || echo "警告: 插件依赖安装失败，将在启动时重试"
                fi
              fi
            done
          fi
        else
          echo "备份恢复失败，使用默认配置"
          cp cmd_config.json "$CLONE_TEMP_DIR/data"
          chmod +w "$CLONE_TEMP_DIR/data/cmd_config.json"
        fi
      else
        echo "未找到备份文件，使用默认配置"
        cp cmd_config.json "$CLONE_TEMP_DIR/data"
        chmod +w "$CLONE_TEMP_DIR/data/cmd_config.json"
        echo "拷贝 cmd_config.json 默认配置文件"
      fi
    else
      echo "备份目录不存在，使用默认配置"
      cp cmd_config.json "$CLONE_TEMP_DIR/data"
      chmod +w "$CLONE_TEMP_DIR/data/cmd_config.json"
      echo "拷贝 cmd_config.json 默认配置文件"
    fi

    # 原子性重命名
    mv "$CLONE_TEMP_DIR" "$INSTALL_DIR"
    
  else
    progress_echo "AstrBot $L_INSTALLED"
  fi
  
  # 启动 AstrBot（失败直接退出）
  progress_echo "AstrBot 配置中"
  cd $INSTALL_DIR
  if [ ! -f "$HOME/.local/bin/uv" ]; then
    echo "uv 未找到"
    exit 1
  fi
  
  # 使用 uv sync 同步依赖
  echo "同步 AstrBot 依赖..."
  if ! $HOME/.local/bin/uv sync; then
    echo "依赖同步失败"
    exit 1
  fi
  
  # 首次启动使用 uv run main.py（会自动同步依赖）
  # 非首次启动使用 uv run --no-sync main.py（跳过依赖同步）
  if [ ! -f "$INSTALL_DIR/.uv_synced" ]; then
    echo "首次启动 AstrBot..."
    if ! $HOME/.local/bin/uv run main.py; then
      echo "AstrBot 启动失败"
      exit 1
    fi
    # 标记已同步
    touch "$INSTALL_DIR/.uv_synced"
  else
    echo "非首次启动 AstrBot，跳过依赖同步..."
    if ! $HOME/.local/bin/uv run --no-sync main.py; then
      echo "AstrBot 启动失败"
      exit 1
    fi
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
