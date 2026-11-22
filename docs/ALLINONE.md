# 一体安装包指南（Enhanced）

一个 `.pkg` 装好 **Google Remote Voice.app（增强版）** 与 **Remote Buddy Mic 虚拟麦克风驱动**，无需另装 BlackHole、无需重启电脑。

## 安装

1. 从 Releases 下载 `GoogleRemoteVoice-Enhanced-<版本>.pkg`，双击运行。
2. 按向导走：欢迎页 → 许可 → 安装。安装结束会**重启一次 CoreAudio** 加载驱动，系统声音中断几秒后自动恢复，属正常。
3. 本构建未经 Apple 公证：首次打开 App 若被拦，**右键 → 打开**，或在系统设置 → 隐私与安全性里允许。不要为此全局关闭 Gatekeeper/SIP。

## 安装后 5 步

1. **授权**：打开 App，授予 **蓝牙 / 辅助功能 / 输入监控**。
   - 若之前装过旧版且重编译后权限失效：在系统设置对应列表里**先删旧条目（−）再重新添加（+）** App，只拨开关无效。
2. **配对遥控器**：系统设置 → 蓝牙，连接 `Chromecast Remote`。
3. **装 PacketLogger（14 键需要）**：Apple 许可不允许第三方打包，须自行下载：
   - 打开 https://developer.apple.com/download/all/?q=Additional%20Tools （需 Apple 账号；若停在注册页，点 *I'm not interested* 跳过或同意免费协议）。
   - 下载 **Additional Tools for Xcode 正式版**（不带 beta），打开 DMG，把 `Hardware/PacketLogger.app` 拖进「应用程序」。
   - 或在 App 里点「选择工具…」指向 PacketLogger。
4. **设输入法**：见 [豆包配置](DOUBAO.md)。麦克风选 `Remote Buddy Mic`，语音快捷键与 App 的「语音键」一致。
5. **开按键接收**：App 里点「开启按键接收」→ 输管理员密码。先勾「按键检测模式」把 14 键各按一遍，核对计数到 14/14，再**取消勾选**启用映射。

## 使用

- **语音**：按住语音键 **>1.5 秒**再说话，松开即停。遥控器松开就停止推流，**免提/免按模式不适用**。
- **14 键**：方向=光标、OK=回车、返回=退格、主页=Home、音量±=系统音量、静音=系统静音、输入源=Tab；YouTube/Netflix/电源可重录或设为打开应用/网址。

## 排障

- **豆包不出字**：确认麦克风选了 `Remote Buddy Mic`（默认是笔记本麦克风）；快捷键两边一致；按住 >1.5 秒。
- **快捷键不触发**：豆包只认真实修饰键 keyDown 序列，本增强版已处理；用「录制」设组合键，不要只设单键挂 flags。
- **14 键 0/14**：PacketLogger 未装或未被识别；接收需管理员授权；同时只连一支同款遥控器。
- **虚拟声卡未就绪**：驱动未加载，重启 CoreAudio（`sudo killall coreaudiod`）或重启电脑。
- 配置：`~/Library/Application Support/GoogleRemoteVoice/config.json`；日志：`~/Library/Logs/GoogleRemoteVoice/engine.log`。

## 许可

应用代码 MIT；捆绑驱动 GPL-3.0-only（BlackHole 派生，见 `LICENSES/` 与 `Packaging/Vendor/SOURCE.md`）；PacketLogger 为 Apple 专有工具，不捆绑。