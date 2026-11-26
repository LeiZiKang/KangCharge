import SwiftUI
import AppKit
import Combine
import KangChargeCore
import KangChargeUI

/// Manages macOS Dock persistence and Menu Bar visibility using native AppKit
/// (`NSApplication.setActivationPolicy` + `NSStatusItem` + `NSPopover`).
/// Avoids SwiftUI's `MenuBarExtra(isInserted:)` menu-bar graph invalidation loop on macOS 27.
@MainActor
final class AppVisibility: ObservableObject {
    static let shared = AppVisibility()
    static let reopenMainWindowNotification = Notification.Name("KangCharge.ReopenMainWindow")

    private enum Key {
        static let showInDock = "kc.showInDock"
        static let showInMenuBar = "kc.showInMenuBar"
    }

    @Published var showInDock: Bool {
        didSet {
            guard showInDock != oldValue else { return }
            if !showInDock && !showInMenuBar {
                showInMenuBar = true
            }
            UserDefaults.standard.set(showInDock, forKey: Key.showInDock)
            applyActivationPolicy()
        }
    }

    @Published var showInMenuBar: Bool {
        didSet {
            guard showInMenuBar != oldValue else { return }
            if !showInMenuBar && !showInDock {
                showInDock = true
            }
            UserDefaults.standard.set(showInMenuBar, forKey: Key.showInMenuBar)
            StatusBarController.shared.setVisible(showInMenuBar)
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        let dock = defaults.object(forKey: Key.showInDock) as? Bool ?? true
        let menuBar = defaults.object(forKey: Key.showInMenuBar) as? Bool ?? true
        self.showInDock = dock || !menuBar
        self.showInMenuBar = menuBar
    }

    func applyActivationPolicy() {
        guard !ChargerStore.isRunningInPreview else { return }
        let target: NSApplication.ActivationPolicy = showInDock ? .regular : .accessory
        if NSApp?.activationPolicy() != target {
            NSApp?.setActivationPolicy(target)
        }
        if showInDock {
            NSApp?.activate(ignoringOtherApps: true)
        }
    }
}

/// Native NSStatusItem + NSPopover controller for reliable live wattage display and instant show/hide toggling.
@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables: Set<AnyCancellable> = []
    private var configured = false

    func attach(store: ChargerStore, onOpenMainWindow: @escaping () -> Void) {
        guard !ChargerStore.isRunningInPreview, !configured else { return }
        configured = true

        let pop = NSPopover()
        pop.behavior = .transient
        pop.animates = true
        let rootView = MenuBarPanel(onOpenMainWindow: { [weak self] in
            self?.popover?.performClose(nil)
            onOpenMainWindow()
        })
        .environmentObject(store)
        .environmentObject(AppVisibility.shared)
        .tint(KCStyle.accent)
        pop.contentViewController = NSHostingController(rootView: rootView)
        self.popover = pop

        setVisible(AppVisibility.shared.showInMenuBar)
        updateTitle(store: store)

        store.$snapshot
            .combineLatest(store.$isConfigured)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak store] _, _ in
                guard let self, let store else { return }
                self.updateTitle(store: store)
            }
            .store(in: &cancellables)
    }

    func setVisible(_ visible: Bool) {
        guard !ChargerStore.isRunningInPreview else { return }
        if visible {
            if statusItem == nil {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = item.button {
                    button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "SugarWatt")
                    button.imagePosition = .imageLeading
                    button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
                    button.target = self
                    button.action = #selector(togglePopover(_:))
                }
                statusItem = item
            }
            statusItem?.isVisible = true
        } else {
            popover?.performClose(nil)
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }

    private func updateTitle(store: ChargerStore) {
        guard let button = statusItem?.button else { return }
        if store.isConfigured {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "SugarWatt")
            button.title = " \(KCFormat.watts(store.totalPower))W"
        } else {
            button.image = NSImage(systemSymbolName: "bolt.slash", accessibilityDescription: "SugarWatt")
            button.title = ""
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            AppVisibility.shared.applyActivationPolicy()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "kcSnapshot") {
                NSApp.activate(ignoringOtherApps: true)
            }
            #endif
        }
    }

    /// Stay resident in Dock and/or Menu Bar when the main window closes so live polling
    /// and the daily energy ledger keep updating cleanly in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Reopen the main window when the user clicks the Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: AppVisibility.reopenMainWindowNotification, object: nil)
        }
        return true
    }
}
