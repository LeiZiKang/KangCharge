import Foundation

// MARK: - Raw MCP payloads

struct MachineFacts: Codable, Hashable {
    struct Port: Codable, Hashable {
        var index: Int
        var name: String
        var connectorType: String?
        var power: Double
    }

    var productFamily: String?
    var brandEn: String?
    var brandZh: String?
    var friendlyNameEn: String?
    var friendlyNameZh: String?
    var maxPowerBudget: Double
    var ports: [Port]

    static let fallback = MachineFacts(
        productFamily: "CP-02S", brandEn: "CANDYSIGN", brandZh: "制糖工厂",
        friendlyNameEn: "CoCan Mirror", friendlyNameZh: "小电拼 Mirror",
        maxPowerBudget: 160,
        ports: [
            Port(index: 1, name: "A", connectorType: "A", power: 60),
            Port(index: 2, name: "C1", connectorType: "C", power: 140),
            Port(index: 3, name: "C2", connectorType: "C", power: 140),
            Port(index: 4, name: "C3", connectorType: "C", power: 140),
            Port(index: 5, name: "C4", connectorType: "C", power: 140),
        ]
    )

    var supportsExtendedDisplay: Bool {
        (productFamily ?? "").uppercased().replacingOccurrences(of: "-", with: "").hasPrefix("CP02S")
    }

    func port(_ index: Int) -> Port? { ports.first { $0.index == index } }
}

struct PortDetail: Codable, Hashable, Identifiable {
    var port: Int
    var connected: Bool?
    var dieTemperature: String?
    var fcProtocol: String?
    var ioutMa: Double?
    var voutMv: Double?
    var vinMv: Double?
    var sessionChargeMwh: Double?
    var sessionId: Int?
    var deviceBrandEn: String?
    var deviceBrandZh: String?
    var deviceNameEn: String?
    var deviceNameZh: String?

    var id: Int { port }
    var voltage: Double { (voutMv ?? 0) / 1000 }
    var current: Double { (ioutMa ?? 0) / 1000 }
    var power: Double { (voutMv ?? 0) * (ioutMa ?? 0) / 1_000_000 }
    var deviceName: String? { deviceNameZh ?? deviceNameEn }
}

struct PortDetailsResponse: Codable { var ports: [PortDetail] }

struct ChargingStatus: Codable, Hashable {
    var statusBitmask: Int
    func isOn(_ port: Int) -> Bool { statusBitmask & (1 << (port - 1)) != 0 }
}

struct TemperatureModeResponse: Codable, Hashable {
    var mode: Int
    var modeName: String?
}

struct DisplayConfig: Codable, Hashable {
    var level: String?
    var displayMode: String?
    var idleDisplay: String?
    var hourlyChime: Bool?
}

struct DeviceInfo: Codable, Hashable {
    var appVersion: String?
    var fpgaVersion: String?
    var model: String?
    var psn: String?
    var rssi: Int?
    var ssid: String?
    var channel: Int?
    var bssid: String?
}

struct PDStatus: Codable, Hashable, Identifiable {
    var port: Int
    var pdRevision: String?
    var ppsChargingSupported: Bool?
    var requestEprModeCapable: Bool?
    var requestPdoId: Int?
    var operatingVoltage: Double?
    var operatingCurrent: Double?
    var statusTemperature: String?
    var hasEmarker: Bool?
    var cableIsActive: Bool?
    var cableEprModeCapable: Bool?
    var cableMaxVbusVoltage: String?
    var cableMaxVbusCurrent: String?
    var cableUsbHighestSpeed: String?
    var cableLatency: String?
    var cableBrandZh: String?
    var cableBrandEn: String?
    var cableNameZh: String?
    var cableNameEn: String?
    var hasBattery: Bool?
    var batteryPresentCapacity: Double?
    var batteryDesignCapacity: Double?
    var batteryLastFullChargeCapacity: Double?
    var deviceNameZh: String?
    var deviceNameEn: String?
    var sinkMaximumPdp: Double?
    var sinkOperationalPdp: Double?

    var id: Int { port }
    /// operating_voltage is reported in 10 mV units, operating_current in 10 mA units.
    var requestedVoltage: Double? { operatingVoltage.flatMap { $0 > 0 ? $0 / 100 : nil } }
    var requestedCurrent: Double? { operatingCurrent.flatMap { $0 > 0 ? $0 / 100 : nil } }
    var cableName: String? {
        let name = cableNameZh ?? cableNameEn
        let brand = cableBrandZh ?? cableBrandEn
        if let name, let brand, name != brand { return "\(brand) \(name)" }
        return name ?? brand
    }
}

struct PDStatusResponse: Codable { var ports: [PDStatus] }

struct PortStatSample: Codable, Hashable {
    var currentMa: Double
    var powerMw: Double
    var voltageMv: Double
}

struct PortStatsResponse: Codable {
    var count: Int?
    var port: Int?
    var samples: [PortStatSample]
}

// MARK: - Control enums

