import SwiftUI
import WidgetKit

import AppIntents

struct PowerWidgetView: View {
    let entry: ChargerEntry
    @Environment(\.widgetFamily) private var family
    private var snapshot: ChargerSnapshot { entry.snapshot }
    private var stale: Bool { entry.state == .stale }
    private var topPort: PortSnapshot? { snapshot.ports.filter(\.isCharging).max(by: { $0.power < $1.power }) }
    var body: some View {
        Group {
            if entry.state == .needsSetup {
                VStack(spacing: 6) {
                    Image(systemName: "bolt.fill").widgetAccentable()
                    Text("Open Kang Charge to connect").font(.caption)
                }
            } else {
                switch family {
                case .accessoryCircular: circular
                case .accessoryRectangular: rectangular
                case .accessoryInline:
                    if stale {
                        Text("\(Int(snapshot.totalPower.rounded())) W · \(snapshot.chargingCount) charging · \(snapshot.fetchedAt, style: .relative)")
                    } else {
                        Text("\(Int(snapshot.totalPower.rounded())) W · \(snapshot.chargingCount) charging")
                    }
                case .systemMedium: medium
                case .systemLarge: large
                default: small
                }
            }
        }
        .opacity(stale ? 0.6 : 1)
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
                .overlay(alignment: .topTrailing) {
                    RadialGradient(colors: [KC.accent.opacity(0.09), .clear], center: .topTrailing, startRadius: 0, endRadius: 220)
                }
        }
        .widgetURL(URL(string: "kangcharge://home"))
    }
    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill").foregroundStyle(KC.accent).widgetAccentable()
            Text(snapshot.deviceName).lineLimit(1)
        }.font(.caption).foregroundStyle(.secondary)
    }
    private var watts: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(Fmt.watts(snapshot.totalPower)).font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1).widgetAccentable()
            Text("W").font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    private var status: some View {
        Group {
            if stale { Text(snapshot.fetchedAt, style: .relative) }
            else { Text("Live").foregroundStyle(KC.charging) }
        }.font(.caption2).lineLimit(1)
    }
    private var sample: some View {
        Text("Sample").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            .padding(.horizontal, 4).padding(.vertical, 2).background(.quaternary, in: Capsule())
    }
    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Spacer(minLength: 0)
            watts
            Text("of \(Fmt.watts(snapshot.maxPower)) W").font(.caption2).foregroundStyle(.secondary)
            LoadBar(fraction: snapshot.totalPower / max(snapshot.maxPower, 1))
            Spacer(minLength: 0)
            HStack {
                Text("\(snapshot.chargingCount) charging").font(.caption2)
                Spacer(minLength: 4)
                status
            }
        }
    }
    private var medium: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                header
                watts
                Text("of \(Fmt.watts(snapshot.maxPower)) W").font(.caption2).foregroundStyle(.secondary)
                LoadBar(fraction: snapshot.totalPower / max(snapshot.maxPower, 1))
                HStack { status; if entry.isDemo { sample } }
                Text("\(snapshot.chargingCount) charging").font(.caption2).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 10) {
                ForEach(snapshot.ports) { port in
                    HStack(spacing: 6) {
                        Text(port.name).font(.caption2.bold()).frame(width: 22, alignment: .leading)
                        LoadBar(fraction: port.power / max(port.maxPower, 1), color: KC.tint(for: port), height: 4)
                        Group {
                            if port.enabled { Text("\(Fmt.watts(port.power)) W") }
                            else { Text("Off") }
                        }.font(.caption2).monospacedDigit().frame(width: 48, alignment: .trailing)
                    }.foregroundStyle(KC.tint(for: port))
                }
            }.frame(maxWidth: .infinity)
        }
    }
    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                header
                Spacer()
                if entry.isDemo { sample }
                status
                Button(intent: RefreshIntent()) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).foregroundStyle(KC.accent).accessibilityLabel("Refresh Charger")
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    watts
                    Text("\(snapshot.chargingCount) charging").font(.caption2).foregroundStyle(.secondary)
                }
                Sparkline(values: snapshot.history.suffix(60).map(\.watts))
                    .frame(height: 44).accessibilityLabel("Recent power history")
            }
            LoadBar(fraction: snapshot.totalPower / max(snapshot.maxPower, 1))
            ForEach(snapshot.ports) { port in
                HStack(spacing: 10) {
                    Text(port.name).font(.caption2.bold()).frame(width: 28, height: 28)
                        .background(KC.tint(for: port).opacity(0.14), in: Circle()).foregroundStyle(KC.tint(for: port)).widgetAccentable()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(port.deviceName ?? (port.enabled ? String(localized: "Idle") : String(localized: "Off"))).font(.caption).lineLimit(1)
                        if let tag = Fmt.protocolTag(port.protocolName), port.isCharging { Text(tag).font(.caption2).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 0)
                    Text("\(Fmt.watts(port.power)) W").font(.caption).monospacedDigit().foregroundStyle(KC.tint(for: port))
                    Button(intent: SetPortIntent(port: port.index, isOn: !port.enabled)) {
                        PortSwitch(isOn: port.enabled)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(port.enabled ? "Turn off \(port.name)" : "Turn on \(port.name)"))
                }.frame(maxHeight: .infinity)
            }
        }
    }
    private var circular: some View {
        Gauge(value: min(max(snapshot.totalPower, 0), max(snapshot.maxPower, 1)), in: 0...max(snapshot.maxPower, 1)) {
            if stale { Text(snapshot.fetchedAt, style: .relative).font(.caption2) }
            else { Image(systemName: "bolt.fill") }
        } currentValueLabel: {
            Text("\(Int(snapshot.totalPower.rounded()))").monospacedDigit()
        }.gaugeStyle(.accessoryCircular).widgetAccentable().accessibilityLabel("Charger Power")
    }
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("⚡︎ \(Fmt.watts(snapshot.totalPower)) W").font(.headline).widgetAccentable()
            if stale { Text(snapshot.fetchedAt, style: .relative).font(.caption) }
            else if let topPort {
                Text("\(snapshot.chargingCount) charging · \(topPort.name) \(Int(topPort.power.rounded())) W").font(.caption).lineLimit(1)
            } else { Text("\(snapshot.chargingCount) charging").font(.caption) }
        }
    }
}

/// Lightweight line + fill sparkline (Swift Charts renders unreliably inside widgets).
struct Sparkline: View {
    var values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let points = normalized(in: proxy.size)
            if points.count > 1 {
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: proxy.size.height))
                        points.forEach { path.addLine(to: $0) }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [KC.accent.opacity(0.25), KC.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(KC.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard values.count > 1, let lo = values.min(), let hi = values.max() else { return [] }
        let span = max(hi - lo, 1)
        return values.enumerated().map { i, v in
            CGPoint(x: size.width * Double(i) / Double(values.count - 1),
                    y: size.height * (1 - (v - lo) / span * 0.85) - 1)
        }
    }
}

/// Compact on/off pill. Drawn by hand because widget Toggles render as large labelled buttons.
struct PortSwitch: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? KC.charging : Color.secondary.opacity(0.25))
            Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
        }
        .frame(width: 38, height: 22)
        .widgetAccentable()
    }
}
