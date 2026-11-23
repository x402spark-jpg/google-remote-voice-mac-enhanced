# 捆绑驱动对应源码与重建说明

本目录提供一体包所捆绑 `RemoteBuddyMic.driver` 的**完整对应源码**（GPL-3.0-only），使本仓库自包含、无 GPL 合规歧义。

## 内容

- `blackhole-src/` — **BlackHole v0.7.2** 上游源码快照，修订 `561d934c77a1fa64987e01ccabe890fed30e181f`（https://github.com/ExistentialAudio/BlackHole ）。含 `BlackHole.xcodeproj`、`LICENSE`（GPL-3.0）。
- `device-usb.patch` — 来自 https://github.com/zfdang/remote-buddy 的 `third_party/blackhole/device-usb.patch`。核心改动：设备级 `kAudioDevicePropertyTransportType` 由 `kAudioDeviceTransportTypeVirtual` 改为 `kAudioDeviceTransportTypeUSB`（使豆包等只枚举 USB transport 麦克风的输入法能识别该回环设备），并含名称格式预处理调整。
- `RemoteBuddyMic.driver/` — 上述源码经补丁与品牌/标识配置编译出的对象代码（即安装包捆绑的驱动）。
- `NOTICE.txt` — GPL v3 第 5(a) 条修改声明。

## 重建步骤（需完整 Xcode）

```sh
cd blackhole-src
git apply ../device-usb.patch        # 或 patch -p1 < ../device-usb.patch
# 用 Xcode 打开 BlackHole.xcodeproj，按上游 remote-buddy 的配置设置：
#   Bundle ID = com.zfdang.remote-buddy.mic
#   固定 UID  = BuddyMic2ch_UID
#   产品名    = Remote Buddy Mic（2ch）
xcodebuild -project BlackHole.xcodeproj -configuration Release
```

产物即 `RemoteBuddyMic.driver`。品牌/标识的精确配置参考上游 https://github.com/zfdang/remote-buddy 的驱动构建脚本。本仓库构建机若仅有 Command Line Tools（无完整 Xcode）则无法编译驱动，故一体包直接捆绑已验证的对象代码。

## 许可

GPL-3.0-only。完整许可证见 `blackhole-src/LICENSE` 与仓库 `LICENSES/BlackHole-GPL-3.0.txt`。BlackHole 官方编译二进制版权归 Existential Audio Inc.；此处为 GPL 源码派生构建。