enum ChargingStrategy: Int, CaseIterable, Codable, Identifiable, Sendable {
    case fast = 0
    case slow = 1
    case usbA = 6
    case highPerformance = 7
    case singlePort = 8

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fast: return "超速充"
        case .slow: return "睡眠慢充"
        case .usbA: return "小家电模式"
        case .highPerformance: return "无线损"
        case .singlePort: return "独享 · C1"
        }
    }

    var subtitle: String {
        switch self {
        case .fast: return "FluxAI 自由流"
        case .slow: return "均衡分配"
        case .usbA: return "C4 模拟 A 口 · 魔拟充"
        case .highPerformance: return "高性能"
        case .singlePort: return "单口极速"
        }
    }

    var detail: String {
        switch self {
        case .fast: return "多设备按需定供，不断连、无分配，日常首选。"
        case .slow: return "每个端口温和输出，安静低温，适合夜间。"
        case .usbA: return "让 C4 口兼容小风扇、台灯等小家电，切换会断电重连。"
        case .highPerformance: return "最大化充电效率，适合紧急补电。"
        case .singlePort: return "仅 C1 输出 140W，其他端口会被关闭。"
        }
    }

    var symbol: String {
        switch self {
        case .fast: return "bolt.fill"
        case .slow: return "moon.stars.fill"
        case .usbA: return "fan.fill"
        case .highPerformance: return "gauge.with.dots.needle.100percent"
        case .singlePort: return "1.circle.fill"
        }
    }

    var needsConfirmation: Bool { self == .usbA || self == .singlePort }

    var displayName: String { "\(title)（\(rawValue)）" }
}

enum TemperatureMode: Int, CaseIterable, Identifiable {
    case power = 0
    case temperature = 1

    var id: Int { rawValue }
    var title: String { self == .power ? "功率优先" : "温度优先" }
    var detail: String { self == .power ? "允许更高温度，换取更强输出" : "主动温控，保持机身凉爽" }
    var symbol: String { self == .power ? "flame.fill" : "snowflake" }
}

enum DisplayLevel: String, CaseIterable, Identifiable {
    case off = "关", low = "低", medium = "中", high = "高"
    var id: String { rawValue }
}

enum StatusDisplayMode: String, CaseIterable, Identifiable {
    case animation = "待机动画优先"
    case power = "功率显示优先"
    var id: String { rawValue }
}

enum IdleDisplay: String, CaseIterable, Identifiable {
    case meteor = "流星", petals = "落花", life = "康威的生命游戏", clock = "时间"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .meteor: return "sparkles"
        case .petals: return "leaf.fill"
        case .life: return "square.grid.3x3.fill"
        case .clock: return "clock.fill"
        }
    }
}

enum PortTemperature {
    static func label(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "cool": return "凉爽"
        case "moderate": return "温和"
        case "warm": return "偏热"
        case .some(let other): return other
        case .none: return "—"
        }
    }
}

// MARK: - Snapshot shared with the widget

struct PortSnapshot: Codable, Hashable, Identifiable {
    var index: Int
    var name: String
    var connector: String
    var maxPower: Double
    var enabled: Bool
    var power: Double
    var voltage: Double
    var current: Double
    var protocolName: String?
    var deviceName: String?
    var temperature: String?

    var id: Int { index }
    var isCharging: Bool { enabled && power >= 0.5 }
}

struct PowerPoint: Codable, Hashable {
    var date: Date
    var watts: Double
}

struct ChargerSnapshot: Codable, Hashable {
    var deviceName: String
    var modelName: String
    var maxPower: Double
    var ports: [PortSnapshot]
    var temperatureMode: Int?
    var fetchedAt: Date
    var history: [PowerPoint] = []

    var totalPower: Double { ports.filter(\.enabled).reduce(0) { $0 + $1.power } }
    var chargingCount: Int { ports.filter(\.isCharging).count }
    var enabledCount: Int { ports.filter(\.enabled).count }

    static let preview = ChargerSnapshot(
        deviceName: "Kang Charge",
        modelName: "小电拼 Mirror",
        maxPower: 160,
        ports: [
            PortSnapshot(index: 1, name: "A", connector: "A", maxPower: 60, enabled: true, power: 4.8, voltage: 5, current: 0.96, protocolName: "Huawei FCP", deviceName: nil, temperature: "cool"),
            PortSnapshot(index: 2, name: "C1", connector: "C", maxPower: 140, enabled: true, power: 58.2, voltage: 20, current: 2.91, protocolName: "PD Fixed High Voltage", deviceName: "MacBook Pro", temperature: "moderate"),
            PortSnapshot(index: 3, name: "C2", connector: "C", maxPower: 140, enabled: true, power: 18.4, voltage: 9, current: 2.04, protocolName: "PD PPS", deviceName: "iPhone", temperature: "cool"),
            PortSnapshot(index: 4, name: "C3", connector: "C", maxPower: 140, enabled: false, power: 0, voltage: 0, current: 0, protocolName: nil, deviceName: nil, temperature: "cool"),
            PortSnapshot(index: 5, name: "C4", connector: "C", maxPower: 140, enabled: true, power: 0.2, voltage: 5.2, current: 0.05, protocolName: "PD Fixed 5V", deviceName: "MacBook Air（M1）", temperature: "cool"),
        ],
        temperatureMode: 0,
        fetchedAt: Date(),
        history: (0..<40).map { PowerPoint(date: Date().addingTimeInterval(Double($0 - 40) * 60), watts: 60 + 25 * sin(Double($0) / 5)) }
    )
}

extension JSONDecoder {
    static let snakeCase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
