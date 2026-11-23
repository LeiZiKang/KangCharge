import SwiftUI
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    @Published var snapshot = SnapshotStore.load()
    @Published var isConfigured = ChargerSource.isConfigured
    @Published var isOnline = false
    @Published var lastError: String?
    @Published var busyPorts: Set<Int> = []
    @Published var strategy = AppConfig.lastStrategy
    @Published var thermal = TemperatureMode(rawValue: SnapshotStore.load()?.temperatureMode ?? 0) ?? .power
    @Published var toast: String?
    @Published var connecting = false
    @Published var controlling = false
    private var polling: Task<Void, Never>?
    private var lastReload = Date.distantPast
    private var generation = 0
    private var fetching = false
    private var fetchTask: Task<ChargerSnapshot, Error>?
    private var toastTask: Task<Void, Never>?

    func start() {
        WatchSync.shared.push()
        guard polling == nil, isConfigured else { return }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(3)) } catch { break }
            }
        }
    }
    func stop() { polling?.cancel(); polling = nil }
    private func reload(force: Bool = false) {
        if force || Date().timeIntervalSince(lastReload) >= 60 {
            WidgetCenter.shared.reloadAllTimelines(); lastReload = .now
        }
    }
    private func failed(_ error: Error) {
        // Avoid surfacing server payloads or URLSession URLs that may contain credentials.
        let message: String
        switch error {
        case MCPError.server, MCPError.tool, is URLError:
            message = String(localized: "Couldn't connect to the charger. Check the address and try again.")
        default: message = describe(error)
        }
        lastError = message; toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
    func refresh() async {
        guard isConfigured, !fetching, busyPorts.isEmpty, !controlling else { return }
        fetching = true
        defer { fetching = false; fetchTask = nil }
        let epoch = generation
        do {
            let task = Task { try await ChargerSource.fetch() }
            fetchTask = task
            let fresh = try await task.value
            guard epoch == generation, !Task.isCancelled else { return }
            // A control may have started while the read was in flight.
            guard busyPorts.isEmpty, !controlling else { return }
            snapshot = fresh; isOnline = true; lastError = nil
            strategy = AppConfig.lastStrategy
            thermal = TemperatureMode(rawValue: fresh.temperatureMode ?? 0) ?? .power
            reload()
        } catch {
            guard epoch == generation, !Task.isCancelled else { return }
            isOnline = false; failed(error)
        }
    }
    func setPort(_ index: Int, on: Bool) async {
        guard !busyPorts.contains(index), let i = snapshot?.ports.firstIndex(where: { $0.index == index }) else { return }
        let previous = snapshot!.ports[i]
        busyPorts.insert(index)
        _ = try? await fetchTask?.value
        snapshot?.ports[i].enabled = on
        if !on { snapshot?.ports[i].power = 0 }
        defer { busyPorts.remove(index); reload(force: true) }
        do {
            try await ChargerSource.setPort(index, on: on)
            if let saved = SnapshotStore.load()?.ports.first(where: { $0.index == index }) { snapshot?.ports[i] = saved }
        } catch { snapshot?.ports[i] = previous; failed(error) }
    }
    func setStrategy(_ value: ChargingStrategy) async {
        guard !controlling else { return }
        controlling = true
        _ = try? await fetchTask?.value
        defer { controlling = false; reload(force: true) }
        do { try await ChargerSource.setStrategy(value); strategy = value } catch { failed(error) }
    }
    func setThermal(_ value: TemperatureMode) async {
        guard !controlling else { return }
        controlling = true
        _ = try? await fetchTask?.value
        defer { controlling = false; reload(force: true) }
        do { try await ChargerSource.setTemperatureMode(value); thermal = value } catch { failed(error) }
    }
    func connect(urlString: String, nickname: String) async {
        guard !connecting else { return }
        connecting = true; lastError = nil
        defer { connecting = false }
        guard let url = AppConfig.validatedServerURL(urlString) else { failed(MCPError.badURL); return }
        let probe = ChargerAPI(url: url)
        defer { probe.client.close() }
        do {
            let facts = try await ChargerSource.withTimeout(seconds: 20) { try await probe.machineFacts() }
            if AppConfig.serverURL != url || ChargerSource.isDemo { AppConfig.resetDeviceData(); snapshot = nil }
            AppConfig.setServerURL(url)
            guard AppConfig.serverURL == url else { throw MCPError.notConfigured }
            AppConfig.customDeviceName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            SnapshotStore.saveFacts(facts); ChargerSource.isDemo = false
            isConfigured = true; strategy = AppConfig.lastStrategy; start()
            reload(force: true)
            WatchSync.shared.push()
        } catch { failed(error) }
    }
    func startDemo() {
        stop(); generation += 1; AppConfig.resetDeviceData()
        ChargerSource.isDemo = true
        snapshot = Demo.snapshot(); SnapshotStore.save(snapshot!)
        AppConfig.lastStrategy = .fast
        isConfigured = true; isOnline = true; lastError = nil; strategy = .fast; thermal = .power
        reload(force: true); start()
        WatchSync.shared.push()
    }
    func rename(_ name: String) {
        AppConfig.customDeviceName = name
        snapshot?.deviceName = AppConfig.deviceName
        if let snapshot { SnapshotStore.save(snapshot) }
        reload(force: true)
        WatchSync.shared.push()
    }
    func disconnect() async {
        stop(); generation += 1
        _ = try? await fetchTask?.value
        if !ChargerSource.isDemo { (try? ChargerAPI.current())?.client.close() }
        AppConfig.setServerURL(nil); ChargerSource.isDemo = false; AppConfig.resetDeviceData()
        AppConfig.customDeviceName = nil
        snapshot = nil; isConfigured = false; isOnline = false; lastError = nil; toast = nil
        strategy = nil; thermal = .power; reload(force: true)
        WatchSync.shared.push()
    }
}
