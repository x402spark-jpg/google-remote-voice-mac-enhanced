// Privileged, session-scoped capture. No input injection and no raw trace files.
import Foundation
import Security
import Darwin
import IOKit
import IOKit.hid

struct CaptureFailure: LocalizedError {
    let text: String
    var errorDescription: String? { text }
}
let domain = "/Library/Preferences/com.apple.MobileBluetooth.debug"
let rootDirectory = "/private/tmp/com.miremote.mapper.capture"
let backupURL = URL(fileURLWithPath: rootDirectory).appendingPathComponent("original.plist")
var ownsSessionLock = false
var snapshotToRemove: URL?

// macOS 26 起普通应用独占 HID 被拒（kIOReturnNotPermitted），root 可独占（实测 26.6）。
// 接收会话期间由本助手独占 Google 遥控器 HID，阻止原生动作与映射双发；进程退出即自动解除。
var hidSeizeManager: IOHIDManager?
var seizedHIDs: [IOHIDDevice] = []

func releaseHIDSeize() {
    for device in seizedHIDs { _ = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)) }
    seizedHIDs.removeAll()
}

func seizeDevice(_ device: IOHIDDevice) -> Bool {
    guard seizedHIDs.contains(where: { $0 == device }) == false else { return true }
    let pid = (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int) ?? -1
    guard pid == 0x9450 else { return false }
    guard IOHIDDeviceOpen(device, IOOptionBits(0)) == kIOReturnSuccess else { return false }
    _ = IOHIDDeviceClose(device, IOOptionBits(0))
    let seized = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice)) == kIOReturnSuccess
    if seized { seizedHIDs.append(device) } else { _ = IOHIDDeviceOpen(device, IOOptionBits(0)) }
    return seized
}

func forgetHID(_ device: IOHIDDevice) {
    guard let index = seizedHIDs.firstIndex(where: { $0 == device }) else { return }
    let old = seizedHIDs.remove(at: index)
    _ = IOHIDDeviceClose(old, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
}

func reportSeizeIfHeld() {
    guard !seizedHIDs.isEmpty else { return }
    emit(GoogleCaptureRecord(kind: "seized", message: "\(seizedHIDs.count)"))
}

// 返回初次枚举独占成功的设备数；BLE 唤醒重连后的新设备实例由 matching 回调补独占。
func startHIDSeize() -> Int {
    let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(0))
    IOHIDManagerSetDeviceMatching(mgr, [kIOHIDVendorIDKey as String: 0x18D1] as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerRegisterDeviceMatchingCallback(mgr, { _, _, _, dvc in
        if seizeDevice(dvc), !seizedHIDs.isEmpty {
            emit(GoogleCaptureRecord(kind: "seized", message: "\(seizedHIDs.count)"))
        }
    }, nil)
    // 断开的旧实例及时释放，避免 seizedHIDs 随重连次数无限增长。
    IOHIDManagerRegisterDeviceRemovalCallback(mgr, { _, _, _, dvc in
        forgetHID(dvc)
    }, nil)
    if let set = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> {
        for dvc in set { _ = seizeDevice(dvc) }
    }
    hidSeizeManager = mgr
    return seizedHIDs.count
}

func execute(_ path: String, _ arguments: [String], input: Data? = nil) throws -> (Int32, Data) {
    let process = Process(); process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
    let output = Pipe(); process.standardOutput = output; process.standardError = FileHandle.nullDevice
    if let input {
        let pipe = Pipe(); process.standardInput = pipe
        try process.run()
        try pipe.fileHandleForWriting.write(contentsOf: input)
        try pipe.fileHandleForWriting.close()
    } else { try process.run() }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, data)
}
func readDomain() throws -> [String: Any] {
    let (status, data) = try execute("/usr/bin/defaults", ["export", domain, "-"])
    if status != 0 {
        guard !FileManager.default.fileExists(atPath: domain + ".plist") else {
            throw CaptureFailure(text: "原有日志配置读取失败，拒绝覆盖")
        }
        return [:]
    }
    guard let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw CaptureFailure(text: "无法读取原蓝牙日志设置，未作修改")
    }
    return value
}
func writeDomain(_ value: [String: Any]) throws {
    let data = try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0)
    let (status, _) = try execute("/usr/bin/defaults", ["import", domain, "-"], input: data)
    guard status == 0 else { throw CaptureFailure(text: "写入蓝牙日志设置失败") }
}
func reloadLogging() {
    _ = try? execute("/usr/bin/killall", ["-USR1", "bluetoothd"])
}
func restoreSettings() throws {
    guard FileManager.default.fileExists(atPath: backupURL.path) else { return }
    let data = try Data(contentsOf: backupURL)
    guard let original = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        throw CaptureFailure(text: "恢复记录损坏，需要人工检查")
    }
    let restoredDomain = GoogleTraceSettings.restored(try readDomain(), original: original)
    // `defaults import` merges keys; omitting HCITraces does NOT remove it.
    // Delete that exact key first so absent/removed dictionary members restore correctly.
    _ = try execute("/usr/bin/defaults", ["delete", domain, "HCITraces"])
    if original["HCITraces"] != nil { try writeDomain(restoredDomain) }
    reloadLogging()
    let actual = try readDomain()
    let expected = original["HCITraces"] as? NSDictionary
    let restored = actual["HCITraces"] as? NSDictionary
    guard expected == restored else { throw CaptureFailure(text: "蓝牙日志设置恢复校验失败") }
    try FileManager.default.removeItem(at: backupURL)
}

