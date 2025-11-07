#!/bin/bash

# 颜色变量
MAGENTA='\033[0;1;35;95m'
RED='\033[0;1;31;91m'
YELLOW='\033[0;1;33;93m'
GREEN='\033[0;1;32;92m'
CYAN='\033[0;1;36;96m'
BLUE='\033[0;1;34;94m'
NC='\033[0m'

function log() {
    time=$(date +"%Y-%m-%d %H:%M:%S")
    message="[${time}]: $1 "
    case "$1" in
    *"失败"* | *"错误"* | *"sudo不存在"* | *"当前用户不是root用户"* | *"无法连接"*)
        echo -e "${RED}${message}${NC}"
        ;;
    *"成功"*)
        echo -e "${GREEN}${message}${NC}"
        ;;
    *"忽略"* | *"跳过"* | *"默认"* | *"警告"*)
        echo -e "${YELLOW}${message}${NC}"
        ;;
    *)
        echo -e "${BLUE}${message}${NC}"
        ;;
    esac
}

function check_sudo() {
    if ! command -v sudo &> /dev/null; then
        log "sudo不存在, 请手动安装: \n Centos: dnf install -y sudo\n Debian/Ubuntu: apt-get install -y sudo\n"
        exit 1
    fi
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "错误: 此脚本需要以 root 权限运行。"
        log "请尝试使用 'sudo bash ${0}' 或切换到 root 用户后运行。"
        exit 1
    fi
    log "脚本正在以 root 权限运行。"
}

function detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        package_manager="apt-get"
    elif command -v dnf &> /dev/null; then
        package_manager="dnf"
    else
        log "高级包管理器检查失败, 目前仅支持apt-get/dnf。"
        exit 1
    fi
    log "当前高级包管理器: ${package_manager}"
}

function detect_package_installer() {
    if command -v dpkg &> /dev/null; then
        package_installer="dpkg"
    elif command -v rpm &> /dev/null; then
        package_installer="rpm"
    else
        log "基础包管理器检查失败, 目前仅支持dpkg/rpm。"
        exit 1
    fi
    log "当前基础包管理器: ${package_installer}"
}

function install_dependency() {
    log "开始更新依赖..."
    detect_package_manager

    if [ "${package_manager}" = "apt-get" ]; then
        sudo apt-get update -y -qq
        sudo apt-get install -y -qq zip unzip jq curl xvfb screen xauth procps g++
    elif [ "${package_manager}" = "dnf" ]; then
        sudo dnf install -y epel-release
        sudo dnf install --allowerasing -y zip unzip jq curl xorg-x11-server-Xvfb screen procps-ng gcc-c++
    fi
    log "依赖安装成功..."
}

function network_test() {
    local timeout=10
    local status=0
    local found=0
    target_proxy=""
    log "开始网络测试: Github..."

    proxy_arr=("https://ghfast.top" "https://gh.wuliya.xin" "https://gh-proxy.com" "https://github.moeyy.xyz")
    check_url="https://raw.githubusercontent.com/NapNeko/NapCatQQ/main/package.json"

    for proxy in "${proxy_arr[@]}"; do
        log "测试代理: ${proxy}"
        status=$(curl -k -L --connect-timeout ${timeout} --max-time $((timeout*2)) -o /dev/null -s -w "%{http_code}" "${proxy}/${check_url}")
        curl_exit=$?
        if [ $curl_exit -ne 0 ]; then
            log "代理 ${proxy} 测试失败或超时 (错误码: $curl_exit)"
            continue
        fi
        if [ "${status}" = "200" ]; then
            found=1
            target_proxy="${proxy}"
            log "将使用Github代理: ${proxy}"
            break
        fi
    done

    if [ ${found} -eq 0 ]; then
        log "警告: 无法找到可用的Github代理，将尝试直连..."
        status=$(curl -k --connect-timeout ${timeout} --max-time $((timeout*2)) -o /dev/null -s -w "%{http_code}" "${check_url}")
        if [ $? -eq 0 ] && [ "${status}" = "200" ]; then
            log "直连Github成功，将不使用代理"
            target_proxy=""
        else
            log "警告: 无法连接到Github，请检查网络。将继续尝试安装，但可能会失败。"
        fi
    fi
}

function create_tmp_folder() {
    if [ -d "./napcat" ] && [ "$(ls -A ./napcat)" ]; then
        log "文件夹已存在且不为空(./napcat)，请重命名后重新执行脚本以防误删"
        exit 1
    fi
    sudo mkdir -p ./napcat
}

function clean() {
    # 不再清理 ./napcat 文件夹
    sudo rm -rf ./NapCat.Shell.zip
}

function download_napcat() {
    create_tmp_folder
    default_file="NapCat.Shell.zip"
    if [ -f "${default_file}" ]; then
        log "检测到已下载NapCat安装包,跳过下载..."
    else
        log "开始下载NapCat安装包,请稍等..."
        network_test
        napcat_download_url="${target_proxy:+${target_proxy}/}https://github.com/NapNeko/NapCatQQ/releases/latest/download/NapCat.Shell.zip"
        curl -k -L -# "${napcat_download_url}" -o "${default_file}"
        if [ $? -ne 0 ]; then
            log "文件下载失败, 请检查错误。或者手动下载压缩包并放在脚本同目录下"
            clean
            exit 1
        fi
        log "${default_file} 成功下载。"
    fi

    log "正在验证 ${default_file}..."
    sudo unzip -t "${default_file}" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log "文件验证失败, 请检查错误。"
        clean
        exit 1
    fi

    log "正在解压 ${default_file}..."
    sudo unzip -q -o -d ./napcat NapCat.Shell.zip
    if [ $? -ne 0 ]; then
        log "文件解压失败, 请检查错误。"
        clean
        exit 1
    fi
}

