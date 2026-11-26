import SwiftUI
import WidgetKit
import KangChargeCore
import KangChargeUI

/// Pure in-memory fixtures for instant Xcode Canvas previews (zero network, zero I/O).
@MainActor
private enum PreviewFixtures {
    static func demoStore() -> ChargerStore {
        ChargerStore(previewDemo: true)
    }

    static func emptyStore() -> ChargerStore {
        ChargerStore(previewDemo: false)
    }

    static func widgetEntry() -> ChargerEntry {
        ChargerEntry(
            date: .now,
            snapshot: KCDemo.snapshot(),
            energySummary: KCDemo.energySummary(weeks: 26),
            isStale: false
        )
    }
}

private struct InteractiveWorkbench: View {
    @StateObject private var store = PreviewFixtures.demoStore()
    @State private var dark = false

    var body: some View {
        DashboardView()
            .environmentObject(store)
            .environmentObject(AppVisibility.shared)
            .environmentObject(UpdateChecker.shared)
            .preferredColorScheme(dark ? .dark : .light)
            .overlay(alignment: .topTrailing) {
                Button(dark ? "Light" : "Dark") { dark.toggle() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(10)
            }
    }
}

// MARK: - Main Apple Music-Style Window Previews

#Preview("0. Interactive Workbench") {
    InteractiveWorkbench()
        .frame(width: 1020, height: 700)
}

#Preview("1. Overview · Light") {
    let store = PreviewFixtures.demoStore()
    DashboardView(initialSelection: .overview)
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .environmentObject(UpdateChecker.shared)
        .frame(width: 1020, height: 740)
        .preferredColorScheme(.light)
}

#Preview("2. Overview · Dark") {
    let store = PreviewFixtures.demoStore()
    DashboardView(initialSelection: .overview)
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .environmentObject(UpdateChecker.shared)
        .frame(width: 1020, height: 740)
        .preferredColorScheme(.dark)
}

#Preview("3. Port Detail (C1)") {
    let store = PreviewFixtures.demoStore()
    DashboardView(initialSelection: .port(2))
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .environmentObject(UpdateChecker.shared)
        .frame(width: 1020, height: 740)
}

#Preview("4. Daily Energy Calendar") {
    let store = PreviewFixtures.demoStore()
    DashboardView(initialSelection: .energy)
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .environmentObject(UpdateChecker.shared)
        .frame(width: 1020, height: 920)
}

#Preview("5. Controls") {
    let store = PreviewFixtures.demoStore()
    DashboardView(initialSelection: .controls)
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .environmentObject(UpdateChecker.shared)
        .frame(width: 1020, height: 740)
}

#Preview("6. Menu Bar · Light & Dark") {
    let store = PreviewFixtures.demoStore()
    HStack(spacing: 20) {
        MenuBarPanel()
            .environmentObject(store)
            .environmentObject(AppVisibility.shared)
            .tint(KCStyle.accent)
            .background(KCStyle.canvasBackground(for: .light))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
            .environment(\.colorScheme, .light)

        MenuBarPanel()
            .environmentObject(store)
            .environmentObject(AppVisibility.shared)
            .tint(KCStyle.accent)
            .background(KCStyle.canvasBackground(for: .dark))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 3)
            .environment(\.colorScheme, .dark)
    }
    .padding(20)
    .background(Color(nsColor: .underPageBackgroundColor))
}

#Preview("7. Settings") {
    let store = PreviewFixtures.demoStore()
    SettingsView()
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .environmentObject(UpdateChecker.shared)
        .tint(KCStyle.accent)
}

#Preview("8. Desktop Widgets") {
    let entry = PreviewFixtures.widgetEntry()
    HStack(alignment: .top, spacing: 20) {
        VStack(spacing: 20) {
            SmallPowerWidget(entry: entry)
                .padding(16)
                .frame(width: 170, height: 170)
                .background(WidgetSurfaceBackground())
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)

            EnergyHeatmapWidgetView(entry: entry, overrideFamily: .systemMedium)
                .padding(16)
                .frame(width: 364, height: 170)
                .background(WidgetSurfaceBackground())
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }

        LargePowerWidget(entry: entry)
            .padding(16)
            .frame(width: 364, height: 360)
            .background(WidgetSurfaceBackground())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }
    .padding(24)
    .background(Color(nsColor: .windowBackgroundColor))
}
