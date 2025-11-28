import 'package:global_repository/global_repository.dart';
import '../config/app_config.dart';
import '../../generated/l10n.dart';

// ubuntu path (保持原有路径结构，但不再使用 proot-distro)
// ubuntu path (keep original path structure, but no longer use proot-distro)
String prootDistroPath = '${RuntimeEnvir.usrPath}/var/lib/proot-distro';
String ubuntuPath = '$prootDistroPath/installed-rootfs/ubuntu';
String ubuntuName = Config.ubuntuFileName.replaceAll(RegExp('-pd.*'), '');

String common =
    '''
export TMPDIR=${RuntimeEnvir.tmpPath}
export BIN=${RuntimeEnvir.binPath}
export HOME_PATH=${RuntimeEnvir.homePath}
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
    
    # 备份用户数据到Android持久化目录
    PERSISTENT_BACKUP="$HOME_PATH/ubuntu_user_backup"
    echo "[backup] 检查并备份用户数据..."
    
    # 备份整个 /root 目录（包含所有用户数据）
    if [ -d "$UBUNTU_PATH/root" ]; then
      echo "[backup] 备份 /root 目录..."
      mkdir -p "$PERSISTENT_BACKUP"
      cp -r "$UBUNTU_PATH/root" "$PERSISTENT_BACKUP/root_backup"
    fi

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
    
    # 恢复用户数据
    if [ -d "$PERSISTENT_BACKUP/root_backup" ]; then
      echo "[restore] 恢复用户数据..."
      mkdir -p "$UBUNTU_PATH/root"
      cp -r "$PERSISTENT_BACKUP/root_backup"/* "$UBUNTU_PATH/root/"
      rm -rf "$PERSISTENT_BACKUP"
    fi
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

String setupFakeSysdata = r'''
# A function for preparing fake content for certain system data interfaces
# which known to be restricted on Android OS.
#
# All /proc entries are based on values retrieved from Arch Linux (x86_64)
# running on a VM with 8 CPUs and 8 GiB of memory. Date 2023.03.28, Linux 6.2.1.
# Some values edited to fit the PRoot-Distro.
setup_fake_sysdata() {
	local d
	for d in proc sys sys/.empty; do
		if [ ! -e "$UBUNTU_PATH/${d}" ]; then
			mkdir -p "$UBUNTU_PATH/${d}"
		fi
		chmod 700 "$UBUNTU_PATH/${d}"
	done
	unset d

	if [ ! -f "$UBUNTU_PATH/proc/.loadavg" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.loadavg"
		0.12 0.07 0.02 2/165 765
		EOF
	fi

	if [ ! -f "$UBUNTU_PATH/proc/.stat" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.stat"
		cpu  1957 0 2877 93280 262 342 254 87 0 0
		cpu0 31 0 226 12027 82 10 4 9 0 0
		cpu1 45 0 664 11144 21 263 233 12 0 0
		cpu2 494 0 537 11283 27 10 3 8 0 0
		cpu3 359 0 234 11723 24 26 5 7 0 0
		cpu4 295 0 268 11772 10 12 2 12 0 0
		cpu5 270 0 251 11833 15 3 1 10 0 0
		cpu6 430 0 520 11386 30 8 1 12 0 0
		cpu7 30 0 172 12108 50 8 1 13 0 0
		intr 127541 38 290 0 0 0 0 4 0 1 0 0 25329 258 0 5777 277 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
		ctxt 140223
		btime 1680020856
		processes 772
		procs_running 2
		procs_blocked 0
		softirq 75663 0 5903 6 25375 10774 0 243 11685 0 21677
		EOF
	fi

	if [ ! -f "$UBUNTU_PATH/proc/.uptime" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.uptime"
		124.08 932.80
		EOF
	fi

	if [ ! -f "$UBUNTU_PATH/proc/.version" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.version"
		Linux version 6.2.1-proot-distro (proot@termux) (gcc (GCC) 13.3.0, GNU ld (GNU Binutils) 2.42) #1 SMP PREEMPT_DYNAMIC Wed Mar 29 00:00:00 UTC 2023
		EOF
	fi

	if [ ! -f "$UBUNTU_PATH/proc/.vmstat" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.vmstat"
		nr_free_pages 1743136
		nr_zone_inactive_anon 179281
		nr_zone_active_anon 7183
		nr_zone_inactive_file 22858
		nr_zone_active_file 51328
		nr_zone_unevictable 642
		nr_zone_write_pending 0
		nr_mlock 0
		nr_bounce 0
		nr_zspages 0
		nr_free_cma 0
		numa_hit 1259626
		numa_miss 0
		numa_foreign 0
		numa_interleave 720
		numa_local 1259626
		numa_other 0
		nr_inactive_anon 179281
		nr_active_anon 7183
		nr_inactive_file 22858
		nr_active_file 51328
		nr_unevictable 642
		nr_slab_reclaimable 8091
		nr_slab_unreclaimable 7804
		nr_isolated_anon 0
		nr_isolated_file 0
		workingset_nodes 0
		workingset_refault_anon 0
		workingset_refault_file 0
		workingset_activate_anon 0
		workingset_activate_file 0
		workingset_restore_anon 0
		workingset_restore_file 0
		workingset_nodereclaim 0
		nr_anon_pages 7723
		nr_mapped 8905
		nr_file_pages 253569
		nr_dirty 0
		nr_writeback 0
		nr_writeback_temp 0
		nr_shmem 178741
		nr_shmem_hugepages 0
		nr_shmem_pmdmapped 0
		nr_file_hugepages 0
		nr_file_pmdmapped 0
		nr_anon_transparent_hugepages 1
		nr_vmscan_write 0
		nr_vmscan_immediate_reclaim 0
		nr_dirtied 0
		nr_written 0
		nr_throttled_written 0
		nr_kernel_misc_reclaimable 0
		nr_foll_pin_acquired 0
		nr_foll_pin_released 0
		nr_kernel_stack 2780
		nr_page_table_pages 344
		nr_sec_page_table_pages 0
		nr_swapcached 0
		pgpromote_success 0
		pgpromote_candidate 0
		nr_dirty_threshold 356564
		nr_dirty_background_threshold 178064
		pgpgin 890508
		pgpgout 0
		pswpin 0
		pswpout 0
		pgalloc_dma 272
		pgalloc_dma32 261
		pgalloc_normal 1328079
		pgalloc_movable 0
		pgalloc_device 0
		allocstall_dma 0
		allocstall_dma32 0
		allocstall_normal 0
		allocstall_movable 0
		allocstall_device 0
		pgskip_dma 0
		pgskip_dma32 0
		pgskip_normal 0
		pgskip_movable 0
		pgskip_device 0
		pgfree 3077011
		pgactivate 0
		pgdeactivate 0
		pglazyfree 0
		pgfault 176973
		pgmajfault 488
		pglazyfreed 0
		pgrefill 0
		pgreuse 19230
		pgsteal_kswapd 0
		pgsteal_direct 0
		pgsteal_khugepaged 0
		pgdemote_kswapd 0
		pgdemote_direct 0
		pgdemote_khugepaged 0
		pgscan_kswapd 0
		pgscan_direct 0
		pgscan_khugepaged 0
		pgscan_direct_throttle 0
		pgscan_anon 0
		pgscan_file 0
		pgsteal_anon 0
		pgsteal_file 0
		zone_reclaim_failed 0
		pginodesteal 0
		slabs_scanned 0
		kswapd_inodesteal 0
		kswapd_low_wmark_hit_quickly 0
		kswapd_high_wmark_hit_quickly 0
		pageoutrun 0
		pgrotated 0
		drop_pagecache 0
		drop_slab 0
		oom_kill 0
		numa_pte_updates 0
		numa_huge_pte_updates 0
		numa_hint_faults 0
		numa_hint_faults_local 0
		numa_pages_migrated 0
		pgmigrate_success 0
		pgmigrate_fail 0
		thp_migration_success 0
		thp_migration_fail 0
		thp_migration_split 0
		compact_migrate_scanned 0
		compact_free_scanned 0
		compact_isolated 0
		compact_stall 0
		compact_fail 0
		compact_success 0
		compact_daemon_wake 0
		compact_daemon_migrate_scanned 0
		compact_daemon_free_scanned 0
		htlb_buddy_alloc_success 0
		htlb_buddy_alloc_fail 0
		cma_alloc_success 0
		cma_alloc_fail 0
		unevictable_pgs_culled 27002
		unevictable_pgs_scanned 0
		unevictable_pgs_rescued 744
		unevictable_pgs_mlocked 744
		unevictable_pgs_munlocked 744
		unevictable_pgs_cleared 0
		unevictable_pgs_stranded 0
		thp_fault_alloc 13
		thp_fault_fallback 0
		thp_fault_fallback_charge 0
		thp_collapse_alloc 4
		thp_collapse_alloc_failed 0
		thp_file_alloc 0
		thp_file_fallback 0
		thp_file_fallback_charge 0
		thp_file_mapped 0
		thp_split_page 0
		thp_split_page_failed 0
		thp_deferred_split_page 1
		thp_split_pmd 1
		thp_scan_exceed_none_pte 0
		thp_scan_exceed_swap_pte 0
		thp_scan_exceed_share_pte 0
		thp_split_pud 0
		thp_zero_page_alloc 0
		thp_zero_page_alloc_failed 0
		thp_swpout 0
		thp_swpout_fallback 0
		balloon_inflate 0
		balloon_deflate 0
		balloon_migrate 0
		swap_ra 0
		swap_ra_hit 0
		ksm_swpin_copy 0
		cow_ksm 0
		zswpin 0
		zswpout 0
		direct_map_level2_splits 29
		direct_map_level3_splits 0
		nr_unstable 0
		EOF
	fi

	if [ ! -f "$UBUNTU_PATH/proc/.sysctl_entry_cap_last_cap" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.sysctl_entry_cap_last_cap"
		40
		EOF
	fi

	if [ ! -f "$UBUNTU_PATH/proc/.sysctl_inotify_max_user_watches" ]; then
		cat <<- EOF > "$UBUNTU_PATH/proc/.sysctl_inotify_max_user_watches"
		4096
		EOF
	fi
}
''';

String loginUbuntu = r'''
login_ubuntu(){
  COMMAND_TO_EXEC="$1"
  if [ -z "$COMMAND_TO_EXEC" ]; then
    COMMAND_TO_EXEC="/bin/bash -il"
  fi
  
  # Setup fake sysdata to fix Android system information retrieval errors
  setup_fake_sysdata
  
  # 构建动态的 bind mount 参数，只在文件不存在时挂载假文件
  BIND_ARGS=""
  
  # 检查并添加假 proc 文件挂载（只在真实文件不可访问时）
  if [ ! -r /proc/loadavg ] || [ ! -s /proc/loadavg ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.loadavg:/proc/loadavg"
  fi
  
  if [ ! -r /proc/stat ] || [ ! -s /proc/stat ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.stat:/proc/stat"
  fi
  
  if [ ! -r /proc/uptime ] || [ ! -s /proc/uptime ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.uptime:/proc/uptime"
  fi
  
  if [ ! -r /proc/version ] || [ ! -s /proc/version ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.version:/proc/version"
  fi
  
  if [ ! -r /proc/vmstat ] || [ ! -s /proc/vmstat ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.vmstat:/proc/vmstat"
  fi
  
  if [ ! -r /proc/sys/kernel/cap_last_cap ] || [ ! -s /proc/sys/kernel/cap_last_cap ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.sysctl_entry_cap_last_cap:/proc/sys/kernel/cap_last_cap"
  fi
  
  if [ ! -r /proc/sys/fs/inotify/max_user_watches ] || [ ! -s /proc/sys/fs/inotify/max_user_watches ]; then
    BIND_ARGS="$BIND_ARGS -b $UBUNTU_PATH/proc/.sysctl_inotify_max_user_watches:/proc/sys/fs/inotify/max_user_watches"
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
    $BIND_ARGS \
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
$setupFakeSysdata
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
