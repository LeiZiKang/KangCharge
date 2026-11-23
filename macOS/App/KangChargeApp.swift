import SwiftUI

@main
struct KangChargeApp: App {
    @StateObject private var store = ChargerStore()

    var body: some Scene {
        Window("Kang Charge", id: "main") {
            Group {
                if store.isConfigured { DashboardView() } else { SetupView() }
            }
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 680)
                .preferredColorScheme(.light)
                .onAppear {
                    store.start()
                    #if DEBUG
                    DebugSnapshot.runIfRequested(store: store)
                    #endif
                }
        }
        .defaultSize(width: 1180, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("刷新") { Task { await store.refreshAll() } }
                    .keyboardShortcut("r")
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .onAppear { store.start() }
        } label: {
            if store.isConfigured {
                Text("\(Image(systemName: "bolt.fill")) \(Format.watts(store.totalPower))W")
            } else {
                Image(systemName: "bolt.slash")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
