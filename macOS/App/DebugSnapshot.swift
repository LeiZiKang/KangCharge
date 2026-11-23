#if DEBUG
import SwiftUI
import AppKit

/// Launch with `open "Kang Charge.app" --args -kcSnapshot YES` to dump PNGs of the
/// dashboard, a port sheet and all widget sizes into the sandbox tmp directory
/// (or `-kcSnapshotDir <path>`; use scripts/screenshots.sh, which builds without the sandbox).
enum DebugSnapshot {
    static let openPortNotification = Notification.Name("KCDebugOpenPort")

    @MainActor
    static func runIfRequested(store: ChargerStore) {
        if UserDefaults.standard.bool(forKey: "kcDemo") { store.loadDemo() }
        guard UserDefaults.standard.bool(forKey: "kcSnapshot") else { return }
        let dir = UserDefaults.standard.string(forKey: "kcSnapshotDir").map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kc-snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: store.isDemo ? 2_000_000_000 : 14_000_000_000)
            if let window = NSApp.windows.first(where: { $0.title == store.deviceName || $0.identifier?.rawValue.contains("main") == true }) {
                let tall = UserDefaults.standard.double(forKey: "kcHeight")
                if tall > 0 {
                    window.setFrame(NSRect(x: 0, y: 0, width: UserDefaults.standard.double(forKey: "kcWidth").nonZero ?? 1180, height: tall), display: true)
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                }
                capture(window, to: dir.appendingPathComponent("main.png"))
                renderDashboard(store: store, dir: dir)
                NotificationCenter.default.post(name: openPortNotification, object: store.isDemo ? 2 : 5)
                try? await Task.sleep(nanoseconds: store.isDemo ? 3_000_000_000 : 16_000_000_000)
                if let sheet = window.attachedSheet { capture(sheet, to: dir.appendingPathComponent("port-sheet.png")) }
            }
            renderWidgets(store: store, dir: dir)
            print("KC_SNAPSHOT_DONE \(dir.path)")
            FileHandle.standardError.write("KC_SNAPSHOT_DONE \(dir.path)\n".data(using: .utf8)!)
        }
    }

    @MainActor
    static func capture(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView else { return }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    @MainActor
    static func renderDashboard(store: ChargerStore, dir: URL) {
        let content = VStack(alignment: .leading, spacing: 16) {
            HeaderView(showDeviceInfo: .constant(false))
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) { ModeCard(); PowerCard(onSelect: { _ in }) }.frame(maxWidth: .infinity)
                VStack(spacing: 16) { PortListCard(onSelect: { _ in }); DeviceCard() }.frame(width: 350)
            }
            HStack(alignment: .top, spacing: 16) {
                TemperatureCard(); DisplayCard(); AllocationCard(showAllocation: .constant(false)).frame(width: 350)
            }
        }
        .padding(24)
        .frame(width: 1180)
        .background(Theme.cream)
        .foregroundStyle(Theme.ink)
        .environmentObject(store)
        .environment(\.colorScheme, .light)
        write(content, scale: 1.5, to: dir.appendingPathComponent("dashboard.png"))

        let setup = SetupView().frame(width: 640, height: 640).environmentObject(store).environment(\.colorScheme, .light)
        write(setup, scale: 2, to: dir.appendingPathComponent("setup.png"))

        let menu = MenuBarPanel().environmentObject(store).environment(\.colorScheme, .light)
        write(menu, scale: 2, to: dir.appendingPathComponent("menubar.png"))
    }

    @MainActor
    static func write<V: View>(_ view: V, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }

    @MainActor
    static func renderWidgets(store: ChargerStore, dir: URL) {
        let snapshot = store.snapshot ?? .preview
        let entry = ChargerEntry(date: .now, snapshot: snapshot, isStale: false)
        let sizes: [(String, CGSize, AnyView)] = [
            ("small", CGSize(width: 170, height: 170), AnyView(SmallWidget(entry: entry))),
            ("medium", CGSize(width: 364, height: 170), AnyView(MediumWidget(entry: entry))),
            ("large", CGSize(width: 364, height: 382), AnyView(LargeWidget(entry: entry))),
        ]
        for (name, size, view) in sizes {
            let content = view
                .foregroundStyle(Theme.ink)
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(WidgetBackground())
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(10)
                .background(Color(white: 0.75))
                .environment(\.colorScheme, .light)
            write(content, scale: 2, to: dir.appendingPathComponent("widget-\(name).png"))
        }
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
#endif
