# Changelog

## Unreleased

### Enhanced（本仓库增强）

- 输出设备可配置：`Config.outputDeviceName`（默认 Remote Buddy Mic）替换四处硬编码设备查找（含 2 秒 watchdog），语音可灌入豆包能识别的 USB-transport 回环设备，无需安装 BlackHole 或重启。
- `postKey` 改为真实按下左修饰键 keyDown/keyUp 序列（含纯修饰键组合如左⌘+左⇧），修复豆包等输入法「按住说话」组合键不触发（仅给主键挂 flags 无效）。
- 一体安装包 `Packaging/build-pkg.sh`：打包 App + 捆绑 `RemoteBuddyMic.driver`（GPL-3.0-only，附许可证/修改声明/对应源码信息）+ postinstall 重启 CoreAudio；安装向导引导 PacketLogger 下载与权限授权。
- 实测打通 `0x011B`/固件 0.0.1 批次在 macOS 26.5.1 的语音 + 14 键全链路（root 独占成功、14/14 按键捕获、豆包出字）。
- 新增 `docs/ALLINONE.md`、`docs/DOUBAO.md`。

### 上游

- 支持第二批次遥控器（固件 0.0.1）的按键报告布局：输入特征 `0x002B`、16 位小端 Consumer usage；解码按 handle 区分两种已验证布局，保留 `0x0046` 旧布局与全部旧测试。
- macOS 26+ 普通应用独占 HID 被系统拒绝（kIOReturnNotPermitted，实测 26.6）：独占改由 root 采集助手在接收会话内执行，经 seized/seize-failed 事件同步；停止/崩溃自动解除，BLE 重连自动补独占。修复"按键只登记不执行、只有语音键可用"。
- connected 事件不再清除独占状态：独占由助手持有并跨连接绑定持续有效，仅 disconnected/stopped/error 清除。
- 新增 30 项第二布局单元检查（合计 96/96 通过），完整排查记录见 docs/new-batch-remote-and-macos26.md。

- 移除普通按键接收会话的 12 小时强制停止限制；保持接收直至手动停止、退出或发生需要停止恢复的异常。

- 长按实测95.07秒、4726包、19次保活、一次Handy结果；结束伴随蓝牙断开，明确不保证固定时长。

- 长按语音按实际会话ID每5秒发送ATVV保活；松开/断线/退出取消，增加音频断流保护。
- 默认在应用启动且设备、权限和工具就绪后自动开启普通按键接收；取消/手动停止后本次不重复自动请求。
- 开始语音及保活时重新申请低延迟，避免闲置后连接退慢。

- 新增麦克风固定音量滑杆（0–24dB），自动保存；推荐18dB，比初次修复提高约6dB。

- 为目标 Google 遥控器请求低延迟连接；本地对照从约32恢复到49.92包/秒，退出释放请求，加入运行时ABI检查。
- 蓝牙通知在回调当下复制/消费数据，避免延迟读取可变 characteristic.value。
- 取消24倍AGC、噪声门和提升EQ，使用固定增益、高通与只衰减限幅；音频核心可独立测试。

- YouTube / Netflix 支持选择应用、网址或录制快捷键，增加测试按钮。
- 打开动作只响应按下，配置兼容旧版本。

## 0.1.0 — 2026-10-31

- 从 MIT mi-remote-mapper 扩展为 Google Chromecast Voice Remote 专版，保留历史与归属。
- Google ATVV 写入属性、连续流、ADPCM nibble 顺序与控制同步适配。
- 按需 Apple PacketLogger 接收，支持 IOHID 不转交的单字节报告。
- 14 个普通实体键配置与检测计数，独立语音键，扩展索引折叠展示。
- 键盘、鼠标、滚轮与媒体动作；返回默认 Backspace。
- 多键差分、重复去重、缺失松开保护、原生输入独占和恢复。
- 管理员工具私有验签快照、设置备份恢复、父进程存活检测与异常恢复记录。
- 独立应用身份、配置及日志路径；公开仓库不含本机配置、抓包、录音、签名身份或 Apple 工具。
- 无特权测试与 macOS CI；管理员及硬件检查另行执行。
