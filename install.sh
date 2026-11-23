#!/bin/zsh
# One-command source install: bundled Remote Buddy Mic driver + build the app + move to /Applications.
# 一键源码安装：捆绑的 Remote Buddy Mic 虚拟声卡 + 编译 App + 装入“应用程序”。
# 普通用户推荐直接下载 Releases 里的 .pkg 一体安装包，无需编译工具。
set -e
cd "$(dirname "$0")"

echo "== 1/3 检查编译工具 =="
if ! command -v swiftc >/dev/null 2>&1; then
  echo "缺少 Xcode 命令行工具，正在触发安装（弹窗里点“安装”后重跑本脚本）…"
  xcode-select --install || true
  exit 1
fi

echo "== 2/3 安装 Remote Buddy Mic 虚拟声卡（需要管理员密码）=="
HAL="/Library/Audio/Plug-Ins/HAL"
if [ -d "$HAL/RemoteBuddyMic.driver" ]; then
  echo "Remote Buddy Mic 已安装，跳过。"
else
  sudo mkdir -p "$HAL"
  sudo cp -R "Packaging/Vendor/RemoteBuddyMic.driver" "$HAL/RemoteBuddyMic.driver"
  echo "重启 CoreAudio 加载驱动（系统声音会中断几秒后自动恢复）…"
  sudo killall coreaudiod 2>/dev/null || true
fi

echo "== 3/3 编译并安装 App =="
./build.sh
DEST="/Applications/Google Remote Voice.app"
if pgrep -f '^/Applications/Google Remote Voice.app/Contents/MacOS/GoogleRemoteVoice($| )' >/dev/null; then
  echo "请先退出 Google Remote Voice，等待按键接收器恢复日志设置，再重跑安装。"
  exit 1
fi
if [ -d "$DEST" ]; then
  mv "$DEST" "build/installed-backup-$(date +%Y%m%d-%H%M%S).app"
fi
cp -R "build/Google Remote Voice.app" "$DEST"
xattr -cr "$DEST" 2>/dev/null || true

cat <<'EOF'

✅ 完成！

接下来：
  1. 在系统蓝牙里，把 Chromecast 语音遥控器和这台 Mac 配对连接。
  2. 打开“应用程序 → Google Remote Voice”（首次右键→打开）。
  3. 点菜单栏图标 → 设置，按提示授权：蓝牙 / 辅助功能 / 输入监控。
  4. 14 键需要 Apple PacketLogger：从 Apple 官方 Additional Tools 下载后放入“应用程序”。
  5. 要让某个 App 用遥控器麦克风：把它的输入设备选成 “Remote Buddy Mic”。
EOF