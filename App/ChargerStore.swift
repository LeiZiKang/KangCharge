import SwiftUI
import WidgetKit
import AppKit
import KangChargeCore

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

    @Published var facts: MachineFacts
    @Published var info: DeviceInfo?
    @Published var details: [PortDetail] = []
    @Published var status: ChargingStatus?
    @Published var temperatureMode: TemperatureMode?
    @Published var display: DisplayConfig?
    @Published var pd: [Int: PDStatus] = [:]
    @Published var portHistory: [Int: [Double]] = [:]
    @Published var totalHistory: [PowerPoint] = []
    @Published var snapshot: ChargerSnapshot?
    @Published var energySummary: EnergySummary
    @Published var energyAnalytics: EnergyAnalytics = .empty
    @Published var connection: Connection = .connecting
    @Published var lastUpdated: Date?
    @Published var busy: Set<String> = []
    @Published var toast: Toast?
    @Published var lastStrategy: ChargingStrategy?
    @Published var deviceName: String
    @Published var isConfigured: Bool
    @Published var isDemo = false

    private var api: ChargerAPI?
    private var pollTask: Task<Void, Never>?
    private var tick = 0
    private var lastWidgetReload = Date.distantPast
    private var toastTask: Task<Void, Never>?
    private var ledgerObserver: NSObjectProtocol?

    static var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static let heatmapWeeks = 47

    init(previewDemo: Bool? = nil) {
        if let previewDemo {
            self.facts = .fallback
            self.energySummary = KCDemo.energySummary(weeks: Self.heatmapWeeks)
            self.energyAnalytics = previewDemo ? KCDemo.energyAnalytics() : .empty
            self.lastStrategy = previewDemo ? .fast : nil
            self.deviceName = "Desk Charger"
            self.isConfigured = previewDemo
            if previewDemo {
                loadDemo()
            }
            return
        }

        if Self.isRunningInPreview {
            self.facts = .fallback
            self.energySummary = KCDemo.energySummary(weeks: Self.heatmapWeeks)
            self.energyAnalytics = KCDemo.energyAnalytics()
            self.lastStrategy = .fast
            self.deviceName = "Desk Charger"
            self.isConfigured = true
            loadDemo()
            return
        }

        self.facts = SnapshotStore.loadFacts() ?? .fallback
        self.energySummary = EnergyLedger.shared.summary(weeks: Self.heatmapWeeks)
        self.energyAnalytics = EnergyLedger.shared.analytics()
        self.lastStrategy = AppConfig.lastStrategy
        self.deviceName = AppConfig.deviceName
        self.isConfigured = AppConfig.serverURL != nil
        self.api = try? ChargerAPI.current()

        if let cached = SnapshotStore.load() {
            snapshot = cached
            totalHistory = cached.history
        }
        ledgerObserver = NotificationCenter.default.addObserver(
            forName: EnergyLedger.didUpdateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isDemo else { return }
                self.energySummary = EnergyLedger.shared.summary(weeks: Self.heatmapWeeks)
                self.energyAnalytics = EnergyLedger.shared.analytics(portNames: self.portLabelMap())
            }
        }
    }

    deinit {
        if let ledgerObserver { NotificationCenter.default.removeObserver(ledgerObserver) }
    }

    // MARK: Derived

    var ports: [PortSnapshot] {
        snapshot?.ports ?? KCDemo.snapshot().ports.map { var p = $0; p.power = 0; p.enabled = false; return p }
    }
    var totalPower: Double { snapshot?.totalPower ?? 0 }
    var maxPower: Double { facts.maxPowerBudget }
    var sessionEnergyMwh: Double {
        let fromDetails = details.compactMap(\.sessionChargeMwh).reduce(0, +)
        return fromDetails > 0 ? fromDetails : (snapshot?.sessionEnergyMwh ?? 0)
    }

    func detail(for port: Int) -> PortDetail? { details.first { $0.port == port } }

    // MARK: Polling

    func start() {
        if isDemo { return }
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
        isDemo = false
        pollTask?.cancel()
        pollTask = nil
        api?.client.close()
        api = try? ChargerAPI.current()
        isConfigured = api != nil
        deviceName = AppConfig.deviceName
        connection = .connecting
        energySummary = EnergyLedger.shared.summary(weeks: 44)
        start()
    }

    func refreshAll() async {
        if isDemo {
            if let current = snapshot {
                snapshot = KCDemo.tick(current)
                totalHistory = snapshot?.history ?? []
                lastUpdated = Date()
            }
            return
        }
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
        withAnimation(.easeInOut(duration: 0.3)) {
            self.snapshot = snapshot
            self.totalHistory = snapshot.history
            self.energySummary = EnergyLedger.shared.summary(weeks: Self.heatmapWeeks, endingAt: now)
            self.energyAnalytics = EnergyLedger.shared.analytics(portNames: self.portLabelMap())
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
        if isDemo {
            show(success, isError: false)
            return
        }
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
            if !on { snapshot.ports[i].power = 0 }
            else if isDemo { snapshot.ports[i].power = KCDemo.basePower[index] ?? 0 }
            withAnimation(.easeInOut(duration: 0.2)) { self.snapshot = snapshot }
        }
        if let status {
            let mask = on ? status.statusBitmask | (1 << (index - 1)) : status.statusBitmask & ~(1 << (index - 1))
            self.status = ChargingStatus(statusBitmask: mask)
        }
        let zh = Locale.kcPrefersChinese
        let msg = zh ? "\(name) 口已\(on ? "开启" : "关闭")" : "\(name) turned \(on ? "on" : "off")"
        run("port-\(index)", success: msg) { api in
            try await api.setPorts([index], on: on)
        }
    }

    func setStrategy(_ strategy: ChargingStrategy) {
        let zh = Locale.kcPrefersChinese
        let msg = zh ? "已切换到 \(strategy.localizedName)" : "Mode set to \(strategy.localizedName)"
        if isDemo { lastStrategy = strategy; show(msg, isError: false); return }
        run("strategy", success: msg) { api in
            try await api.setStrategy(strategy)
            await MainActor.run { self.lastStrategy = strategy }
        }
    }

    func setTemperature(_ mode: TemperatureMode) {
        let previous = temperatureMode
        temperatureMode = mode
        let zh = Locale.kcPrefersChinese
        let msg = zh ? "温控：\(mode.localizedName)" : "Thermal: \(mode.localizedName)"
        run("temperature", success: msg) { api in
            do { try await api.setTemperatureMode(mode) } catch {
                await MainActor.run { self.temperatureMode = previous }
                throw error
            }
        }
    }

    func setDisplayLevel(_ level: DisplayLevel) {
        display?.level = level.rawValue
        let zh = Locale.kcPrefersChinese
        run("display-level", success: zh ? "亮度：\(level.localizedName)" : "Brightness: \(level.localizedName)") { api in
            try await api.setDisplayLevel(level)
        }
    }

    func setStatusDisplayMode(_ mode: StatusDisplayMode) {
        display?.displayMode = mode.rawValue
        let zh = Locale.kcPrefersChinese
        run("display-mode", success: zh ? "屏显：\(mode.localizedName)" : "Display: \(mode.localizedName)") { api in
            try await api.setStatusDisplayMode(mode)
        }
    }

    func setIdleDisplay(_ idle: IdleDisplay) {
        display?.idleDisplay = idle.rawValue
        let zh = Locale.kcPrefersChinese
        run("idle-display", success: zh ? "待机动画：\(idle.localizedName)" : "Idle screen: \(idle.localizedName)") { api in
            try await api.setIdleDisplay(idle)
        }
    }

    func setHourlyChime(_ enabled: Bool) {
        display?.hourlyChime = enabled
        let zh = Locale.kcPrefersChinese
        run("hourly-chime", success: zh ? "整点报时已\(enabled ? "开启" : "关闭")" : "Hourly chime \(enabled ? "on" : "off")") { api in
            try await api.setHourlyChime(enabled)
        }
    }

    func applyAllocation(_ watts: [Int]) {
        let zh = Locale.kcPrefersChinese
        run("allocation", success: zh ? "临时功率分配已生效" : "Power allocation applied") { api in
            try await api.setPowerAllocation(watts)
        }
    }

    func loadStats(port: Int) async throws -> [PortStatSample] {
        if isDemo {
            return (0..<180).map { i in
                let watts = 46 + 14 * sin(Double(i) / 9) + (i > 120 ? -16 : 0)
                return PortStatSample(currentMa: watts / 20 * 1000, powerMw: watts * 1000, voltageMv: 20_000)
            }
        }
        guard let api else { throw MCPError.notConfigured }
        return try await api.portStats(port: port).samples
    }

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

    func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        api?.client.close()
        api = nil
        isDemo = false
        AppConfig.setServerURL(nil)
        AppConfig.resetDeviceData()
        isConfigured = false
        snapshot = nil
        details = []
        connection = .offline(MCPError.notConfigured.localizedDescription)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func resetEnergyHistory() {
        EnergyLedger.shared.reset()
        energySummary = EnergyLedger.shared.summary(weeks: Self.heatmapWeeks)
        energyAnalytics = .empty
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func portLabelMap() -> [Int: String] {
        var map: [Int: String] = [:]
        for port in ports {
            let base = port.name == "A" ? "USB-A" : port.name
            if let device = port.deviceName, !device.isEmpty {
                map[port.index] = "\(base) · \(device)"
            } else {
                map[port.index] = base
            }
        }
        return map
    }

    func show(_ message: String, isError: Bool) {
        let toast = Toast(message: message, isError: isError)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { self.toast = toast }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(nanoseconds: isError ? 5_000_000_000 : 2_600_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { if self.toast == toast { self.toast = nil } }
        }
    }

    /// Enters interactive sample-data mode (available both in Debug and Release so anyone can preview without hardware).
    func loadDemo() {
        isDemo = true
        pollTask?.cancel()
        pollTask = nil
        api = nil
        isConfigured = true
        facts = .fallback
        let demo = KCDemo.snapshot()
        deviceName = demo.deviceName
        snapshot = demo
        totalHistory = demo.history
        energySummary = KCDemo.energySummary(weeks: Self.heatmapWeeks)
        energyAnalytics = KCDemo.energyAnalytics()
        details = demo.ports.map { port in
            PortDetail(
                port: port.index, connected: port.enabled, dieTemperature: port.temperature,
                fcProtocol: port.protocolName, ioutMa: port.current * 1000, voutMv: port.voltage * 1000,
                vinMv: 13_000, sessionChargeMwh: port.sessionChargeMwh, sessionId: 1,
                deviceNameEn: port.deviceName, deviceNameZh: port.deviceName
            )
        }
        for port in demo.ports {
            portHistory[port.index] = (0..<40).map { max(0, port.power + sin(Double($0) / 3) * port.power * 0.08) }
        }
        info = DeviceInfo(appVersion: "2.1.18", fpgaVersion: "0.2.19", model: "ultra", psn: "0000000000000000", rssi: -42, ssid: "Home", channel: 6, bssid: nil)
        temperatureMode = .power
        display = DisplayConfig(level: "中", displayMode: "功率显示优先", idleDisplay: "时间", hourlyChime: true)
        lastStrategy = .fast
        pd = KCDemo.samplePDStatus()
        connection = .online
        lastUpdated = Date()
    }
}
