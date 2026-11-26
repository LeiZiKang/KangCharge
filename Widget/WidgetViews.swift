import WidgetKit
import SwiftUI
import AppIntents
import KangChargeCore
import KangChargeUI

struct ChargerEntry: TimelineEntry {
    var date: Date
    var snapshot: ChargerSnapshot
    var energySummary: EnergySummary
    var isStale: Bool
    var errorMessage: String?
    var needsSetup = false
}

// MARK: - Live Power Widget Views

struct ChargerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ChargerEntry

    var body: some View {
        Group {
            if entry.needsSetup {
                WidgetSetupPrompt()
            } else {
                switch family {
                case .systemSmall: SmallPowerWidget(entry: entry)
                case .systemMedium: MediumPowerWidget(entry: entry)
                default: LargePowerWidget(entry: entry)
                }
            }
        }
        .opacity(entry.isStale && !entry.needsSetup ? 0.65 : 1)
        .containerBackground(for: .widget) {
            WidgetSurfaceBackground()
        }
    }
}

struct WidgetSurfaceBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        KCStyle.canvasBackground(for: colorScheme)
            .overlay(alignment: .topTrailing) {
                RadialGradient(
                    colors: [KCStyle.accent.opacity(colorScheme == .dark ? 0.08 : 0.05), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 210
                )
            }
    }
}

struct SmallPowerWidget: View {
    var entry: ChargerEntry
    private var snapshot: ChargerSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(KCStyle.accent)
                    .widgetAccentable()
                Text(snapshot.deviceName)
                    .lineLimit(1)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(KCFormat.watts(snapshot.totalPower))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .widgetAccentable()
                Text("W")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("of \(KCFormat.watts(snapshot.maxPower)) W")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            KCLoadBar(
                fraction: snapshot.maxPower > 0 ? snapshot.totalPower / snapshot.maxPower : 0,
                color: KCStyle.accent,
                height: 5
            )

            Spacer(minLength: 2)

            HStack(spacing: 4) {
                ForEach(snapshot.ports) { port in
                    Capsule()
                        .fill(port.isCharging ? KCStyle.charging : (port.enabled ? Color.primary.opacity(0.18) : Color.primary.opacity(0.08)))
                        .frame(height: 3.5)
                }
            }

