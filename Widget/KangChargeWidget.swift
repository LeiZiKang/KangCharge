import WidgetKit
import SwiftUI
import AppIntents

struct ChargerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargerEntry {
        ChargerEntry(date: .now, snapshot: .preview, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargerEntry) -> Void) {
        if context.isPreview {
            completion(ChargerEntry(date: .now, snapshot: SnapshotStore.load() ?? .preview, isStale: false))
            return
        }
        Task {
            completion(await loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargerEntry>) -> Void) {
        Task {
            let entry = await loadEntry()
            let next = Calendar.current.date(byAdding: .minute, value: entry.errorMessage == nil ? 5 : 2, to: .now) ?? .now.addingTimeInterval(300)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func loadEntry() async -> ChargerEntry {
        do {
            let api = try ChargerAPI.current()
            let snapshot = try await withTimeout(seconds: 20) { try await api.fetchSnapshot() }
            return ChargerEntry(date: .now, snapshot: snapshot, isStale: false)
        } catch MCPError.notConfigured {
            return ChargerEntry(date: .now, snapshot: .preview, isStale: true, needsSetup: true)
        } catch {
            let cached = SnapshotStore.load()
            return ChargerEntry(date: .now, snapshot: cached ?? .preview, isStale: true, errorMessage: cached == nil ? "暂无数据" : error.localizedDescription)
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
    }
}

struct KangChargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: ChargerProvider()) { entry in
            ChargerWidgetView(entry: entry)
        }
        .configurationDisplayName("Kang Charge")
        .description("小电拼 Mirror 的实时功率与端口状态，大尺寸可直接开关端口。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemLarge) {
    KangChargeWidget()
} timeline: {
    ChargerEntry(date: .now, snapshot: .preview, isStale: false)
}
