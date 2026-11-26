import SwiftUI
import Charts
import KangChargeCore
import KangChargeUI

// MARK: - Apple Music-Style Track Row for Ports (No heavy colored blobs)

struct PortListRow: View {
    @EnvironmentObject private var store: ChargerStore
    @Environment(\.colorScheme) private var colorScheme
    var port: PortSnapshot
    var onSelect: () -> Void
    @State private var confirmOff = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    // Left icon tile: shows real USB-PD battery % ring when the connected device reports battery status
                    let batteryFraction = store.pd[port.index]?.batteryFraction
                    ZStack {
                        Circle()
                            .fill(KCStyle.surfaceTile(for: colorScheme).opacity(port.isCharging ? 1.0 : 0.65))
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 2)
                        if let batteryFraction, port.isCharging {
                            Circle()
                                .trim(from: 0, to: batteryFraction)
                                .stroke(
                                    KCStyle.charging,
                                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        Image(systemName: DeviceSymbol.systemName(for: port))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(port.isCharging ? .primary : .tertiary)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(port.deviceName ?? fallbackTitle)
                                .font(.body.weight(.medium))
                                .foregroundStyle(port.isCharging ? .primary : .secondary)
                                .lineLimit(1)
                            if port.deviceName != nil {
                                Text(KCFormat.portDisplayName(port))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                            }
                            if let batteryFraction, port.isCharging {
                                Text("\(Int((batteryFraction * 100).rounded()))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(KCStyle.charging)
                                    .monospacedDigit()
                            }
                        }

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if let tempLabel = PortTemperature.localizedLabel(port.temperature), port.isCharging {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(KCStyle.temperatureColor(port.temperature))
                                .frame(width: 5, height: 5)
                            Text(tempLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Style 2: Hardware LED 8-segment Power Pressure Meter + wattage / max capacity
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(port.isCharging ? "\(KCFormat.watts(port.power)) W" : "—")
                                .font(.body.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(port.isCharging ? .primary : .tertiary)
                            if port.isCharging, port.maxPower > 0 {
                                Text("/ \(Int(port.maxPower))W")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                        PowerPressureMeter(
                            watts: port.isCharging ? port.power : 0,
                            maxWatts: port.maxPower
                        )
                    }
                    .frame(width: 96, alignment: .trailing)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.quaternary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Show an honest switch when delivering power; show a clean Idle / Turn On control when unpowered
            if port.isCharging {
                KCSwitch(isOn: Binding(
                    get: { true },
                    set: { newValue in
                        if !newValue { confirmOff = true }
                    }
                ))
                .disabled(store.busy.contains("port-\(port.index)"))
                .accessibilityLabel(L("Cut power to \(KCFormat.portDisplayName(port))", "断开 \(KCFormat.portDisplayName(port)) 供电"))
            } else {
                Button {
                    store.setPort(port.index, on: true)
                } label: {
                    Text(hovering ? L("Wake", "通电") : L("Idle", "空闲"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(hovering ? .primary : .tertiary)
                        .frame(width: 36, height: 20)
                        .background(
                            Capsule().fill(hovering ? Color.primary.opacity(0.08) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.busy.contains("port-\(port.index)"))
                .help(L("Send turn-on command to \(KCFormat.portDisplayName(port))", "向 \(KCFormat.portDisplayName(port)) 发送通电指令"))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.045) : .clear)
        )
        .onHover { hovering = $0 }
        .confirmationDialog(
            L("Turn off \(KCFormat.portDisplayName(port))?", "关闭 \(KCFormat.portDisplayName(port)) 口？"),
            isPresented: $confirmOff
        ) {
            Button(L("Turn Off", "关闭端口"), role: .destructive) {
                store.setPort(port.index, on: false)
            }
            Button(L("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L(
                "\(port.deviceName ?? "The connected device") is drawing \(KCFormat.watts(port.power)) W and will lose power immediately.",
                "\(port.deviceName ?? "该端口设备")正在以 \(KCFormat.watts(port.power)) W 充电，关闭后将立即断电。"
            ))
        }
    }

    private var fallbackTitle: String {
        KCFormat.portDisplayName(port)
    }

    private var subtitle: String {
        guard port.isCharging else {
            return L("Idle · Up to \(Int(port.maxPower)) W", "空闲 · 最高 \(Int(port.maxPower)) W")
        }
        var parts: [String] = []
        if let tag = KCFormat.protocolTag(port.protocolName) { parts.append(tag) }
        if port.voltage > 0 { parts.append(KCFormat.volts(port.voltage)) }
        if port.current > 0 { parts.append(KCFormat.amps(port.current)) }
        if parts.isEmpty { parts.append(L("Ready · Up to \(Int(port.maxPower)) W", "就绪 · 最高 \(Int(port.maxPower)) W")) }
        return parts.joined(separator: " · ")
    }
}

/// Pure SwiftUI Apple-style switch that renders identically in live windows,
/// Xcode Previews, and offscreen ImageRenderer snapshots (no AppKit NSSwitch placeholder).
struct KCSwitch: View {
    @Binding var isOn: Bool
    var scale: CGFloat = 1.0
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let width: CGFloat = 32 * scale
        let height: CGFloat = 18 * scale
        let knob: CGFloat = 14 * scale

        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? KCStyle.charging : Color.primary.opacity(0.15))
            Circle()
                .fill(Color.white)
                .frame(width: knob, height: knob)
                .shadow(color: .black.opacity(0.20), radius: 1.5, y: 0.75)
                .padding(2 * scale)
        }
        .frame(width: width, height: height)
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(Capsule())
        .onTapGesture {
            guard isEnabled else { return }
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                isOn.toggle()
            }
        }
        .accessibilityElement()
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if isEnabled { isOn.toggle() } }
    }
}

/// Compact badge used in MenuBarPanel.
struct PortBadgeCircle: View {
    var port: PortSnapshot
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(Color.primary.opacity(port.isCharging ? 0.08 : 0.04))
            Image(systemName: DeviceSymbol.systemName(for: port))
                .font(.system(size: size * 0.48, weight: .medium))
                .foregroundStyle(port.isCharging ? KCStyle.charging : .secondary)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Inline Port Detail Canvas (No Pop-Up Sheet Needed)

struct PortDetailCanvas: View {
    @EnvironmentObject private var store: ChargerStore
    var portIndex: Int

