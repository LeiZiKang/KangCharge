import WidgetKit
import SwiftUI
import AppIntents

struct ChargerEntry: TimelineEntry {
    var date: Date
    var snapshot: ChargerSnapshot
    var isStale: Bool
    var errorMessage: String?
    var needsSetup = false
}

// MARK: - Views

struct ChargerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: ChargerEntry

    var body: some View {
        Group {
            if entry.needsSetup {
                WidgetSetupPrompt()
            } else {
                switch family {
                case .systemSmall: SmallWidget(entry: entry)
                case .systemMedium: MediumWidget(entry: entry)
                default: LargeWidget(entry: entry)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .containerBackground(for: .widget) {
            WidgetBackground()
        }
    }
}

struct WidgetBackground: View {
    var body: some View { Theme.cream }
}

struct WidgetHeader: View {
    var entry: ChargerEntry
    var showRefresh = false
    var showTime = true
    var showBadge = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(entry.snapshot.deviceName)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(1)
            if showBadge {
            Text(entry.isStale ? "离线" : "在线")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(entry.isStale ? Theme.gray : Theme.green))
            }
            Spacer(minLength: 2)
            if showTime {
                Text(entry.snapshot.fetchedAt, style: .time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.gray)
            }
            if showRefresh {
                Button(intent: RefreshChargerIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.orange)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BigPower: View {
    var watts: Double
    var size: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("实时充电功率")
                .font(.system(size: size * 0.32, weight: .semibold))
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(Format.watts(watts)).font(.system(size: size, weight: .heavy)).monospacedDigit()
                Text("W").font(.system(size: size * 0.68, weight: .heavy))
            }
            .foregroundStyle(Theme.orange)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetAccentable()
        }
    }
}

struct SmallWidget: View {
    var entry: ChargerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(entry: entry, showTime: false)
            Text("CoCan Mirror")
                .font(.system(size: 9, weight: .heavy).italic())
                .foregroundStyle(Theme.orange)
            Spacer(minLength: 4)
            BigPower(watts: entry.snapshot.totalPower, size: 30)
            Spacer(minLength: 6)
            HStack(spacing: 4) {
                ForEach(entry.snapshot.ports) { port in
                    VStack(spacing: 3) {
                        Text(port.connector == "A" ? "A" : port.name)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(port.enabled ? Theme.ink : Theme.gray)
                        Capsule()
                            .fill(port.isCharging ? Theme.orange : (port.enabled ? Theme.orange.opacity(0.3) : Color(hex: 0xE1E1E1)))
                            .frame(height: 4)
                    }
                }
            }
        }
    }
}

struct MediumWidget: View {
    var entry: ChargerEntry

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(entry: entry, showTime: false, showBadge: false)
                Text("CoCan Mirror")
                    .font(.system(size: 9, weight: .heavy).italic())
                    .foregroundStyle(Theme.orange)
                Spacer(minLength: 2)
                BigPower(watts: entry.snapshot.totalPower, size: 28)
                Text("\(entry.snapshot.chargingCount) 口充电 · 已用 \(usedPercent)%")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.gray)
            }
            .frame(width: 112, alignment: .leading)

            CableDiagram(ports: entry.snapshot.ports, chipScale: 0.62, chargerScale: 1.0, cableWidth: 3)
        }
    }

    private var usedPercent: Int {
        entry.snapshot.maxPower > 0 ? Int((entry.snapshot.totalPower / entry.snapshot.maxPower * 100).rounded()) : 0
    }
}

struct LargeWidget: View {
    var entry: ChargerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(entry: entry, showRefresh: true)

            ZStack(alignment: .bottomLeading) {
                CableDiagram(ports: entry.snapshot.ports, chipScale: 0.78, chargerScale: 1.25, cableWidth: 4)
                BigPower(watts: entry.snapshot.totalPower, size: 30)
            }
            .frame(height: 168)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))

            VStack(spacing: 0) {
                ForEach(entry.snapshot.ports) { port in
                    WidgetPortRow(port: port)
                    if port.index != entry.snapshot.ports.last?.index {
                        Rectangle().fill(Theme.line).frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        }
    }
}

struct WidgetPortRow: View {
    var port: PortSnapshot

    var body: some View {
        HStack(spacing: 8) {
            Text(port.connector == "A" ? "A" : port.name)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(port.enabled ? Theme.orange : Theme.gray)
                .frame(width: 22, alignment: .leading)
            Text(port.deviceName ?? (port.enabled ? (port.protocolName ?? "空闲") : "已关闭"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(port.enabled ? Theme.ink : Theme.gray)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(port.enabled ? "\(Format.watts(port.power))W" : "OFF")
                .font(.system(size: 12, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(port.isCharging ? Theme.orange : (port.enabled ? Theme.ink : Theme.gray))
            Button(intent: SetPortPowerIntent(portIndex: port.index, turnOn: !port.enabled)) {
                Image(systemName: "power")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(port.enabled ? Color.white : Theme.gray)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(port.enabled ? Theme.orange : Color(hex: 0xEDEDED)))
            }
            .buttonStyle(.plain)
            .widgetAccentable()
        }
        .padding(.vertical, 4.5)
    }
}

struct WidgetSetupPrompt: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "bolt.slash.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.orange)
            Spacer(minLength: 0)
            Text("还没有连接小电拼").font(.system(size: 13, weight: .heavy))
            Text("打开 Kang Charge，粘贴 MCP 地址完成设置。")
                .font(.system(size: 11))
                .foregroundStyle(Theme.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
