# 来源、第三方与许可证

## 代码基础

**mi-remote-mapper — 零度汉化**
https://github.com/81199000/mi-remote-mapper
MIT。保留原仓库提交历史、原始版权以及 LICENSE。菜单栏应用、音频输出、设置与映射基础来自该项目；本扩展聚焦 Google 遥控器。

## 协议与诊断参考

- https://github.com/zfdang/voice-input-buddy — G9N9N 描述符与公开抓包证据边界。
- https://github.com/b0o/ATVVoice — ATVV 协议/会话研究参考；不将其其他样机结果当作本项目验收。
- https://github.com/Tilkmilk/vibe-mote — Google 遥控器 Windows 旁路输入实现参考，平台代码未移植为 macOS 驱动。
- https://github.com/HOLODATA-COM/SiriRemoteForge — 按需 PacketLogger 接收的研究参考，Siri Remote 的验收不等于 G9N9N 验收。
- https://github.com/apple-oss-distributions/IOHIDFamily — HID 处理与报告长度检查参考。

这些项目是研究来源，不表示它们为本项目背书，也不改变各自许可证。协议 UUID、按键 usage 和线格式属于互操作事实；不捆绑这些项目的应用、驱动或二进制。

## 捆绑与单独安装的依赖

- **RemoteBuddyMic.driver（一体包捆绑）**：GPL-3.0-only。BlackHole v0.7.2（修订 561d934）的 USB-transport 派生驱动，来自 https://github.com/zfdang/remote-buddy 。一体安装包随附该驱动对象代码、GPL 许可证（`LICENSES/BlackHole-GPL-3.0.txt`）、修改声明（`Packaging/Vendor/NOTICE.txt`）与对应源码信息（`Packaging/Vendor/SOURCE.md`）。源码构建用户也可改用官方 BlackHole。
- **BlackHole**：https://github.com/ExistentialAudio/BlackHole ，GPL-3.0。上述捆绑驱动的上游；单独安装时作为系统音频驱动使用。
- **Apple PacketLogger**：https://developer.apple.com/bluetooth/ ，Apple 工具，遵守其下载与使用条款。**本仓库/安装包不打包、转售或重新发布 PacketLogger、Additional Tools、Apple 诊断描述文件**；用户须自行从 Apple 官方下载（需 Apple 账号），安装包仅检测并引导。
- **Handy / 豆包输入法 / Typeless 等**：可选外部语音识别/输入工具，独立安装并遵守各自许可证。本应用不捆绑它们或任何语音模型。

Google、Chromecast、Apple 等商标属于相应权利人；本项目是独立社区项目。
