import Foundation

enum AppConfig {
    /// App Group shared by the app and the widget. Injected at build time from
    /// `$(TeamIdentifierPrefix)$(BUNDLE_ID_PREFIX).kangcharge` via Info.plist.
    static let appGroup: String? = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "KCAppGroup") as? String,
              !value.isEmpty, !value.contains("$("),
              value != Bundle.main.bundleIdentifier else { return nil }  // no Team ID → no real App Group
        return value
    }()
    static let widgetKind = "KangChargeWidget"

    static let defaults: UserDefaults = appGroup.flatMap { UserDefaults(suiteName: $0) } ?? .standard

    enum Key {
        static let serverURL = "serverURL"
        static let deviceName = "deviceName"
        static let snapshot = "snapshot.v1"
        static let facts = "machineFacts.v1"
        static let lastStrategy = "lastStrategy"
    }

    /// The personal MCP SSE endpoint copied from the CANDYSIGN app. It embeds the
    /// device serial and an access token, so it is only ever stored on this Mac.
    static var serverURL: URL? {
        defaults.string(forKey: Key.serverURL).flatMap(validatedServerURL)
    }

    static func setServerURL(_ url: URL?) {
        defaults.set(url?.absoluteString, forKey: Key.serverURL)
    }

    static func validatedServerURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", url.host != nil else { return nil }
        return url
    }

    /// Name shown in the UI: the user's own nickname, else the model name reported by the device.
    static var deviceName: String {
        if let custom = customDeviceName { return custom }
        return SnapshotStore.loadFacts()?.friendlyNameZh ?? "小电拼"
    }

    static var customDeviceName: String? {
        get { defaults.string(forKey: Key.deviceName).flatMap { $0.isEmpty ? nil : $0 } }
        set { defaults.set(newValue, forKey: Key.deviceName) }
    }

    static var lastStrategy: ChargingStrategy? {
        get { defaults.object(forKey: Key.lastStrategy).flatMap { ($0 as? Int).flatMap(ChargingStrategy.init(rawValue:)) } }
        set { defaults.set(newValue?.rawValue, forKey: Key.lastStrategy) }
    }

    /// Clears everything stored for the current device (used when switching devices).
    static func resetDeviceData() {
        for key in [Key.snapshot, Key.facts, Key.lastStrategy] { defaults.removeObject(forKey: key) }
    }
}

enum SnapshotStore {
    static func load() -> ChargerSnapshot? {
        guard let data = AppConfig.defaults.data(forKey: AppConfig.Key.snapshot) else { return nil }
        return try? JSONDecoder().decode(ChargerSnapshot.self, from: data)
    }

    static func save(_ snapshot: ChargerSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        AppConfig.defaults.set(data, forKey: AppConfig.Key.snapshot)
    }

    static func loadFacts() -> MachineFacts? {
        guard let data = AppConfig.defaults.data(forKey: AppConfig.Key.facts) else { return nil }
        return try? JSONDecoder().decode(MachineFacts.self, from: data)
    }

    static func saveFacts(_ facts: MachineFacts) {
        guard let data = try? JSONEncoder().encode(facts) else { return }
        AppConfig.defaults.set(data, forKey: AppConfig.Key.facts)
    }

    /// Appends a total-power sample, keeping roughly the last 2 hours at ≥30 s spacing.
    static func appendingHistory(_ history: [PowerPoint], watts: Double, at date: Date) -> [PowerPoint] {
        var result = history.filter { date.timeIntervalSince($0.date) < 2 * 3600 }
        if let last = result.last, date.timeIntervalSince(last.date) < 30 {
            result[result.count - 1] = PowerPoint(date: last.date, watts: max(last.watts, watts))
        } else {
            result.append(PowerPoint(date: date, watts: watts))
        }
        return Array(result.suffix(240))
    }
}

/// Typed wrapper around the CANDYSIGN ionbridge MCP tools.
final class ChargerAPI: @unchecked Sendable {
    let client: MCPClient

    init(url: URL) {
        client = MCPClient(sseURL: url)
    }

    private static let lock = NSLock()
    private static var cached: ChargerAPI?

    /// Process-wide instance bound to the currently configured server URL.
    static func current() throws -> ChargerAPI {
        lock.lock()
        defer { lock.unlock() }
        guard let url = AppConfig.serverURL else {
            cached?.client.close()
            cached = nil
            throw MCPError.notConfigured
        }
        if let cached, cached.client.sseURL == url { return cached }
        cached?.client.close()
        let api = ChargerAPI(url: url)
        cached = api
        return api
    }

    private func decode<T: Decodable>(_ type: T.Type, _ tool: String, arguments: [String: Any] = [:], timeout: TimeInterval = 25) async throws -> T {
        let data = try await client.callTool(tool, arguments: arguments, timeout: timeout)
        do {
            return try JSONDecoder.snakeCase.decode(T.self, from: data)
        } catch {
            let text = String(data: data, encoding: .utf8) ?? ""
            if !text.hasPrefix("{") && !text.isEmpty { throw MCPError.tool(text) }
            throw MCPError.decoding(tool)
        }
    }

