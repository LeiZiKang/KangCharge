import AppIntents
import WidgetKit

enum ChargerPort: Int, AppEnum {
    case a = 1, c1, c2, c3, c4

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "端口"
    static var caseDisplayRepresentations: [ChargerPort: DisplayRepresentation] = [
        .a: "A 口", .c1: "C1 口", .c2: "C2 口", .c3: "C3 口", .c4: "C4 口",
    ]
}

extension ChargingStrategy: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "充电策略"
    static var caseDisplayRepresentations: [ChargingStrategy: DisplayRepresentation] = [
        .fast: "超速充（FluxAI 自由流）",
        .slow: "睡眠慢充",
        .usbA: "小家电模式",
        .highPerformance: "无线损",
        .singlePort: "独享 · C1",
    ]
}

struct SetPortPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "开关小电拼端口"
    static var description = IntentDescription("打开或关闭 Kang Charge 的某个充电端口。")

    @Parameter(title: "端口") var port: ChargerPort
    @Parameter(title: "打开", default: true) var turnOn: Bool

    init() {}

    init(portIndex: Int, turnOn: Bool) {
        self.port = ChargerPort(rawValue: portIndex) ?? .c1
        self.turnOn = turnOn
    }

    static var parameterSummary: some ParameterSummary {
        Summary("将 \(\.$port) 设为 \(\.$turnOn)")
    }

    func perform() async throws -> some IntentResult {
        let api = try ChargerAPI.current()
        try await api.setPorts([port.rawValue], on: turnOn)
        if var snapshot = SnapshotStore.load(), let i = snapshot.ports.firstIndex(where: { $0.index == port.rawValue }) {
            snapshot.ports[i].enabled = turnOn
            if !turnOn { snapshot.ports[i].power = 0 }
            SnapshotStore.save(snapshot)
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
        _ = try? await api.fetchSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct RefreshChargerIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新小电拼状态"
    static var description = IntentDescription("从 Kang Charge 拉取最新的充电数据。")

    func perform() async throws -> some IntentResult {
        _ = try await ChargerAPI.current().fetchSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SetChargingStrategyIntent: AppIntent {
    static var title: LocalizedStringResource = "切换小电拼充电策略"
    static var description = IntentDescription("切换 Kang Charge 的充电策略。")

    @Parameter(title: "策略") var strategy: ChargingStrategy

    init() {}
    init(strategy: ChargingStrategy) { self.strategy = strategy }

    func perform() async throws -> some IntentResult {
        try await ChargerAPI.current().setStrategy(strategy)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
