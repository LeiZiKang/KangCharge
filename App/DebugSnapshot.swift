#if DEBUG
import SwiftUI
import AppKit
import KangChargeCore
import KangChargeUI

enum DebugSnapshot {
    @MainActor
    static func runIfRequested(store: ChargerStore) {
        if UserDefaults.standard.bool(forKey: "kcDemo") { store.loadDemo() }
        guard UserDefaults.standard.bool(forKey: "kcSnapshot") else { return }
        let dir = UserDefaults.standard.string(forKey: "kcSnapshotDir").map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kc-snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            renderAll(store: store, dir: dir)
            print("KC_SNAPSHOT_DONE \(dir.path)")
            FileHandle.standardError.write("KC_SNAPSHOT_DONE \(dir.path)\n".data(using: .utf8)!)
            NSApp.terminate(nil)
        }
    }

    @MainActor
    static func renderAll(store: ChargerStore, dir: URL) {
        let schemes: [(String, ColorScheme)] = [("light", .light), ("dark", .dark)]
        let snapshot = store.snapshot ?? KCDemo.snapshot()
        let entry = ChargerEntry(
            date: .now,
            snapshot: snapshot,
            energySummary: KCDemo.energySummary(weeks: 26),
            isStale: false
        )

        for (suffix, scheme) in schemes {
            let sidebarBg = scheme == .dark ? Color(red: 0.13, green: 0.13, blue: 0.14) : Color(red: 0.945, green: 0.941, blue: 0.925)
            let canvasBg = KCStyle.canvasBackground(for: scheme)

            // Render two-column Apple Music-inspired composition cleanly for README/audit
            let overview = HStack(spacing: 0) {
                mockSidebar(store: store, scheme: scheme)
                    .frame(width: 224)
                    .background(sidebarBg)
                Divider()
                ZStack(alignment: .bottom) {
                    OverviewBody(onSelectPort: { _ in })
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(canvasBg)
                    FloatingControlBar(confirmingStrategy: .constant(nil))
                        .padding(.bottom, 16)
                }
            }
            .frame(width: 1040, height: 930)
            .clipped()
            .environmentObject(store)
            .environmentObject(UpdateChecker.shared)
            .environment(\.colorScheme, scheme)

            write(overview, scale: 2, to: dir.appendingPathComponent("dashboard-\(suffix).png"))

            let menu = MenuBarPanel()
                .background(scheme == .dark ? Color(red: 0.15, green: 0.15, blue: 0.16) : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 14, y: 4)
                .padding(14)
                .background(sidebarBg)
                .environmentObject(store)
                .environmentObject(AppVisibility.shared)
                .environment(\.colorScheme, scheme)
            write(menu, scale: 2, to: dir.appendingPathComponent("menubar-\(suffix).png"))

            let widgetSizes: [(String, CGSize, AnyView)] = [
                ("widget-small-\(suffix)", CGSize(width: 170, height: 170), AnyView(SmallPowerWidget(entry: entry))),
                ("widget-medium-\(suffix)", CGSize(width: 364, height: 170), AnyView(MediumPowerWidget(entry: entry))),
                ("widget-large-\(suffix)", CGSize(width: 364, height: 382), AnyView(LargePowerWidget(entry: entry))),
                ("widget-heatmap-medium-\(suffix)", CGSize(width: 364, height: 170), AnyView(EnergyHeatmapWidgetView(entry: entry, overrideFamily: .systemMedium))),
                ("widget-heatmap-large-\(suffix)", CGSize(width: 364, height: 382), AnyView(EnergyHeatmapWidgetView(entry: entry, overrideFamily: .systemLarge))),
            ]
            for (name, size, view) in widgetSizes {
                let card = view
                    .padding(16)
                    .frame(width: size.width, height: size.height)
                    .background(scheme == .dark ? Color(red: 0.14, green: 0.14, blue: 0.15) : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.35 : 0.10), radius: 14, y: 4)
                    .padding(16)
                    .background(sidebarBg)
                    .environment(\.colorScheme, scheme)
                write(card, scale: 2, to: dir.appendingPathComponent("\(name).png"))
            }
        }
    }

    @MainActor
    private static func mockSidebar(store: ChargerStore, scheme: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    StatusDot(connection: store.connection)
                    Text(store.deviceName).font(.headline.weight(.semibold))
                }
                Text(store.facts.localizedName).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 4) {
                sidebarItem("Overview", icon: "bolt.circle", selected: true)
                sidebarItem("Daily Energy", icon: "calendar", badge: KCFormat.energy(wattHours: store.energySummary.todayWattHours))
                sidebarItem("Controls", icon: "slider.horizontal.3")
                sidebarItem("Hardware", icon: "cpu")
            }
            .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text("PORTS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
                ForEach(store.ports) { port in
                    HStack(spacing: 8) {
                        Image(systemName: DeviceSymbol.systemName(for: port))
                            .font(.caption)
                            .foregroundStyle(port.isCharging ? .primary : .secondary)
                            .frame(width: 16)
                        Text(port.deviceName ?? KCFormat.portDisplayName(port))
                            .font(.callout)
                            .foregroundStyle(port.enabled ? .primary : .secondary)
                            .lineLimit(1)
                        Spacer()
                        if port.isCharging {
                            Text("\(KCFormat.watts(port.power)) W")
                                .font(.caption2.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                }
            }
            .padding(.horizontal, 8)

            Spacer()
        }
        .padding(.top, 22)
    }

    private static func sidebarItem(_ title: String, icon: String, selected: Bool = false, badge: String? = nil) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(selected ? KCStyle.accent : .secondary)
                .frame(width: 18)
            Text(title)
                .font(.callout.weight(selected ? .medium : .regular))
            Spacer()
            if let badge {
                Text(badge).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(selected ? Color.primary.opacity(0.08) : .clear))
    }

    @MainActor
    static func write<V: View>(_ view: V, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        if let image = renderer.nsImage,
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
}
#endif