function get_system_arch() {
    system_arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/)
    if [ "${system_arch}" = "none" ]; then
        log "无法识别的系统架构, 请检查错误。"
        exit 1
    fi
    log "当前系统架构: ${system_arch}"
}

function install_linuxqq() {
    get_system_arch
    detect_package_installer
    log "安装LinuxQQ..."
    if [ "${system_arch}" = "amd64" ]; then
        if [ "${package_installer}" = "rpm" ]; then
            qq_download_url="https://dldir1.qq.com/qqfile/qq/QQNT/ec800879/linuxqq_3.2.20-40990_x86_64.rpm"
        elif [ "${package_installer}" = "dpkg" ]; then
            qq_download_url="https://dldir1.qq.com/qqfile/qq/QQNT/ec800879/linuxqq_3.2.20-40990_amd64.deb"
        fi
    elif [ "${system_arch}" = "arm64" ]; then
        if [ "${package_installer}" = "rpm" ]; then
            qq_download_url="https://dldir1.qq.com/qqfile/qq/QQNT/ec800879/linuxqq_3.2.20-40990_aarch64.rpm"
        elif [ "${package_installer}" = "dpkg" ]; then
            qq_download_url="https://dldir1.qq.com/qqfile/qq/QQNT/ec800879/linuxqq_3.2.20-40990_arm64.deb"
        fi
    fi

    if [ "${package_manager}" = "dnf" ]; then
        if ! [ -f "QQ.rpm" ]; then
            sudo curl -k -L -# "${qq_download_url}" -o QQ.rpm
            if [ $? -ne 0 ]; then
                log "QQ下载失败"
                exit 1
            fi
        fi
        sudo dnf localinstall -y ./QQ.rpm
        sudo rm -f QQ.rpm
    elif [ "${package_manager}" = "apt-get" ]; then
        if ! [ -f "QQ.deb" ]; then
            sudo curl -k -L -# "${qq_download_url}" -o QQ.deb
            if [ $? -ne 0 ]; then
                log "QQ下载失败"
                exit 1
            fi
        fi
        sudo apt-get install -f -y --allow-downgrades -qq ./QQ.deb
        sudo apt-get install -y --allow-downgrades -qq libnss3
        sudo apt-get install -y --allow-downgrades -qq libgbm1
        sudo apt-get install -y --allow-downgrades -qq libasound2 || sudo apt-get install -y --allow-downgrades -qq libasound2t64
        sudo rm -f QQ.deb
    fi
    log "LinuxQQ安装完成"
}

function download_launcher_so() {
    get_system_arch
    network_test

    # 只支持 amd64/arm64 架构
    if [ "${system_arch}" != "amd64" ] && [ "${system_arch}" != "arm64" ]; then
        log "不支持的架构: ${system_arch}"
        exit 1
    fi

    cpp_url="https://raw.githubusercontent.com/NapNeko/napcat-linux-launcher/refs/heads/main/launcher.cpp"
    cpp_file="launcher.cpp"
    so_file="libnapcat_launcher.so"

    if [ -n "${target_proxy}" ]; then
        cpp_url_path="${cpp_url#https://}"
        download_url="${target_proxy}/${cpp_url_path}"
    else
        download_url="${cpp_url}"
    fi

    log "开始下载 ${cpp_file} ..."
    curl -k -L -# "${download_url}" -o "${cpp_file}"
    if [ $? -ne 0 ]; then
        log "${cpp_file} 下载失败，请检查网络或手动下载。"
        exit 1
    fi
    log "${cpp_file} 下载成功。"

    log "正在编译 ${so_file} ..."
    g++ -shared -fPIC "${cpp_file}" -o "${so_file}" -ldl
    if [ $? -ne 0 ]; then
        log "${so_file} 编译失败，请检查g++是否安装或源码是否有误。"
        exit 1
    fi
    log "${so_file} 编译成功。"
}

clear
log "NapCat Shell 安装脚本"
check_sudo
check_root
install_dependency
download_napcat
install_linuxqq
download_launcher_so
clean

# 写入启动步骤到 launcher.sh
cat << 'EOF' > launcher.sh
#!/bin/bash
Xvfb :1 -screen 0 1x1x8 +extension GLX +render > /dev/null 2>&1 &
export DISPLAY=:1
LD_PRELOAD=./libnapcat_launcher.so qq --no-sandbox
EOF

chmod +x launcher.sh

log "启动步骤:"
log "输入 Xvfb :1 -screen 0 1x1x8 +extension GLX +render > /dev/null 2>&1 &"
log "输入 export DISPLAY=:1"
log "输入 sudo su"
log "输入 LD_PRELOAD=./libnapcat_launcher.so qq --no-sandbox"
log "或直接运行 sudo bash ./launcher.sh 启动 NapCat Shell"
