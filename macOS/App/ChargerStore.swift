import SwiftUI
import WidgetKit
import AppKit

@MainActor
final class ChargerStore: ObservableObject {
    enum Connection: Equatable {
        case connecting
        case online
        case offline(String)
    }

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        var message: String
        var isError: Bool
    }

    @Published var facts: MachineFacts = SnapshotStore.loadFacts() ?? .fallback
    @Published var info: DeviceInfo?
    @Published var details: [PortDetail] = []
    @Published var status: ChargingStatus?
    @Published var temperatureMode: TemperatureMode?
    @Published var display: DisplayConfig?
    @Published var pd: [Int: PDStatus] = [:]
    @Published var portHistory: [Int: [Double]] = [:]
    @Published var totalHistory: [PowerPoint] = []
    @Published var snapshot: ChargerSnapshot?
    @Published var connection: Connection = .connecting
    @Published var lastUpdated: Date?
    @Published var busy: Set<String> = []
    @Published var toast: Toast?
    @Published var lastStrategy: ChargingStrategy? = AppConfig.lastStrategy
    @Published var deviceName: String = AppConfig.deviceName
    @Published var isConfigured = AppConfig.serverURL != nil

    private var api: ChargerAPI? = try? ChargerAPI.current()
    private var pollTask: Task<Void, Never>?
    private var tick = 0
    private var lastWidgetReload = Date.distantPast
    private var toastTask: Task<Void, Never>?

    init() {
        if let cached = SnapshotStore.load() {
            snapshot = cached
            totalHistory = cached.history
        }
    }

    // MARK: Derived

    var ports: [PortSnapshot] { snapshot?.ports ?? ChargerSnapshot.preview.ports.map { var p = $0; p.power = 0; p.enabled = false; return p } }
    var totalPower: Double { snapshot?.totalPower ?? 0 }
    var maxPower: Double { facts.maxPowerBudget }
    var sessionEnergy: Double { details.compactMap(\.sessionChargeMwh).reduce(0, +) }

    func detail(for port: Int) -> PortDetail? { details.first { $0.port == port } }

    // MARK: Polling

    func start() {
        #if DEBUG
        if isDemo { return }
        #endif
        guard pollTask == nil else { return }
        guard api != nil else {
            connection = .offline(MCPError.notConfigured.localizedDescription)
            return
        }
        pollTask = Task { [weak self] in
            await self?.refreshAll()
            while !Task.isCancelled {
                let interval: Double = NSApp?.isActive == true ? 3 : 8
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self else { return }
                self.tick += 1
                await self.refreshLive()
                if self.tick % 10 == 0 { await self.refreshSlow() }
            }
        }
    }

    func reconnect() {
        pollTask?.cancel()
        pollTask = nil
        api?.client.close()
        api = try? ChargerAPI.current()
        isConfigured = api != nil
        deviceName = AppConfig.deviceName
        connection = .connecting
        start()
    }

    func refreshAll() async {
        guard let api else { return }
        if let facts = try? await api.machineFacts() {
            self.facts = facts
            SnapshotStore.saveFacts(facts)
            deviceName = AppConfig.deviceName
        }
        await refreshLive()
        await refreshSlow()
    }

    func refreshLive() async {
        guard let api else { return }
        async let detailsTask = api.portDetails()
        async let statusTask = api.chargingStatus()
        do {
            let details = try await detailsTask
            let status = try? await statusTask
            apply(details: details, status: status)
            connection = .online
        } catch {
            _ = try? await statusTask
            connection = .offline(error.localizedDescription)
        }
    }

    func refreshSlow() async {
        guard let api else { return }
        async let temperatureTask = api.temperatureMode()
        async let displayTask = api.displayConfig()
        async let infoTask = api.deviceInfo()
        async let pdTask = api.pdStatus()
        if let temperature = try? await temperatureTask { temperatureMode = TemperatureMode(rawValue: temperature.mode) }
        if let display = try? await displayTask { self.display = display }
        if let info = try? await infoTask { self.info = info }
        if let pd = try? await pdTask { self.pd = Dictionary(pd.map { ($0.port, $0) }, uniquingKeysWith: { $1 }) }
        if let snapshot, snapshot.temperatureMode != temperatureMode?.rawValue {
            var updated = snapshot
            updated.temperatureMode = temperatureMode?.rawValue
            self.snapshot = updated
            SnapshotStore.save(updated)
        }
    }

    private func apply(details: [PortDetail], status: ChargingStatus?) {
        let now = Date()
        self.details = details
        if let status { self.status = status }
        let snapshot = ChargerAPI.makeSnapshot(
            facts: facts, details: details, status: status ?? self.status,
            temperatureMode: temperatureMode?.rawValue, previous: self.snapshot ?? SnapshotStore.load(), date: now
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            self.snapshot = snapshot
            self.totalHistory = snapshot.history
            for port in snapshot.ports {
                var values = portHistory[port.index] ?? []
                values.append(port.power)
                portHistory[port.index] = Array(values.suffix(60))
            }
        }
        lastUpdated = now
        SnapshotStore.save(snapshot)
        if now.timeIntervalSince(lastWidgetReload) > 60 {
            lastWidgetReload = now
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Actions

    private func run(_ key: String, success: String, refresh: Bool = true, _ body: @escaping (ChargerAPI) async throws -> Void) {
        guard !busy.contains(key) else { return }
        guard let api else {
            show(MCPError.notConfigured.localizedDescription, isError: true)
            return
        }
        busy.insert(key)
        Task {
            defer { busy.remove(key) }
            do {
                try await body(api)
                show(success, isError: false)
                if refresh {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    await refreshLive()
                    await refreshSlow()
                }
                lastWidgetReload = .distantPast
                WidgetCenter.shared.reloadAllTimelines()
            } catch {
                show(error.localizedDescription, isError: true)
            }
        }
    }

    func setPort(_ index: Int, on: Bool) {
        let name = facts.port(index)?.name ?? "\(index)"
        if var snapshot, let i = snapshot.ports.firstIndex(where: { $0.index == index }) {
            snapshot.ports[i].enabled = on
            withAnimation { self.snapshot = snapshot }
        }
        if let status {
            let mask = on ? status.statusBitmask | (1 << (index - 1)) : status.statusBitmask & ~(1 << (index - 1))
            self.status = ChargingStatus(statusBitmask: mask)
        }
        run("port-\(index)", success: "\(name) 口已\(on ? "打开" : "关闭")") { api in
            try await api.setPorts([index], on: on)
        }
    }

    func setStrategy(_ strategy: ChargingStrategy) {
        run("strategy", success: "已切换到「\(strategy.title)」") { api in
            try await api.setStrategy(strategy)
            await MainActor.run { self.lastStrategy = strategy }
        }
    }

    func setTemperature(_ mode: TemperatureMode) {
        let previous = temperatureMode
        temperatureMode = mode
        run("temperature", success: "温控已设为「\(mode.title)」") { api in
            do { try await api.setTemperatureMode(mode) } catch {
                await MainActor.run { self.temperatureMode = previous }
                throw error
            }
        }
    }

    func setDisplayLevel(_ level: DisplayLevel) {
        display?.level = level.rawValue
        run("display-level", success: "状态屏亮度：\(level.rawValue)") { api in try await api.setDisplayLevel(level) }
    }

    func setStatusDisplayMode(_ mode: StatusDisplayMode) {
        display?.displayMode = mode.rawValue
        run("display-mode", success: "屏显模式：\(mode.rawValue)") { api in try await api.setStatusDisplayMode(mode) }
    }

    func setIdleDisplay(_ idle: IdleDisplay) {
        display?.idleDisplay = idle.rawValue
        run("idle-display", success: "待机显示：\(idle.rawValue)") { api in try await api.setIdleDisplay(idle) }
    }

    func setHourlyChime(_ enabled: Bool) {
        display?.hourlyChime = enabled
        run("hourly-chime", success: "整点报时已\(enabled ? "开启" : "关闭")") { api in try await api.setHourlyChime(enabled) }
    }

    func applyAllocation(_ watts: [Int]) {
        run("allocation", success: "临时功率分配已生效") { api in try await api.setPowerAllocation(watts) }
    }

    func loadStats(port: Int) async throws -> [PortStatSample] {
        #if DEBUG
        if isDemo {
            return (0..<180).map { i in
                let watts = 42 + 14 * sin(Double(i) / 9) + (i > 120 ? -18 : 0)
                return PortStatSample(currentMa: watts / 20 * 1000, powerMw: watts * 1000, voltageMv: 20_000)
            }
        }
        #endif
        guard let api else { throw MCPError.notConfigured }
        return try await api.portStats(port: port).samples
    }

    /// Validates a pasted MCP address by actually talking to the charger, then saves it.
    func connect(to url: URL, nickname: String) async throws {
        let probe = ChargerAPI(url: url)
        defer { probe.client.close() }
        let facts = try await probe.machineFacts()
        if AppConfig.serverURL != url { AppConfig.resetDeviceData() }
        AppConfig.setServerURL(url)
        AppConfig.customDeviceName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        SnapshotStore.saveFacts(facts)
        self.facts = facts
        snapshot = nil
        details = []
        portHistory = [:]
        totalHistory = []
        lastStrategy = AppConfig.lastStrategy
        reconnect()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Forgets the MCP address and all cached device data.
    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        api?.client.close()
        api = nil
        AppConfig.setServerURL(nil)
        AppConfig.resetDeviceData()
        isConfigured = false
        snapshot = nil
        details = []
        connection = .offline(MCPError.notConfigured.localizedDescription)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func show(_ message: String, isError: Bool) {
        let toast = Toast(message: message, isError: isError)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { self.toast = toast }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: isError ? 5_000_000_000 : 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { if self.toast == toast { self.toast = nil } }
        }
    }

    #if DEBUG
    private(set) var isDemo = false

    /// Fills the store with sample data (no network) for README screenshots: `-kcDemo YES`.
    func loadDemo() {
        isDemo = true
        pollTask?.cancel()
        pollTask = nil
        api = nil
        isConfigured = true
        facts = .fallback
        deviceName = "书桌小电拼"
        var demo = ChargerSnapshot.preview
        demo.deviceName = deviceName
        snapshot = demo
        totalHistory = demo.history
        details = demo.ports.map { port in
            PortDetail(port: port.index, connected: true, dieTemperature: port.temperature, fcProtocol: port.protocolName,
                       ioutMa: port.current * 1000, voutMv: port.voltage * 1000, vinMv: 13_000, sessionChargeMwh: 12_400,
                       sessionId: 1, deviceBrandEn: nil, deviceBrandZh: nil, deviceNameEn: nil, deviceNameZh: port.deviceName)
        }
        for port in demo.ports {
            portHistory[port.index] = (0..<40).map { max(0, port.power + sin(Double($0) / 3) * port.power * 0.08) }
        }
        info = DeviceInfo(appVersion: "2.1.18", fpgaVersion: "0.2.19", model: "ultra", psn: "0000000000000000", rssi: -42, ssid: "Home", channel: 6, bssid: nil)
        temperatureMode = .power
        display = DisplayConfig(level: "中", displayMode: "功率显示优先", idleDisplay: "时间", hourlyChime: true)
        lastStrategy = .fast
        pd = [2: PDStatus(port: 2, pdRevision: "PD 3.0", ppsChargingSupported: true, requestEprModeCapable: false, requestPdoId: 4,
                          operatingVoltage: 2000, operatingCurrent: 291, statusTemperature: "moderate", hasEmarker: true,
                          cableIsActive: false, cableEprModeCapable: true, cableMaxVbusVoltage: "50V", cableMaxVbusCurrent: "5A",
                          cableUsbHighestSpeed: "USB 2.0", cableLatency: "<10ns", cableBrandZh: "Apple", cableBrandEn: "Apple",
                          cableNameZh: "240W 编织线", cableNameEn: nil, hasBattery: false, batteryPresentCapacity: nil,
                          batteryDesignCapacity: nil, batteryLastFullChargeCapacity: nil, deviceNameZh: "MacBook Pro",
                          deviceNameEn: nil, sinkMaximumPdp: nil, sinkOperationalPdp: nil)]
        connection = .online
        lastUpdated = Date()
    }
    #endif
}
