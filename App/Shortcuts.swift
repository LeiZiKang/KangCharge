import AppIntents

struct KangChargeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshChargerIntent(),
            phrases: ["Refresh \(.applicationName)", "Check power in \(.applicationName)"],
            shortTitle: "Refresh Charger",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: SetChargingStrategyIntent(),
            phrases: ["Set charging mode in \(.applicationName)"],
            shortTitle: "Set Charging Mode",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: SetPortPowerIntent(),
            phrases: ["Toggle port in \(.applicationName)"],
            shortTitle: "Toggle Port",
            systemImageName: "power"
        )
    }
}
