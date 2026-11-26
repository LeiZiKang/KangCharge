import WidgetKit
import SwiftUI
import AppIntents
import KangChargeCore

struct ChargerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargerEntry {
        ChargerEntry(
            date: .now,
            snapshot: KCDemo.snapshot(),
            energySummary: KCDemo.energySummary(weeks: 26),
            isStale: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargerEntry) -> Void) {
        if context.isPreview {
            completion(ChargerEntry(
                date: .now,
                snapshot: SnapshotStore.load() ?? KCDemo.snapshot(),
                energySummary: currentEnergySummary(),
                isStale: false
            ))
            return
        }
        Task { completion(await loadEntry()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargerEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Calendar.current.date(byAdding: .minute, value: entry.errorMessage == nil ? 5 : 2, to: .now)
                ?? .now.addingTimeInterval(300)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func currentEnergySummary() -> EnergySummary {
        let live = EnergyLedger.shared.summary(weeks: 26)
        return live.activeDays > 0 ? live : KCDemo.energySummary(weeks: 26)
    }

    private func loadEntry() async -> ChargerEntry {
        EnergyLedger.shared.pullFromCloud()
        do {
            let api = try ChargerAPI.current()
            let snapshot = try await withTimeout(seconds: 20) { try await api.fetchSnapshot() }
            return ChargerEntry(
                date: .now,
                snapshot: snapshot,
                energySummary: EnergyLedger.shared.summary(weeks: 26),
                isStale: false
            )
        } catch MCPError.notConfigured {
            return ChargerEntry(
                date: .now,
                snapshot: KCDemo.snapshot(),
                energySummary: KCDemo.energySummary(weeks: 26),
                isStale: true,
                needsSetup: true
            )
        } catch {
            let cached = SnapshotStore.load()
            return ChargerEntry(
                date: .now,
                snapshot: cached ?? KCDemo.snapshot(),
                energySummary: EnergyLedger.shared.summary(weeks: 26),
                isStale: true,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func withTimeout<T: Sendable>(seconds: Double, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
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

@main
struct KangChargeWidgetBundle: WidgetBundle {
    var body: some Widget {
        KangChargeWidget()
        KangChargeHeatmapWidget()
    }
}

struct KangChargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: ChargerProvider()) { entry in
            ChargerWidgetView(entry: entry)
        }
        .configurationDisplayName("Charger Power")
        .description("Live wattage, load trend, and interactive port switches.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct KangChargeHeatmapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.heatmapWidgetKind, provider: ChargerProvider()) { entry in
            EnergyHeatmapWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Energy")
        .description("GitHub-style daily charging energy heatmap.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
