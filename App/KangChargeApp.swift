import SwiftUI
import KangChargeCore
import KangChargeUI

@main
struct KangChargeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ChargerStore()

    var body: some Scene {
        Window("SugarWatt", id: "main") {
            MainRootView()
                .environmentObject(store)
                .environmentObject(AppVisibility.shared)
                .environmentObject(UpdateChecker.shared)
                .frame(minWidth: 860, minHeight: 600)
        }
        .defaultSize(width: 1020, height: 700)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .toolbar) {
                Button(L("Refresh", "刷新")) {
                    Task { await store.refreshAll() }
                }
                .keyboardShortcut("r")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(AppVisibility.shared)
                .environmentObject(UpdateChecker.shared)
        }
    }
}

/// Concise bilingual helper (English-first, automatic Simplified Chinese).
func L(_ en: String, _ zh: String) -> String {
    Locale.kcPrefersChinese ? zh : en
}

struct MainRootView: View {
    @EnvironmentObject private var store: ChargerStore
    @EnvironmentObject private var visibility: AppVisibility
    @EnvironmentObject private var updater: UpdateChecker
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if store.isConfigured {
                DashboardView()
            } else {
                SetupView()
            }
        }
        .onAppear {
            guard !ChargerStore.isRunningInPreview else { return }
            visibility.applyActivationPolicy()
            StatusBarController.shared.attach(store: store) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            store.start()
            #if !APP_STORE
            updater.checkOnLaunchIfNeeded()
            #endif
            #if DEBUG
            DebugSnapshot.runIfRequested(store: store)
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: AppVisibility.reopenMainWindowNotification)) { _ in
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
