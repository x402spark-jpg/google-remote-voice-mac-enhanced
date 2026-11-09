import Foundation

struct GoogleCaptureRecord: Codable, Equatable {
    var kind: String
    var buttons: [Int] = []
    var message: String = ""
}

struct GooglePacketDecoder {
    let peripheralID: String
    // 两台实测样机的输入报告布局，按键特征 handle → 解码规则一一对应：
    // 0x0046：8 位 Consumer 数组索引（样机固件 26.7）；0x002B：16 位小端 Consumer usage（另一批次，固件 0.0.1）。
    // 新批次/重新配对后布局可能再变，需按 docs/PROTOCOL.md 复验后再扩充。
    let attributes: [UInt16]
    private var connection: UInt16?
    var isBound: Bool { connection != nil }
    init(peripheralID: String, attributes: [UInt16]) {
        self.peripheralID = peripheralID.uppercased(); self.attributes = attributes
    }
    // 索引 → Consumer usage 对照（与 Model.swift GVRMap 注释同源；0x002B 布局已在实机验证 14 键）。
    private static let consumerToUsage: [UInt16: Int] = [
        0x019E: 1, 0x00CD: 2, 0x0042: 3, 0x0043: 4, 0x0044: 5, 0x0045: 6, 0x0041: 7,
        0x00E2: 8, 0x0221: 9, 0x0223: 10, 0x0224: 11, 0x00E9: 12, 0x00EA: 13,
        0x0077: 14, 0x0078: 15, 0x0079: 16, 0x0189: 17,
    ]
    private static let row = try! NSRegularExpression(pattern:
        #"^\S+\s{2,}(Config|ATT Receive|HCI Event)\s{2,}Chromecast Remote\s{2,}(0x[0-9a-fA-F]+)\s{2,}RECV\s{2,}(.*)$"#)
    private static let notification = try! NSRegularExpression(pattern:
        #"^Handle Value Notification - Handle:(0x[0-9a-fA-F]+) - Value: ([0-9a-fA-F]+(?: [0-9a-fA-F]+)*)(?:\s{2,}|$)"#)
    mutating func feed(_ line: String) -> GoogleCaptureRecord? {
        let text = line.trimmingCharacters(in: .newlines)
        guard let row = Self.row.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let ns = text as NSString
        let kind = ns.substring(with: row.range(at: 1))
        let handleText = ns.substring(with: row.range(at: 2))
        guard let handle = UInt16(handleText.dropFirst(2), radix: 16) else { return nil }
        let body = ns.substring(with: row.range(at: 3))
        if kind == "Config", body.hasPrefix("Connected:"), body.uppercased().contains(peripheralID) {
            connection = handle
            return GoogleCaptureRecord(kind: "connected")
        }
        guard connection == handle else { return nil }
        if (kind == "HCI Event" && body.hasPrefix("Disconnection Complete")) || (kind == "Config" && body.hasPrefix("Disconnected:")) {
            connection = nil
            return GoogleCaptureRecord(kind: "disconnected")
        }
        guard kind == "ATT Receive",
              let match = Self.notification.firstMatch(in: body, range: NSRange(body.startIndex..., in: body)) else { return nil }
        let description = body as NSString
        guard let attribute = UInt16(description.substring(with: match.range(at: 1)).dropFirst(2), radix: 16),
              attributes.contains(attribute) else { return nil }
        let hex = description.substring(with: match.range(at: 2)).replacingOccurrences(of: " ", with: "")
        if attribute == 0x46 {
            return decodeIndexArray(hex)
        }
        return decodeConsumerCodes(hex)
    }
    // 0x0046：每字节一个按键索引（1-17），0=松开；兼容 1-2 字节（单键/和弦）。
    private func decodeIndexArray(_ hex: String) -> GoogleCaptureRecord? {
        guard hex.count == 2 || hex.count == 4 else { return nil }
        var payload: [Int] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let value = Int(hex[index..<next], radix: 16), value <= 17 else { return nil }
            payload.append(value); index = next
        }
        return GoogleCaptureRecord(kind: "buttons", buttons: Set(payload).subtracting([0]).sorted())
    }
    // 0x002B：每 2 字节一个 16 位小端 Consumer usage，0=松开；兼容 1-2 个 usage 的单键/和弦。
    private func decodeConsumerCodes(_ hex: String) -> GoogleCaptureRecord? {
        guard hex.count == 4 || hex.count == 8, let bytes = Self.parseBytes(hex) else { return nil }
        var payload: [Int] = []
        for offset in stride(from: 0, to: bytes.count, by: 2) {
            let code = bytes[offset] | (UInt16(bytes[offset + 1]) << 8)
            guard code == 0 || Self.consumerToUsage[code] != nil else { return nil }
            if let usage = Self.consumerToUsage[code] { payload.append(usage) }
        }
        return GoogleCaptureRecord(kind: "buttons", buttons: Set(payload).sorted())
    }
    private static func parseBytes(_ hex: String) -> [UInt16]? {
        var bytes: [UInt16] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let value = UInt16(hex[index..<next], radix: 16) else { return nil }
            bytes.append(value); index = next
        }
        return bytes
    }
}

struct GoogleKeyEdge: Equatable {
    var button: Int
    var down: Bool
}

struct GoogleButtonState {
    private(set) var held: Set<Int> = []
    mutating func update(_ buttons: [Int]) -> [GoogleKeyEdge] {
        guard buttons.count <= 2, buttons.allSatisfy({ (1...17).contains($0) }) else { return [] }
        let next = Set(buttons)
        let edges = held.subtracting(next).sorted().map { GoogleKeyEdge(button: $0, down: false) }
            + next.subtracting(held).sorted().map { GoogleKeyEdge(button: $0, down: true) }
        held = next
        return edges
    }
    mutating func releaseAll() -> [GoogleKeyEdge] {
        let edges = held.sorted().map { GoogleKeyEdge(button: $0, down: false) }
        held.removeAll()
        return edges
    }
}

enum GoogleTraceSettings {
    static func enabled(_ current: [String: Any]) -> [String: Any] {
        var result = current
        var traces = current["HCITraces"] as? [String: Any] ?? [:]
        for key in ["StackDebugEnabled", "HCILiveTraces", "HIDTrace", "HCISkipAuth"] { traces[key] = true }
        traces["HCIFileTraces"] = false
        traces["RawAudioTrace"] = false
        result["HCITraces"] = traces
        return result
    }
    static func restored(_ current: [String: Any], original: [String: Any]) -> [String: Any] {
        var result = current
        result["HCITraces"] = original["HCITraces"]
        return result
    }
}

struct LegacyPressFilter {
    private var held: UInt8 = 0
    mutating func accept(_ usage: UInt8) -> Bool {
        if usage != 0 && usage == held { return false }
        held = usage
        return true
    }
}

enum GoogleCapturePolicy {
    static func shouldSeize(active: Bool, deviceCount: Int, connected: Bool, currentID: String?, sessionID: String?) -> Bool {
        guard active, deviceCount == 1, connected, let currentID, let sessionID else { return false }
        return currentID.uppercased() == sessionID.uppercased()
    }
}

// PacketLogger emits its UUID/handle inventory at launch, not on every reconnect.
// Refresh only while unbound; never infer identity from a Bluetooth name/handle.
struct GoogleCaptureRecovery {
    private var lastRefresh: TimeInterval = 0
    mutating func shouldRefresh(bound: Bool, now: TimeInterval) -> Bool {
        guard !bound, now - lastRefresh >= 5 else { return false }
        lastRefresh = now
        return true
    }
}