var writer: FileHandle?
func emit(_ record: GoogleCaptureRecord) {
    if var data = try? JSONEncoder().encode(record) {
        data.append(10)
        try? writer?.write(contentsOf: data)
    }
}

do {
    guard getuid() == 0, CommandLine.arguments.count == 6 else {
        throw CaptureFailure(text: "采集助手需要管理员授权和有效会话")
    }
    let cli = URL(fileURLWithPath: CommandLine.arguments[1]).resolvingSymlinksInPath()
    let output = URL(fileURLWithPath: CommandLine.arguments[2])
    // 逗号分隔的候选输入报告 handle（"46,2B"）：两种已实测的 G9N9N 报告布局。
    let attributes = CommandLine.arguments[5].split(separator: ",").compactMap { UInt16($0, radix: 16) }.filter { $0 > 0 }
    guard let parent = Int32(CommandLine.arguments[3]), parent > 1,
          let identifier = UUID(uuidString: CommandLine.arguments[4]),
          !attributes.isEmpty else {
        throw CaptureFailure(text: "会话参数无效")
    }
    // Root only opens an existing, single-link, private regular file owned by the App user.
    let fd = open(output.path, O_WRONLY | O_APPEND | O_NOFOLLOW)
    guard fd >= 0 else { throw CaptureFailure(text: "无法打开私有事件文件") }
    var file = stat(); var directory = stat()
    guard fstat(fd, &file) == 0, file.st_mode & S_IFMT == S_IFREG, file.st_nlink == 1,
          file.st_uid != 0, file.st_mode & 0o077 == 0,
          lstat(output.deletingLastPathComponent().path, &directory) == 0,
          directory.st_mode & S_IFMT == S_IFDIR, directory.st_uid == file.st_uid,
          directory.st_mode & 0o077 == 0 else {
        close(fd); throw CaptureFailure(text: "事件目录权限不安全")
    }
    writer = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    let (parentStatus, parentUID) = try execute("/bin/ps", ["-p", String(parent), "-o", "uid="])
    guard parentStatus == 0, UInt32(String(decoding: parentUID, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) == file.st_uid else {
        throw CaptureFailure(text: "父应用身份不匹配")
    }
    var code: SecStaticCode?
    var requirement: SecRequirement?
    guard cli.lastPathComponent == "packetlogger",
          SecStaticCodeCreateWithPath(cli as CFURL, [], &code) == errSecSuccess,
          SecRequirementCreateWithString(#"anchor apple and identifier "com.apple.packetlogger""# as CFString, [], &requirement) == errSecSuccess,
          let code, SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
        throw CaptureFailure(text: "PacketLogger 的 Apple 签名或工具身份无效")
    }
    if mkdir(rootDirectory, 0o700) != 0 && errno != EEXIST { throw CaptureFailure(text: "无法建立恢复目录") }
    var rootStat = stat()
    guard lstat(rootDirectory, &rootStat) == 0, rootStat.st_uid == 0,
          rootStat.st_mode & S_IFMT == S_IFDIR, rootStat.st_mode & 0o077 == 0 else {
        throw CaptureFailure(text: "管理员恢复目录权限不安全")
    }
    let lockFD = open(rootDirectory + "/session.lock", O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
    guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
        throw CaptureFailure(text: "另一按键接收会话仍在运行，请先停止")
    }
    ownsSessionLock = true
    // Recover any session interrupted by SIGKILL/crash before enabling a new one.
    try restoreSettings()
    // Run only a root-private, fully verified snapshot: a user-writable source
    // must not be replaceable between signature verification and root execution.
    let sourceApp = cli.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    guard sourceApp.pathExtension == "app" else { throw CaptureFailure(text: "请选择完整的 Apple PacketLogger.app") }
    let snapshot = URL(fileURLWithPath: rootDirectory).appendingPathComponent("PacketLogger-\(UUID().uuidString).app")
    snapshotToRemove = snapshot
    let (copyStatus, _) = try execute("/usr/bin/ditto", [sourceApp.path, snapshot.path])
    guard copyStatus == 0 else { throw CaptureFailure(text: "无法建立工具的管理员私有快照") }
    var snapshotCode: SecStaticCode?
    var appRequirement: SecRequirement?
    guard SecStaticCodeCreateWithPath(snapshot as CFURL, [], &snapshotCode) == errSecSuccess,
          SecRequirementCreateWithString(#"anchor apple and identifier "com.apple.PacketLogger""# as CFString, [], &appRequirement) == errSecSuccess,
          let snapshotCode,
          SecStaticCodeCheckValidity(snapshotCode, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckNestedCode), appRequirement) == errSecSuccess else {
        throw CaptureFailure(text: "PacketLogger 完整工具包的签名验证失败")
    }
    let privateCLI = snapshot.appendingPathComponent("Contents/Resources/packetlogger")
    var privateCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(privateCLI as CFURL, [], &privateCode) == errSecSuccess,
          let privateCode, SecStaticCodeCheckValidity(privateCode, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
        throw CaptureFailure(text: "工具私有快照中的命令行签名无效")
    }
    let original = try readDomain()
    let backup = try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0)
    try backup.write(to: backupURL, options: .atomic)
    chmod(backupURL.path, 0o600)
    try writeDomain(GoogleTraceSettings.enabled(original))
    reloadLogging()

    // macOS 26+: 普通应用独占 HID 被系统拒绝，改由本 root 助手在会话内独占（详见 startHIDSeize 注释）。
    let seizedCount = startHIDSeize()
    if seizedCount > 0 {
        emit(GoogleCaptureRecord(kind: "seized", message: "\(seizedCount)"))
    } else {
        emit(GoogleCaptureRecord(kind: "seize-failed", message: "无法独占 Google 遥控器 HID，映射已暂停；请重开按键接收"))
    }

    var process: Process?
    var outputPipe: Pipe?
    var errorPipe: Pipe?
    var generation = 0
    let queue = DispatchQueue(label: "com.miremote.capture.session")
    var decoder = GooglePacketDecoder(peripheralID: identifier.uuidString, attributes: attributes)
    var buffered = Data(); var finished = false; var sourceReady = false
    var errorText = ""
    var recovery = GoogleCaptureRecovery()
    let began = Date()
    let stopPath = output.deletingLastPathComponent().appendingPathComponent("stop").path
    func stopChild() {
        generation += 1 // Ignore already queued callbacks from the old child.
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminationHandler = nil
        if let child = process, child.isRunning {
            child.interrupt()
            for _ in 0..<20 { if !child.isRunning { break }; usleep(50_000) }
            if child.isRunning { kill(child.processIdentifier, SIGKILL); child.waitUntilExit() }
        }
        process = nil; outputPipe = nil; errorPipe = nil
    }
    func finish(_ reason: String, failed: Bool = false) {
        guard !finished else { return }; finished = true
        stopChild()
        releaseHIDSeize()
        emit(GoogleCaptureRecord(kind: "disconnected", message: reason))
        do {
            try restoreSettings()
            if let snapshotToRemove { try? FileManager.default.removeItem(at: snapshotToRemove) }
            emit(GoogleCaptureRecord(kind: failed ? "error" : "stopped", message: reason))
        } catch {
            emit(GoogleCaptureRecord(kind: "error", message: "恢复失败：\(error.localizedDescription)；重新开启接收器会尝试恢复"))
            exit(2)
        }
        exit(failed ? 1 : 0)
    }
    for sig in [SIGTERM, SIGINT, SIGHUP] { signal(sig, SIG_IGN) }
    signal(SIGPIPE, SIG_IGN)
    var signals: [DispatchSourceSignal] = []
    for sig in [SIGTERM, SIGINT, SIGHUP] {
        let source = DispatchSource.makeSignalSource(signal: sig, queue: queue)
        source.setEventHandler { finish("接收器已停止") }; source.resume(); signals.append(source)
    }
    func startChild() throws {
        stopChild()
        let current = generation
        buffered.removeAll(); errorText = ""
        decoder = GooglePacketDecoder(peripheralID: identifier.uuidString, attributes: attributes)
        let child = Process(); child.executableURL = privateCLI
        child.arguments = ["convert", "-s", "-f", "ipnhdsr"]
        let out = Pipe(); let err = Pipe()
        child.standardOutput = out; child.standardError = err
        process = child; outputPipe = out; errorPipe = err
        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            queue.async {
                guard !finished, current == generation, !data.isEmpty else { return }
                buffered.append(data)
                if buffered.count > 1_048_576 { finish("数据行超过安全上限", failed: true); return }
                while let newline = buffered.firstIndex(of: 10) {
                    let line = String(decoding: buffered[..<newline], as: UTF8.self)
                    buffered.removeSubrange(...newline)
                    if line.contains("  ATT Receive ") || line.contains("  HCI Event ") { sourceReady = true }
                    if let record = decoder.feed(line) {
                        emit(record)
                        if record.kind == "connected" {
                            sourceReady = true
                            emit(GoogleCaptureRecord(kind: "ready", message: "已绑定遥控器，等待按键"))
                            // 重连可能复用原 HID 实例（无 matching 回调）；独占仍在持有时重报，
                            // 避免应用端在 disconnected 后永久停用映射。
                            reportSeizeIfHeld()
                        }
                    }
                }
            }
        }
        err.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            queue.async {
                guard !finished, current == generation else { return }
                errorText = String((errorText + String(decoding: data, as: UTF8.self)).suffix(2000))
            }
        }
        child.terminationHandler = { _ in
            queue.async {
                guard !finished, current == generation else { return }
                finish("PacketLogger 已退出，请检查工具和蓝牙状态", failed: true)
            }
        }
        try child.run()
    }
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + 1, repeating: 1)
    timer.setEventHandler {
        if kill(parent, 0) != 0 || FileManager.default.fileExists(atPath: stopPath) {
            finish("应用停止接收，已恢复原设置"); return
        }
        if !sourceReady && Date().timeIntervalSince(began) > 15 {
            finish(errorText.contains("Profile") ? "系统未允许诊断接收，需要检查蓝牙日志配置" : "未收到有效蓝牙记录，请重试", failed: true); return
        }
        if sourceReady && recovery.shouldRefresh(bound: decoder.isBound, now: Date().timeIntervalSince(began)) {
            emit(GoogleCaptureRecord(kind: "disconnected", message: "等待遥控器重连，正在刷新连接绑定…"))
            do { try startChild() }
            catch { finish("刷新连接失败：\(error.localizedDescription)", failed: true); return }
            // 刷新只重启 PacketLogger，HID 独占从未释放；重报状态，避免应用误判映射暂停。
            reportSeizeIfHeld()
        }
        emit(GoogleCaptureRecord(kind: "heartbeat"))
    }
    do { try startChild() } catch { finish("无法启动 PacketLogger：\(error.localizedDescription)", failed: true) }
    emit(GoogleCaptureRecord(kind: "starting", message: "已临时开启诊断接收"))
    timer.resume()
    withExtendedLifetime((signals, timer, lockFD)) { RunLoop.main.run() }
} catch {
    // Startup failures after backup creation must restore too, while holding the session lock.
    // Errors before owning the lock must never restore another live session.
    var message = error.localizedDescription
    releaseHIDSeize()
    if ownsSessionLock {
        do { try restoreSettings() }
        catch { message += "；恢复失败：\(error.localizedDescription)；请重新开启接收器以恢复原设置" }
    }
    if let snapshotToRemove { try? FileManager.default.removeItem(at: snapshotToRemove) }
    emit(GoogleCaptureRecord(kind: "error", message: message))
    fputs("\(message)\n", stderr)
    exit(1)
}