            HStack {
                Text(Locale.kcPrefersChinese ? "\(snapshot.chargingCount) 口充电" : "\(snapshot.chargingCount) charging")
                Spacer(minLength: 2)
                if entry.isStale {
                    Text(snapshot.fetchedAt, style: .relative)
                } else {
                    Text(Locale.kcPrefersChinese ? "在线" : "Live")
                        .foregroundStyle(KCStyle.charging)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}

struct MediumPowerWidget: View {
    var entry: ChargerEntry
    private var snapshot: ChargerSnapshot { entry.snapshot }

    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(KCStyle.accent)
                        .widgetAccentable()
                    Text(snapshot.deviceName)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(KCFormat.watts(snapshot.totalPower))
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .widgetAccentable()
                    Text("W")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("of \(KCFormat.watts(snapshot.maxPower)) W")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                KCLoadBar(
                    fraction: snapshot.maxPower > 0 ? snapshot.totalPower / snapshot.maxPower : 0,
                    color: KCStyle.accent,
                    height: 5
                )

                HStack(spacing: 5) {
                    Circle()
                        .fill(entry.isStale ? Color.secondary : KCStyle.charging)
                        .frame(width: 5, height: 5)
                    Text(Locale.kcPrefersChinese ? "\(snapshot.chargingCount) 口充电" : "\(snapshot.chargingCount) charging")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(snapshot.ports) { port in
                    HStack(spacing: 6) {
                        Text(KCFormat.portBadgeName(port))
                            .font(.caption2.weight(.semibold))
                            .frame(width: 20, alignment: .leading)
                            .foregroundStyle(port.enabled ? .primary : .secondary)
                        KCLoadBar(
                            fraction: port.enabled && port.maxPower > 0 ? port.power / port.maxPower : 0,
                            color: KCStyle.portTint(for: port),
                            height: 4
                        )
                        Text(port.enabled ? "\(KCFormat.watts(port.power)) W" : (Locale.kcPrefersChinese ? "关" : "Off"))
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(port.isCharging ? .primary : .secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct LargePowerWidget: View {
    var entry: ChargerEntry
    private var snapshot: ChargerSnapshot { entry.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(KCStyle.accent)
                        .widgetAccentable()
                    Text(snapshot.deviceName)
                        .lineLimit(1)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                if entry.isStale {
                    Text(snapshot.fetchedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(Locale.kcPrefersChinese ? "在线" : "Live")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(KCStyle.charging)
                }

                Button(intent: RefreshChargerIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(KCFormat.watts(snapshot.totalPower))
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .widgetAccentable()
                        Text("W")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text(Locale.kcPrefersChinese ? "\(snapshot.chargingCount) 口充电 · 今日 \(KCFormat.energy(wattHours: entry.energySummary.todayWattHours))" : "\(snapshot.chargingCount) charging · Today \(KCFormat.energy(wattHours: entry.energySummary.todayWattHours))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 4)
                WidgetSparkline(points: snapshot.history.map(\.watts), color: KCStyle.accent)
                    .frame(width: 120, height: 38)
            }

            Divider()

            VStack(spacing: 0) {
                ForEach(snapshot.ports) { port in
                    HStack(spacing: 8) {
                        Text(KCFormat.portBadgeName(port))
                            .font(.caption2.weight(.semibold))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(port.isCharging ? Color.white : KCStyle.portTint(for: port))
                            .background {
                                Circle().fill(port.isCharging ? KCStyle.charging : Color.primary.opacity(0.06))
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(port.deviceName ?? (port.enabled ? (KCFormat.protocolTag(port.protocolName) ?? (Locale.kcPrefersChinese ? "待机" : "Idle")) : (Locale.kcPrefersChinese ? "已关闭" : "Off")))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(port.enabled ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Text(port.enabled ? "\(KCFormat.watts(port.power)) W" : "—")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(port.isCharging ? .primary : .secondary)

                        Button(intent: SetPortPowerIntent(portIndex: port.index, turnOn: !port.enabled)) {
                            WidgetSwitchPill(isOn: port.enabled)
                        }
                        .buttonStyle(.plain)
                        .widgetAccentable()
                    }
                    .padding(.vertical, 5.5)

                    if port.index != snapshot.ports.last?.index {
                        Divider().padding(.leading, 32)
                    }
                }
            }
        }
    }
}

struct WidgetSwitchPill: View {
    var isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? KCStyle.charging : Color.primary.opacity(0.16))
            Circle()
                .fill(Color.white)
                .padding(2)
                .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
        }
        .frame(width: 30, height: 18)
    }
}

struct WidgetSparkline: View {
    var points: [Double]
    var color: Color

    var body: some View {
        GeometryReader { geo in
            if points.count >= 2 {
                let minV = min(points.min() ?? 0, 0)
                let maxV = max(points.max() ?? 1, minV + 10)
                let span = maxV - minV
                let coords: [CGPoint] = points.enumerated().map { idx, val in
                    let x = geo.size.width * CGFloat(idx) / CGFloat(points.count - 1)
                    let y = geo.size.height * (1 - CGFloat((val - minV) / span))
                    return CGPoint(x: x, y: y)
                }
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        for pt in coords { p.addLine(to: pt) }
                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0.0)], startPoint: .top, endPoint: .bottom))

                    Path { p in
                        p.move(to: coords[0])
                        for pt in coords.dropFirst() { p.addLine(to: pt) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}

// MARK: - Daily Energy Heatmap Widget (GitHub Contribution Style)

struct EnergyHeatmapWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ChargerEntry
    var overrideFamily: WidgetFamily? = nil

    private var effectiveFamily: WidgetFamily { overrideFamily ?? family }

    var body: some View {
        Group {
            if entry.needsSetup {
                WidgetSetupPrompt()
            } else if effectiveFamily == .systemLarge {
                largeHeatmap
            } else {
                mediumHeatmap
            }
        }
        .containerBackground(for: .widget) {
            WidgetSurfaceBackground()
        }
    }

    private var mediumHeatmap: some View {
        let trimmed = EnergySummary(days: Array(entry.energySummary.days.suffix(26 * 7)), todayKey: entry.energySummary.days.last?.dayKey ?? "")
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(Locale.kcPrefersChinese ? "每日用电" : "Daily Energy", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(KCFormat.energy(wattHours: trimmed.todayWattHours))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(KCStyle.charging)
            }

            EnergyHeatmapView(
                summary: trimmed,
                tint: KCStyle.charging,
                cellSpacing: 2.5,
                cornerRadius: 2.5,
                maxCellSize: 10.5,
                interactive: false,
                showLegend: false,
                showHeader: false,
                showAxisLabels: false
            )

            HStack {
                Text(Locale.kcPrefersChinese ? "近 7 天 \(KCFormat.energy(wattHours: trimmed.last7DaysWattHours))" : "7d \(KCFormat.energy(wattHours: trimmed.last7DaysWattHours))")
                Spacer()
                Text(Locale.kcPrefersChinese ? "合计 \(KCFormat.energy(wattHours: trimmed.totalWattHours))" : "Total \(KCFormat.energy(wattHours: trimmed.totalWattHours))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }

    private var largeHeatmap: some View {
        let trimmed = EnergySummary(days: Array(entry.energySummary.days.suffix(20 * 7)), todayKey: entry.energySummary.days.last?.dayKey ?? "")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Locale.kcPrefersChinese ? "每日用电量" : "Daily Energy")
                        .font(.headline)
                    Text(entry.snapshot.deviceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(KCFormat.energy(wattHours: trimmed.todayWattHours))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(KCStyle.charging)
                    Text(Locale.kcPrefersChinese ? "今日" : "Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            EnergyHeatmapView(
                summary: trimmed,
                tint: KCStyle.charging,
                cellSpacing: 3,
                cornerRadius: 3,
                maxCellSize: 14,
                interactive: false,
                showLegend: true,
                showHeader: false,
                showAxisLabels: false
            )

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Locale.kcPrefersChinese ? "近 7 天" : "Last 7 Days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(KCFormat.energy(wattHours: trimmed.last7DaysWattHours))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(Locale.kcPrefersChinese ? "单日峰值" : "Peak Day")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(KCFormat.energy(wattHours: trimmed.peakWattHours))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Locale.kcPrefersChinese ? "连续记录" : "Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Locale.kcPrefersChinese ? "\(trimmed.currentStreak) 天" : "\(trimmed.currentStreak) days")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }
}

struct WidgetSetupPrompt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "bolt.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("SugarWatt")
                .font(.callout.weight(.semibold))
            Text(Locale.kcPrefersChinese ? "打开 SugarWatt 粘贴 MCP 地址完成连接。" : "Open SugarWatt to connect your charger.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
