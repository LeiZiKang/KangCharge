import SwiftUI
import WidgetKit

struct PowerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargerEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (ChargerEntry) -> Void) {
        if context.isPreview {
            completion(ChargerEntry(date: .now, snapshot: SnapshotStore.load() ?? Demo.snapshot(), state: .live, isDemo: ChargerSource.isDemo))
        } else { Task { completion(await ChargerEntry.load()) } }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargerEntry>) -> Void) {
        Task {
            let entry = await ChargerEntry.load()
            completion(Timeline(entries: [entry], policy: .after(Date(timeIntervalSinceNow: entry.state == .stale ? 5 * 60 : 15 * 60))))
        }
    }
}
struct PowerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConfig.widgetKind, provider: PowerProvider()) { entry in
            PowerWidgetView(entry: entry)
        }
        .configurationDisplayName("Charger Power")
        .description("Live power and ports of your charger.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
@main
struct KangChargeWidgets: WidgetBundle {
    var body: some Widget { PowerWidget() }
}

#Preview(as: .systemSmall) { PowerWidget() } timeline: { ChargerEntry.placeholder }
#Preview(as: .systemMedium) { PowerWidget() } timeline: { ChargerEntry.placeholder }
#Preview(as: .systemLarge) { PowerWidget() } timeline: { ChargerEntry.placeholder }
#Preview(as: .accessoryCircular) { PowerWidget() } timeline: { ChargerEntry.placeholder }
#Preview(as: .accessoryRectangular) { PowerWidget() } timeline: { ChargerEntry.placeholder }
#Preview(as: .accessoryInline) { PowerWidget() } timeline: { ChargerEntry.placeholder }
