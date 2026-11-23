import AppIntents
import WidgetKit

enum PortChoice: Int, AppEnum {
    case a = 1, c1, c2, c3, c4

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Port"
    static var caseDisplayRepresentations: [PortChoice: DisplayRepresentation] = [
        .a: "USB-A", .c1: "C1", .c2: "C2", .c3: "C3", .c4: "C4",
    ]
}

enum StrategyChoice: Int, AppEnum {
    case smart = 0, sleep = 1, smallAppliance = 6, performance = 7, c1Only = 8

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Charging Mode"
    static var caseDisplayRepresentations: [StrategyChoice: DisplayRepresentation] = [
        .smart: "Smart", .sleep: "Sleep", .smallAppliance: "Small Appliance",
        .performance: "Performance", .c1Only: "C1 Only",
    ]

    var strategy: ChargingStrategy { ChargingStrategy(rawValue: rawValue) ?? .fast }
}

/// Turns one port on or off. Used by the interactive widget toggles and by Shortcuts.
struct SetPortIntent: AppIntent {
    static var title: LocalizedStringResource = "Turn Charger Port On or Off"
    static var description = IntentDescription("Turns one port of your charger on or off.")

    @Parameter(title: "Port") var port: PortChoice
    @Parameter(title: "On", default: true) var isOn: Bool

    init() {}

    init(port: Int, isOn: Bool) {
        self.port = PortChoice(rawValue: port) ?? .c1
        self.isOn = isOn
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Turn \(\.$port) \(\.$isOn)")
    }

    func perform() async throws -> some IntentResult {
        try await ChargerSource.setPort(port.rawValue, on: isOn)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Charger Status"
    static var description = IntentDescription("Fetches the latest readings from your charger.")

    func perform() async throws -> some IntentResult {
        _ = try? await ChargerSource.fetch()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct SetModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Charging Mode"
    static var description = IntentDescription("Switches your charger to another charging mode.")

    @Parameter(title: "Mode") var mode: StrategyChoice

    init() {}

    func perform() async throws -> some IntentResult {
        try await ChargerSource.setStrategy(mode.strategy)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct TotalPowerIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Charger Power"
    static var description = IntentDescription("Returns how many watts your charger is delivering right now.")

    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let snapshot = try await ChargerSource.fetch()
        let watts = (snapshot.totalPower * 10).rounded() / 10
        return .result(value: watts, dialog: "\(Fmt.watts(watts)) W across \(snapshot.chargingCount) ports")
    }
}
