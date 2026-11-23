import Foundation
import WidgetKit

/// One place that answers "what's the charger doing?" for the app, the widgets and
/// App Intents, in either live mode (MCP) or demo mode (sample data, no network).
enum ChargerSource {
    static let demoKey = "demoMode.v1"

    static var isDemo: Bool {
        get { AppConfig.defaults.bool(forKey: demoKey) }
        set { AppConfig.defaults.set(newValue, forKey: demoKey) }
    }

    static var isConfigured: Bool { isDemo || AppConfig.serverURL != nil }

    /// Fetches a fresh snapshot (or the evolving demo snapshot) and stores it for the widgets.
    static func fetch() async throws -> ChargerSnapshot {
        if isDemo {
            let snapshot = Demo.tick(SnapshotStore.load() ?? Demo.snapshot())
            SnapshotStore.save(snapshot)
            return snapshot
        }
        let api = try ChargerAPI.current()
        return try await withTimeout(seconds: 20) { try await api.fetchSnapshot() }
    }

    static func setPort(_ index: Int, on: Bool) async throws {
        if !isDemo {
            try await ChargerAPI.current().setPorts([index], on: on)
        }
        if var snapshot = SnapshotStore.load(), let i = snapshot.ports.firstIndex(where: { $0.index == index }) {
            snapshot.ports[i].enabled = on
            if !on { snapshot.ports[i].power = 0 }
            if on, isDemo { snapshot.ports[i].power = Demo.basePower[index] ?? 0 }
            SnapshotStore.save(snapshot)
        }
    }

    static func setStrategy(_ strategy: ChargingStrategy) async throws {
        if isDemo { AppConfig.lastStrategy = strategy; return }
        try await ChargerAPI.current().setStrategy(strategy)
    }

    static func setTemperatureMode(_ mode: TemperatureMode) async throws {
        if !isDemo { try await ChargerAPI.current().setTemperatureMode(mode) }
        if var snapshot = SnapshotStore.load() {
            snapshot.temperatureMode = mode.rawValue
            SnapshotStore.save(snapshot)
        }
    }

    static func withTimeout<T: Sendable>(seconds: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw MCPError.timeout
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }
}

/// Sample data for App Review, screenshots and anyone without a charger.
enum Demo {
    static let basePower: [Int: Double] = [1: 4.8, 2: 61.4, 3: 18.2, 4: 0, 5: 6.1]

    static func snapshot(date: Date = Date()) -> ChargerSnapshot {
        let ports = [
            PortSnapshot(index: 1, name: "A", connector: "A", maxPower: 60, enabled: true, power: 4.8, voltage: 5.0, current: 0.96, protocolName: "Apple 2.4A", deviceName: "AirPods Pro", temperature: "cool"),
            PortSnapshot(index: 2, name: "C1", connector: "C", maxPower: 140, enabled: true, power: 61.4, voltage: 20.0, current: 3.07, protocolName: "PD Fixed", deviceName: "MacBook Pro", temperature: "moderate"),
            PortSnapshot(index: 3, name: "C2", connector: "C", maxPower: 140, enabled: true, power: 18.2, voltage: 9.0, current: 2.02, protocolName: "PD PPS", deviceName: "iPhone", temperature: "cool"),
            PortSnapshot(index: 4, name: "C3", connector: "C", maxPower: 140, enabled: false, power: 0, voltage: 0, current: 0, protocolName: nil, deviceName: nil, temperature: "cool"),
            PortSnapshot(index: 5, name: "C4", connector: "C", maxPower: 140, enabled: true, power: 6.1, voltage: 5.1, current: 1.2, protocolName: "PD Fixed", deviceName: "Apple Watch", temperature: "cool"),
        ]
        let history = (0..<90).map { i -> PowerPoint in
            let t = Double(i)
            return PowerPoint(date: date.addingTimeInterval((t - 90) * 60), watts: 84 + 12 * sin(t / 9) + 4 * sin(t / 2.7) + 6 * t / 90)
        }
        return ChargerSnapshot(deviceName: String(localized: "Desk Charger"), modelName: "CoCan Mirror", maxPower: 160,
                               ports: ports, temperatureMode: 0, fetchedAt: date, history: history)
    }

    /// Nudges the readings a little so demo mode feels alive.
    static func tick(_ snapshot: ChargerSnapshot, date: Date = Date()) -> ChargerSnapshot {
        var next = snapshot
        let phase = date.timeIntervalSince1970 / 20
        for i in next.ports.indices where next.ports[i].enabled {
            let base = basePower[next.ports[i].index] ?? 0
            guard base > 0 else { continue }
            let wobble = 1 + 0.08 * sin(phase + Double(i) * 1.7)
            next.ports[i].power = (base * wobble * 10).rounded() / 10
            if next.ports[i].voltage > 0 { next.ports[i].current = next.ports[i].power / next.ports[i].voltage }
        }
        next.fetchedAt = date
        // After a long gap the 2-hour window empties out; refill it so the chart stays readable.
        let recent = next.history.filter { date.timeIntervalSince($0.date) < 2 * 3600 }
        if recent.count < 20 { next.history = Demo.snapshot(date: date).history }
        next.history = SnapshotStore.appendingHistory(next.history, watts: next.totalPower, at: date)
        return next
    }
}

/// Timeline entry shared by the iOS and watchOS widgets.
struct ChargerEntry: TimelineEntry {
    enum State { case live, stale, needsSetup }
    var date: Date
    var snapshot: ChargerSnapshot
    var state: State
    var isDemo = false

    static let placeholder = ChargerEntry(date: .now, snapshot: Demo.snapshot(), state: .live)

    static func load() async -> ChargerEntry {
        guard ChargerSource.isConfigured else {
            return ChargerEntry(date: .now, snapshot: Demo.snapshot(), state: .needsSetup)
        }
        do {
            let snapshot = try await ChargerSource.fetch()
            return ChargerEntry(date: .now, snapshot: snapshot, state: .live, isDemo: ChargerSource.isDemo)
        } catch {
            return ChargerEntry(date: .now, snapshot: SnapshotStore.load() ?? Demo.snapshot(), state: .stale)
        }
    }
}
