import SwiftUI
import WidgetKit

@MainActor
final class WatchModel: ObservableObject {
    @Published var snapshot = SnapshotStore.load()
    @Published var isConfigured: Bool = {
        #if DEBUG
        // Screenshots / simulator checks: `-kcDemo` starts in sample-data mode.
        if ProcessInfo.processInfo.arguments.contains("-kcDemo") {
            ChargerSource.isDemo = true
            SnapshotStore.save(Demo.snapshot())
        }
        #endif
        return ChargerSource.isConfigured
    }()
    @Published var isOnline = false
    @Published var busyPorts: Set<Int> = []
    @Published var errorMessage: String?
    private var polling: Task<Void, Never>?
    private var fetchTask: Task<ChargerSnapshot, Error>?
    private var controlTask: Task<Void, Error>?
    private var active = false
    private var generation = 0
    private var sync: WatchSync?

    func setActive(_ active: Bool) {
        self.active = active
        if sync == nil { sync = WatchSync(model: self) }
        polling?.cancel(); polling = nil
        guard active, isConfigured else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(5)) } catch { break }
            }
        }
    }

    func refresh() async {
        guard isConfigured, fetchTask == nil, busyPorts.isEmpty else { return }
        let epoch = generation
        let task = Task { try await ChargerSource.fetch() }
        fetchTask = task
        defer { fetchTask = nil }
        do {
            let fresh = try await task.value
            guard generation == epoch, !Task.isCancelled, busyPorts.isEmpty else { return }
            snapshot = fresh; isOnline = true; errorMessage = nil
        } catch {
            guard generation == epoch, !Task.isCancelled else { return }
            isOnline = false
        }
    }

    func applyConfiguration(url: URL?, demo: Bool, nickname: String?) async {
        generation += 1
        let epoch = generation
        polling?.cancel(); polling = nil
        // Drain old reads before changing credentials or clearing the shared cache.
        _ = try? await fetchTask?.value
        _ = try? await controlTask?.value
        guard generation == epoch else { return }
        if AppConfig.serverURL != url || ChargerSource.isDemo != demo { AppConfig.resetDeviceData() }
        AppConfig.setServerURL(url)
        ChargerSource.isDemo = demo
        AppConfig.customDeviceName = nickname
        snapshot = SnapshotStore.load(); isConfigured = ChargerSource.isConfigured; isOnline = false
        setActive(active)
        await refresh()
    }

    func startDemo() async {
        await applyConfiguration(url: nil, demo: true, nickname: nil)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setPort(_ index: Int, on: Bool) async {
        guard busyPorts.isEmpty else { return }
        busyPorts.insert(index)
        let epoch = generation
        defer { busyPorts.remove(index); controlTask = nil; WidgetCenter.shared.reloadAllTimelines() }
        do {
            let read = fetchTask
            let task = Task {
                _ = try? await read?.value
                try await ChargerSource.setPort(index, on: on)
            }
            controlTask = task
            try await task.value
            guard generation == epoch else { return }
            snapshot = SnapshotStore.load(); errorMessage = nil
        } catch {
            guard generation == epoch else { return }
            errorMessage = String(localized: "Couldn't update the port. Try again.")
        }
    }
}
