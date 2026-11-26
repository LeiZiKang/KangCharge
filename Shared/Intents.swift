import AppIntents
import WidgetKit
import KangChargeCore

enum ChargerPort: Int, AppEnum {
    case a = 1, c1, c2, c3, c4

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Port"
    static var caseDisplayRepresentations: [ChargerPort: DisplayRepresentation] = [
        .a: "USB-A", .c1: "C1", .c2: "C2", .c3: "C3", .c4: "C4",
    ]
}

enum StrategyChoice: Int, AppEnum {
    case smart = 0, sleep = 1, smallAppliance = 6, performance = 7, c1Only = 8

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Charging Mode"
    static var caseDisplayRepresentations: [StrategyChoice: DisplayRepresentation] = [
        .smart: "Smart",
        .sleep: "Sleep",
        .smallAppliance: "Small Appliance",
        .performance: "Performance",
        .c1Only: "C1 Only",
    ]

    var strategy: ChargingStrategy {
        ChargingStrategy(rawValue: rawValue) ?? .fast
    }
}

struct SetPortPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Charger Port"
    static var description = IntentDescription("Turn a SugarWatt charger port on or off.")

    @Parameter(title: "Port") var port: ChargerPort
    @Parameter(title: "Turn On", default: true) var turnOn: Bool

    init() {}

    init(portIndex: Int, turnOn: Bool) {
        self.port = ChargerPort(rawValue: portIndex) ?? .c1
        self.turnOn = turnOn
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Set \(\.$port) to \(\.$turnOn)")
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
    static var title: LocalizedStringResource = "Refresh Charger Status"
    static var description = IntentDescription("Fetch the latest power readings from your charger.")

    func perform() async throws -> some IntentResult {
        _ = try await ChargerAPI.current().fetchSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SetChargingStrategyIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Charging Mode"
    static var description = IntentDescription("Switch the charging strategy on your charger.")

    @Parameter(title: "Mode") var mode: StrategyChoice

    init() {}
    init(strategy: ChargingStrategy) {
        self.mode = StrategyChoice(rawValue: strategy.rawValue) ?? .smart
    }

    func perform() async throws -> some IntentResult {
        try await ChargerAPI.current().setStrategy(mode.strategy)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
