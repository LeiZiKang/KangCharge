import AppIntents

struct ChargerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: RefreshChargerIntent(), phrases: ["刷新 \(.applicationName)"], shortTitle: "刷新状态", systemImageName: "arrow.clockwise")
        AppShortcut(intent: SetChargingStrategyIntent(), phrases: ["用 \(.applicationName) 切换充电策略"], shortTitle: "切换策略", systemImageName: "bolt.fill")
        AppShortcut(intent: SetPortPowerIntent(), phrases: ["用 \(.applicationName) 开关端口"], shortTitle: "开关端口", systemImageName: "powerplug.fill")
    }
}