    @State private var samples: [PortStatSample] = []
    @State private var loadingStats = false
    @State private var statsError: String?
    @State private var confirmOff = false

    private var port: PortSnapshot? { store.ports.first { $0.index == portIndex } }
    private var detail: PortDetail? { store.detail(for: portIndex) }
    private var pd: PDStatus? { store.pd[portIndex] }
    private var displayedSamples: [PortStatSample] {
        if !samples.isEmpty { return samples }
        if store.isDemo {
            return (0..<180).map { i in
                let watts = 46 + 14 * sin(Double(i) / 9) + (i > 120 ? -16 : 0)
                return PortStatSample(currentMa: watts / 20 * 1000, powerMw: watts * 1000, voltageMv: 20_000)
            }
        }
        return []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                // Header with device icon, title, and inline power switch
                HStack(spacing: 16) {
                    if let port {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.055))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: DeviceSymbol.systemName(for: port))
                                    .font(.system(size: 24, weight: .regular))
                                    .foregroundStyle(port.enabled ? .primary : .tertiary)
                            }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(port?.deviceName ?? (port.map(KCFormat.portDisplayName) ?? "Port"))
                            .font(.system(size: 26, weight: .bold))
                        Text("\(port.map(KCFormat.portDisplayName) ?? "") · \(port?.protocolName ?? L("No fast-charge protocol", "未协商快充协议"))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let port {
                        HStack(spacing: 8) {
                            Text(port.enabled ? L("On", "开启") : L("Off", "关闭"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            KCSwitch(isOn: Binding(
                                get: { port.enabled },
                                set: { newValue in
                                    if !newValue && port.isCharging { confirmOff = true }
                                    else { store.setPort(portIndex, on: newValue) }
                                }
                            ))
                        }
                    }
                }

                // Editorial metrics strip
                HStack(spacing: 32) {
                    PortBigMetric(title: L("Power", "功率"), value: "\(KCFormat.watts(port?.power ?? 0)) W", highlight: true)
                    PortBigMetric(title: L("Voltage", "电压"), value: KCFormat.volts(port?.voltage ?? 0))
                    PortBigMetric(title: L("Current", "电流"), value: KCFormat.amps(port?.current ?? 0))
                    PortBigMetric(title: L("Session", "本次充入"), value: detail?.sessionChargeMwh.map { KCFormat.energy(mWh: $0) } ?? "—")
                    PortBigMetric(
                        title: L("Temp", "温度"),
                        value: PortTemperature.localizedLabel(port?.temperature) ?? "—",
                        color: KCStyle.temperatureColor(port?.temperature)
                    )
                    Spacer()
                }

                Divider().opacity(0.6)

                // Charger memory log chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(L("Charger Memory Log", "设备内存功率记录"))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        if loadingStats {
                            ProgressView().controlSize(.small)
                        } else {
                            Button {
                                Task { await loadStats() }
                            } label: {
                                Label(L("Reload", "刷新记录"), systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Group {
                        if let statsError {
                            Text(statsError).font(.callout).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if displayedSamples.isEmpty {
                            Text(loadingStats ? "" : L("No samples recorded", "暂无记录"))
                                .font(.callout).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            let peakY = max((displayedSamples.map { $0.powerMw / 1000 }.max() ?? 60) * 1.2, 20)
                            Chart(Array(displayedSamples.enumerated()), id: \.offset) { item in
                                AreaMark(x: .value("Sample", item.offset), y: .value("Watts", item.element.powerMw / 1000))
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [KCStyle.accent.opacity(0.20), KCStyle.accent.opacity(0.0)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                LineMark(x: .value("Sample", item.offset), y: .value("Watts", item.element.powerMw / 1000))
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(KCStyle.accent)
                                    .lineStyle(StrokeStyle(lineWidth: 1.8))
                            }
                            .chartYScale(domain: 0...peakY)
                            .chartXAxis(.hidden)
                            .chartYAxis {
                                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.primary.opacity(0.07))
                                    AxisValueLabel {
                                        if let w = value.as(Double.self), w > 0 {
                                            Text("\(Int(w)) W").font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 165)

                    if !displayedSamples.isEmpty {
                        let powers = displayedSamples.map { $0.powerMw / 1000 }
                        HStack(spacing: 24) {
                            EditorialStat(label: L("Samples", "样本"), value: "\(displayedSamples.count)")
                            EditorialStat(label: L("Average", "平均"), value: String(format: "%.1f W", powers.reduce(0, +) / Double(powers.count)))
                            EditorialStat(label: L("Peak", "峰值"), value: String(format: "%.1f W", powers.max() ?? 0))
                            EditorialStat(
                                label: L("Voltage Range", "电压范围"),
                                value: String(format: "%.1f–%.1f V", (displayedSamples.map(\.voltageMv).min() ?? 0) / 1000, (displayedSamples.map(\.voltageMv).max() ?? 0) / 1000)
                            )
                            Spacer()
                        }
                    }
                }

                Divider().opacity(0.6)

                // Clean two-column specifications (USB PD + Cable E-Marker)
                HStack(alignment: .top, spacing: 36) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("USB PD Negotiation", "USB PD 协商"))
                            .font(.headline)
                        if let pd {
                            SpecLine(L("Revision", "PD 版本"), pd.pdRevision)
                            SpecLine(L("Requested", "请求档位"), pd.requestedVoltage.map { v in String(format: "%.2f V / %.2f A", v, pd.requestedCurrent ?? 0) })
                            SpecLine("PPS", pd.ppsChargingSupported.map { $0 ? L("Supported", "支持") : L("No", "不支持") })
                            SpecLine("EPR", pd.requestEprModeCapable.map { $0 ? L("Supported", "支持") : L("No", "不支持") })
                            SpecLine(L("Status Temp", "状态温度"), PortTemperature.localizedLabel(pd.statusTemperature))
                        } else {
                            Text(port?.enabled == true ? L("No PD negotiation data available.", "暂无 PD 协商信息") : L("Port is off.", "端口已关闭"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Cable & E-Marker", "线材与 E-Marker"))
                            .font(.headline)
                        if let pd {
                            SpecLine(L("Cable", "识别"), pd.cableName ?? (pd.hasEmarker == true ? L("E-Marker present", "带 E-Marker") : L("Standard", "普通线材")))
                            SpecLine("E-Marker", pd.hasEmarker.map { $0 ? L("Yes", "有") : L("No", "无") })
                            SpecLine(L("Max Voltage", "最高电压"), pd.cableMaxVbusVoltage)
                            SpecLine(L("Max Current", "最大电流"), pd.cableMaxVbusCurrent)
                            SpecLine(L("Data Speed", "数据速率"), pd.cableUsbHighestSpeed)
                            SpecLine(L("EPR Rated", "EPR 线材"), pd.cableEprModeCapable.map { $0 ? L("Yes", "是") : L("No", "否") })
                        } else {
                            Text(L("No cable telemetry available.", "暂无线材数据"))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 86)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: portIndex) { await loadStats() }
        .confirmationDialog(
            L("Turn off \(port.map(KCFormat.portDisplayName) ?? "port")?", "关闭端口？"),
            isPresented: $confirmOff
        ) {
            Button(L("Turn Off", "关闭端口"), role: .destructive) { store.setPort(portIndex, on: false) }
            Button(L("Cancel", "取消"), role: .cancel) {}
        }
    }

    private func loadStats() async {
        loadingStats = true
        statsError = nil
        defer { loadingStats = false }
        do {
            let result = try await store.loadStats(port: portIndex)
            withAnimation { samples = result }
        } catch {
            statsError = error.localizedDescription
        }
    }
}

private struct PortBigMetric: View {
    let title: String
    let value: String
    var highlight = false
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color ?? (highlight ? KCStyle.accent : .primary))
        }
    }
}

private struct SpecLine: View {
    let title: String
    let value: String?

    init(_ title: String, _ value: String?) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value?.isEmpty == false ? value! : "—")
                .fontWeight(.medium)
                .textSelection(.enabled)
        }
        .font(.callout)
        .padding(.vertical, 2)
    }
}