    private func perform(_ tool: String, arguments: [String: Any] = [:]) async throws {
        _ = try await client.callTool(tool, arguments: arguments, timeout: 30, retry: true)
    }

    // MARK: Reads

    func machineFacts() async throws -> MachineFacts { try await decode(MachineFacts.self, "get_machine_facts") }
    func deviceInfo() async throws -> DeviceInfo { try await decode(DeviceInfo.self, "get_device_info") }
    func portDetails() async throws -> [PortDetail] { try await decode(PortDetailsResponse.self, "get_port_details").ports }
    func chargingStatus() async throws -> ChargingStatus { try await decode(ChargingStatus.self, "get_charging_status") }
    func temperatureMode() async throws -> TemperatureModeResponse { try await decode(TemperatureModeResponse.self, "get_temperature_mode") }
    func displayConfig() async throws -> DisplayConfig { try await decode(DisplayConfig.self, "get_display_config") }
    func pdStatus() async throws -> [PDStatus] { try await decode(PDStatusResponse.self, "get_port_pd_status", timeout: 40).ports }
    func portStats(port: Int) async throws -> PortStatsResponse {
        try await decode(PortStatsResponse.self, "get_port_stats", arguments: ["port": port], timeout: 60)
    }

    // MARK: Controls

    func setStrategy(_ strategy: ChargingStrategy) async throws {
        if strategy == .usbA {
            try await perform("set_usba_charging_mode")
        } else {
            try await perform("set_charging_strategy", arguments: ["strategy": strategy.rawValue])
        }
        AppConfig.lastStrategy = strategy
    }

    func setTemperatureMode(_ mode: TemperatureMode) async throws {
        try await perform("set_temperature_mode", arguments: ["mode": mode.rawValue])
    }

    func setPorts(_ ports: [Int], on: Bool) async throws {
        try await perform(on ? "turn_on_port" : "turn_off_port", arguments: ["ports": ports])
    }

    func setPowerAllocation(_ watts: [Int]) async throws {
        try await perform("set_port_power_allocation", arguments: ["power_allocation": watts])
    }

    func setDisplayLevel(_ level: DisplayLevel) async throws {
        try await perform("set_display_intensity", arguments: ["level": level.rawValue])
    }

    func setStatusDisplayMode(_ mode: StatusDisplayMode) async throws {
        try await perform("set_status_display_mode", arguments: ["mode": mode.rawValue])
    }

    func setIdleDisplay(_ display: IdleDisplay) async throws {
        try await perform("set_idle_display", arguments: ["idle_display": display.rawValue])
    }

    func setHourlyChime(_ enabled: Bool) async throws {
        try await perform("set_hourly_chime", arguments: ["enabled": enabled])
    }

    // MARK: Snapshot

    static func makeSnapshot(facts: MachineFacts, details: [PortDetail], status: ChargingStatus?, temperatureMode: Int?, previous: ChargerSnapshot?, date: Date = Date()) -> ChargerSnapshot {
        let ports = facts.ports.sorted { $0.index < $1.index }.map { port -> PortSnapshot in
            let detail = details.first { $0.port == port.index }
            let enabled = status?.isOn(port.index) ?? previous?.ports.first { $0.index == port.index }?.enabled ?? true
            return PortSnapshot(
                index: port.index,
                name: port.name,
                connector: port.connectorType ?? (port.name.hasPrefix("A") ? "A" : "C"),
                maxPower: port.power,
                enabled: enabled,
                power: enabled ? (detail?.power ?? 0) : 0,
                voltage: detail?.voltage ?? 0,
                current: detail?.current ?? 0,
                protocolName: detail?.fcProtocol,
                deviceName: detail?.deviceName,
                temperature: detail?.dieTemperature
            )
        }
        var snapshot = ChargerSnapshot(
            deviceName: AppConfig.deviceName,
            modelName: facts.friendlyNameZh ?? facts.friendlyNameEn ?? "小电拼",
            maxPower: facts.maxPowerBudget,
            ports: ports,
            temperatureMode: temperatureMode ?? previous?.temperatureMode,
            fetchedAt: date,
            history: previous?.history ?? []
        )
        snapshot.history = SnapshotStore.appendingHistory(snapshot.history, watts: snapshot.totalPower, at: date)
        return snapshot
    }

    /// Fetches a fresh snapshot (used by the widget and App Intents) and persists it.
    func fetchSnapshot() async throws -> ChargerSnapshot {
        let facts: MachineFacts
        if let cachedFacts = SnapshotStore.loadFacts() {
            facts = cachedFacts
        } else {
            facts = (try? await machineFacts()) ?? .fallback
            SnapshotStore.saveFacts(facts)
        }
        async let detailsTask = portDetails()
        async let statusTask = chargingStatus()
        async let temperatureTask = temperatureMode()
        let details = try await detailsTask
        let status = try? await statusTask
        let temperature = try? await temperatureTask
        let snapshot = Self.makeSnapshot(facts: facts, details: details, status: status, temperatureMode: temperature?.mode, previous: SnapshotStore.load())
        SnapshotStore.save(snapshot)
        return snapshot
    }
}
