import SwiftUI
import WidgetKit
import BackgroundTasks
import AppIntents

@main
struct KangChargeApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase
    nonisolated private var refreshID: String { (Bundle.main.bundleIdentifier ?? "KangCharge") + ".refresh" }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(model).tint(KC.accent)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { model.start() }
                    else { model.stop(); if phase == .background { scheduleRefresh() } }
                }
        }
        .backgroundTask(.appRefresh(refreshID)) {
            defer { scheduleRefresh() }
            guard ChargerSource.isConfigured else { return }
            _ = try? await ChargerSource.fetch()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    nonisolated private func scheduleRefresh() {
        guard ChargerSource.isConfigured else { return }
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var model: AppModel
    var body: some View {
        Group {
            if model.isConfigured { HomeView() } else { SetupView() }
        }
        .task { if scenePhase == .active { model.start() } }
    }
}
struct KangChargeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: SetPortIntent(), phrases: ["Turn a port on or off with \(.applicationName)"], shortTitle: "Control Port", systemImageName: "power")
        AppShortcut(intent: RefreshIntent(), phrases: ["Refresh \(.applicationName)"], shortTitle: "Refresh Charger", systemImageName: "arrow.clockwise")
        AppShortcut(intent: SetModeIntent(), phrases: ["Set charging mode in \(.applicationName)"], shortTitle: "Set Mode", systemImageName: "bolt.fill")
        AppShortcut(intent: TotalPowerIntent(), phrases: ["Get power from \(.applicationName)"], shortTitle: "Charger Power", systemImageName: "gauge")
    }
}
