import SwiftUI
import WidgetKit

struct WatchChargerProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargerEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (ChargerEntry) -> Void) {
        if context.isPreview { completion(.placeholder) }
        else { Task { completion(await ChargerEntry.load()) } }
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargerEntry>) -> Void) {
        Task {
            let entry = await ChargerEntry.load()
            let stale = ChargerEntry(date: entry.date.addingTimeInterval(5 * 60), snapshot: entry.snapshot,
                                     state: entry.state == .needsSetup ? .needsSetup : .stale, isDemo: entry.isDemo)
            completion(Timeline(entries: [entry, stale], policy: .after(entry.date.addingTimeInterval(15 * 60))))
        }
    }
}

@main
struct KangChargeWatchWidgets: WidgetBundle {
    var body: some Widget { WatchPowerWidget() }
}

struct WatchPowerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KangChargeWatchPower", provider: WatchChargerProvider()) { entry in
            WatchPowerView(entry: entry).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Charger Power")
        .description("Power and charging ports at a glance.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct WatchPowerView: View {
    let entry: ChargerEntry
    @Environment(\.widgetFamily) private var family
    private var snapshot: ChargerSnapshot { entry.snapshot }
    private var topPort: PortSnapshot? { snapshot.ports.filter(\.isCharging).max { $0.power < $1.power } }
    private var watts: Int { Int(snapshot.totalPower.rounded()) }
    private var fraction: Double { min(max(snapshot.totalPower / max(snapshot.maxPower, 1), 0), 1) }

    var body: some View {
        Group {
            if entry.state == .needsSetup {
                Text("Open Kang Charge on your iPhone to connect.")
            } else {
                switch family {
                case .accessoryCircular:
                    Gauge(value: fraction) { Text("W") } currentValueLabel: { Text("\(watts)").monospacedDigit() }
                        .gaugeStyle(.accessoryCircular)
                case .accessoryCorner:
                    Text("\(watts) W").monospacedDigit()
                        .widgetLabel { Gauge(value: fraction) { Text("Charger Power") } }
                case .accessoryRectangular:
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(watts) W").font(.headline).monospacedDigit()
                        if let topPort {
                            Text("\(snapshot.chargingCount) charging · \(topPort.name) \(Int(topPort.power.rounded())) W")
                        } else { Text("\(snapshot.chargingCount) charging") }
                        if entry.state == .stale { Text("Updated \(snapshot.fetchedAt, style: .relative) ago").font(.caption2) }
                    }
                default:
                    Text("\(watts) W · \(snapshot.chargingCount) charging")
                }
            }
        }.widgetAccentable().opacity(entry.state == .stale ? 0.6 : 1)
    }
}
