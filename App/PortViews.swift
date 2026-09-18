import SwiftUI
import Charts

// MARK: - Port list

struct PortListCard: View {
    @EnvironmentObject private var store: ChargerStore
    var onSelect: (PortSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardTitle(title: "端口", detail: "点按查看协议与线材")
                .padding(.bottom, 8)
            ForEach(store.ports) { port in
                PortRow(port: port)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(port) }
                if port.index != store.ports.last?.index {
                    Divider().overlay(Theme.line)
                }
            }
        }
        .candyCard()
    }
}

struct CardTitle: View {
    var title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 16, weight: .heavy))
            Spacer()
            if let detail {
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.gray)
            }
        }
    }
}

struct PortRow: View {
    @EnvironmentObject private var store: ChargerStore
    var port: PortSnapshot
    @State private var confirmOff = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            PortTag(port: port)
            VStack(alignment: .leading, spacing: 3) {
                Text(port.deviceName ?? stateText)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(port.enabled ? "\(port.protocolName ?? "未协商") · \(Format.volts(port.voltage)) \(Format.amps(port.current))" : "端口已关闭 · 最高 \(Int(port.maxPower))W")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(port.enabled ? "\(Format.watts(port.power))W" : "—")
                    .font(.system(size: 15, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(port.isCharging ? Theme.orange : Theme.ink)
                HStack(spacing: 3) {
                    Circle().fill(Theme.temperatureColor(port.temperature)).frame(width: 6, height: 6)
                    Text(PortTemperature.label(port.temperature))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.gray)
            }
            CandyToggle(isOn: Binding(
                get: { port.enabled },
                set: { newValue in
                    if !newValue && port.isCharging { confirmOff = true } else { store.setPort(port.index, on: newValue) }
                }
            ), label: "\(Format.portLabel(port)) 供电", scale: 0.9)
            .disabled(store.busy.contains("port-\(port.index)"))
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering ? Theme.cream.opacity(0.7) : .clear))
        .onHover { hovering = $0 }
        .confirmationDialog("关闭 \(port.name) 口？", isPresented: $confirmOff) {
            Button("关闭端口", role: .destructive) { store.setPort(port.index, on: false) }
        } message: {
            Text("\(port.deviceName ?? "该端口上的设备")正在以 \(Format.watts(port.power))W 充电，关闭后将立即断电。")
        }
    }

    private var stateText: String {
        if !port.enabled { return port.connector == "A" ? "USB-A 口" : "USB-C 口" }
        return port.isCharging ? "充电中" : "待机"
    }
}

struct PortTag: View {
    var port: PortSnapshot
    var size: CGFloat = 36

    var body: some View {
        Text(port.connector == "A" ? "A" : port.name)
            .font(.system(size: size * 0.36, weight: .heavy))
            .foregroundStyle(port.enabled ? Theme.orange : Theme.gray)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(port.enabled ? Theme.orangeSoft : Color(hex: 0xF0F0F0)))
    }
}

// MARK: - Detail sheet

struct PortDetailSheet: View {
    @EnvironmentObject private var store: ChargerStore
    @Environment(\.dismiss) private var dismiss
    var portIndex: Int

    @State private var samples: [PortStatSample] = []
    @State private var loadingStats = false
    @State private var statsError: String?

