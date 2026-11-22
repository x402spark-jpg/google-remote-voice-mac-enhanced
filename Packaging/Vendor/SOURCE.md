# 捆绑驱动对应源码（GPL-3.0-only）

一体安装包捆绑的 `RemoteBuddyMic.driver` 是 GPL-3.0-only 自由软件，依据 GNU GPL v3 第 6 条随对象代码提供对应源码（Corresponding Source）信息。

## 对象代码

- 文件：`RemoteBuddyMic.driver`（HAL 音频驱动，Bundle ID `com.zfdang.remote-buddy.mic`，版本 0.1.2 / build 3）
- 来源：Remote Buddy（遥控搭子）项目，作者 zfdang 及贡献者
- 上游仓库：https://github.com/zfdang/remote-buddy （GPL-3.0-only，完整对应源码随其 Release 发布）

## 修改说明（GPL v3 第 5(a) 条）

本驱动是 Existential Audio **BlackHole v0.7.2** 的修改版本：

- BlackHole 上游修订：`561d934c77a1fa64987e01ccabe890fed30e181f`
  https://github.com/ExistentialAudio/BlackHole
- 修改补丁：`third_party/blackhole/device-usb.patch`（把设备级 `kAudioDevicePropertyTransportType` 由 `kAudioDeviceTransportTypeVirtual` 改为 `kAudioDeviceTransportTypeUSB`，使豆包等只枚举 USB transport 麦克风的输入法能够识别该回环设备）
- 以 Remote Buddy 的 Bundle ID（`com.zfdang.remote-buddy.mic`）、固定 UID（`BuddyMic2ch_UID`）与产品品牌编译。

完整许可证文本见 `LICENSES/BlackHole-GPL-3.0.txt` 与驱动包内 `Resources/BlackHole-LICENSE`；修改声明见 `NOTICE.txt`。

## 获取对应源码

1. 首选：从上游 https://github.com/zfdang/remote-buddy 的对应 Release 下载完整源码（含 BlackHole 子模块与补丁）。
2. 书面要约：自本发行版起三年内，任何收到本对象代码的人，均可通过本项目 GitHub Issues 联系维护者，以不超过合理复制成本的价格获取上述完整对应源码（含 BlackHole v0.7.2 修订 561d934 与 device-usb.patch）。

本驱动未做超出上述补丁与品牌/标识之外的修改。BlackHole 官方编译二进制版权归 Existential Audio Inc.；此处捆绑的是 GPL 源码派生构建，遵循 GPL-3.0-only。