    private var port: PortSnapshot? { store.ports.first { $0.index == portIndex } }
    private var detail: PortDetail? { store.detail(for: portIndex) }
    private var pd: PDStatus? { store.pd[portIndex] }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    liveGrid
                    historySection
                    HStack(alignment: .top, spacing: 14) {
                        pdSection
                        cableSection
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
            }
        }
        .frame(width: 680, height: 700)
        .background(Theme.cream)
        .foregroundStyle(Theme.ink)
        .task { await loadStats() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let port { PortTag(port: port, size: 46) }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(port.map(Format.portLabel) ?? "") · \(port?.deviceName ?? "未识别设备")")
                    .font(.system(size: 22, weight: .heavy))
                Text(port?.protocolName ?? "未协商快充协议")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gray)
            }
            Spacer()
            if let port {
                HStack(spacing: 8) {
                    Text("端口供电").font(.system(size: 13, weight: .medium))
                    CandyToggle(isOn: Binding(get: { port.enabled }, set: { store.setPort(portIndex, on: $0) }), label: "端口供电")
                }
            }
            Button("完成") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .tint(Theme.orange)
        }
        .padding(22)
    }

    private var liveGrid: some View {
        HStack(spacing: 10) {
            MetricTile(title: "实时功率", value: Format.watts(port?.power ?? 0), unit: "W", highlight: true)
            MetricTile(title: "输出电压", value: String(format: "%.2f", port?.voltage ?? 0), unit: "V")
            MetricTile(title: "输出电流", value: String(format: "%.2f", port?.current ?? 0), unit: "A")
            MetricTile(title: "本次充入", value: detail?.sessionChargeMwh.map { Format.energy(mWh: $0) } ?? "—", unit: "")
            MetricTile(title: "芯片温度", value: PortTemperature.label(port?.temperature), unit: "", color: Theme.temperatureColor(port?.temperature))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("设备内存中的功率记录").font(.system(size: 15, weight: .heavy))
                Spacer()
                if loadingStats {
                    ProgressView().controlSize(.small)
                    Text("正在从小电拼读取…").font(.system(size: 11)).foregroundStyle(Theme.gray)
                } else {
                    Button { Task { await loadStats() } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.orange)
                }
            }
            Group {
                if let statsError {
                    Text(statsError).foregroundStyle(Theme.gray).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if samples.isEmpty {
                    Text(loadingStats ? "" : "暂无记录").foregroundStyle(Theme.gray).frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Chart(Array(samples.enumerated()), id: \.offset) { item in
                        AreaMark(x: .value("序号", item.offset), y: .value("功率", item.element.powerMw / 1000))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [Theme.orange.opacity(0.22), Theme.orange.opacity(0)], startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("序号", item.offset), y: .value("功率", item.element.powerMw / 1000))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.orange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(Theme.line)
                            AxisValueLabel { if let w = value.as(Double.self) { Text(String(format: "%.1fW", w)).foregroundStyle(Theme.gray) } }
                        }
                    }
                }
            }
            .frame(height: 170)
            if !samples.isEmpty {
                let powers = samples.map { $0.powerMw / 1000 }
                HStack(spacing: 22) {
                    SummaryValue(title: "样本", value: "\(samples.count)")
                    SummaryValue(title: "平均", value: String(format: "%.2fW", powers.reduce(0, +) / Double(powers.count)))
                    SummaryValue(title: "峰值", value: String(format: "%.2fW", powers.max() ?? 0))
                    SummaryValue(title: "电压范围", value: String(format: "%.2f–%.2fV", (samples.map(\.voltageMv).min() ?? 0) / 1000, (samples.map(\.voltageMv).max() ?? 0) / 1000))
                    Spacer()
                }
            }
        }
        .candyCard()
    }

    private var pdSection: some View {
        DetailList(title: "USB PD 协商") {
            if let pd {
                DetailRow("PD 版本", pd.pdRevision)
                DetailRow("请求档位", pd.requestedVoltage.map { v in String(format: "%.2fV / %.2fA", v, pd.requestedCurrent ?? 0) })
                DetailRow("PPS 支持", pd.ppsChargingSupported.map { $0 ? "支持" : "不支持" })
                DetailRow("EPR 请求", pd.requestEprModeCapable.map { $0 ? "支持" : "不支持" })
                DetailRow("状态温度", PortTemperature.label(pd.statusTemperature))
                if pd.hasBattery == true {
                    DetailRow("电池容量", pd.batteryPresentCapacity.map { String(format: "%.1f / %.1f Wh", $0 / 10, (pd.batteryDesignCapacity ?? 0) / 10) })
                }
            } else {
                Text(port?.enabled == true ? "正在读取 PD 信息…" : "端口未开启").font(.system(size: 12)).foregroundStyle(Theme.gray)
            }
        }
    }

    private var cableSection: some View {
        DetailList(title: "线材") {
            if let pd {
                DetailRow("识别", pd.cableName ?? (pd.hasEmarker == true ? "带 E-Marker" : "未识别"))
                DetailRow("E-Marker", pd.hasEmarker.map { $0 ? "有" : "无" })
                DetailRow("最高电压", pd.cableMaxVbusVoltage)
                DetailRow("最大电流", pd.cableMaxVbusCurrent)
                DetailRow("数据速率", pd.cableUsbHighestSpeed)
                DetailRow("类型", pd.cableIsActive.map { $0 ? "有源线" : "无源线" })
                DetailRow("EPR 线材", pd.cableEprModeCapable.map { $0 ? "是" : "否" })
            } else {
                Text("暂无线材数据").font(.system(size: 12)).foregroundStyle(Theme.gray)
            }
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

struct MetricTile: View {
    var title: String
    var value: String
    var unit: String
    var highlight = false
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.gray)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(color ?? (highlight ? Theme.orange : Theme.ink))
                    .contentTransition(.numericText())
                Text(unit).font(.system(size: 12, weight: .bold)).foregroundStyle(highlight ? Theme.orange : Theme.ink)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .candyCard(padding: 12, radius: 12)
    }
}

struct SummaryValue: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 10)).foregroundStyle(Theme.gray)
            Text(value).font(.system(size: 13, weight: .bold)).monospacedDigit()
        }
    }
}

struct DetailList<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 15, weight: .heavy))
            VStack(spacing: 8) { content }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .candyCard()
    }
}

struct DetailRow: View {
    var title: String
    var value: String?

    init(_ title: String, _ value: String?) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title).foregroundStyle(Theme.gray)
            Spacer()
            Text(value?.isEmpty == false ? value! : "—")
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.system(size: 12))
    }
}
