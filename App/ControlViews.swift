import SwiftUI

/// Pill segmented control in the CANDYSIGN style.
struct PillSegments<Value: Hashable>: View {
    var options: [(Value, String)]
    var selection: Value?
    var onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.0) { value, title in
                let selected = value == selection
                Button { onSelect(value) } label: {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(selected ? Color.white : Theme.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(selected ? Theme.orange : Color.white))
                        .overlay(Capsule().strokeBorder(selected ? Color.clear : Color(hex: 0xE1E1E1)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TemperatureCard: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardTitle(title: "温控")
                if store.busy.contains("temperature") { ProgressView().controlSize(.small) }
            }
            ForEach(TemperatureMode.allCases) { mode in
                let selected = store.temperatureMode == mode
                Button { store.setTemperature(mode) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(selected ? Color.white : Theme.orange)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(selected ? Theme.orange : Theme.orangeSoft))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(mode.title)（\(mode.rawValue)）").font(.system(size: 13, weight: .bold))
                            Text(mode.detail).font(.system(size: 11)).foregroundStyle(Theme.gray)
                        }
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 17))
                            .foregroundStyle(selected ? Theme.orange : Theme.lightGray)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Theme.orangeSoft.opacity(0.6) : Theme.cream.opacity(0.6)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .candyCard()
    }
}

struct DisplayCard: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardTitle(title: "状态屏")
                if store.busy.contains(where: { $0.hasPrefix("display") || $0 == "idle-display" || $0 == "hourly-chime" }) {
                    ProgressView().controlSize(.small)
                }
            }

            SettingRow(title: "亮度") {
                PillSegments(options: DisplayLevel.allCases.map { ($0, $0.rawValue) },
                             selection: DisplayLevel(rawValue: store.display?.level ?? "")) { store.setDisplayLevel($0) }
            }

            if store.facts.supportsExtendedDisplay {
                SettingRow(title: "屏显模式") {
                    PillSegments(options: [(StatusDisplayMode.animation, "动画优先"), (.power, "功率优先")],
                                 selection: StatusDisplayMode(rawValue: store.display?.displayMode ?? "")) { store.setStatusDisplayMode($0) }
                }
                SettingRow(title: "待机显示") {
                    PillSegments(options: [(IdleDisplay.meteor, "流星"), (.petals, "落花"), (.life, "生命游戏"), (.clock, "时间")],
                                 selection: IdleDisplay(rawValue: store.display?.idleDisplay ?? "")) { store.setIdleDisplay($0) }
                }
                SettingRow(title: "整点报时") {
                    CandyToggle(isOn: Binding(get: { store.display?.hourlyChime ?? false }, set: { store.setHourlyChime($0) }), label: "整点报时")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .candyCard()
        .disabled(store.display == nil)
        .opacity(store.display == nil ? 0.5 : 1)
    }
}

struct SettingRow<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.gray)
            Spacer(minLength: 8)
            content
        }
    }
}

struct AllocationCard: View {
    @EnvironmentObject private var store: ChargerStore
    @Binding var showAllocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardTitle(title: "临时功率分配")
            Text("手动指定每个端口的功率上限（开启的端口至少 18W，总和不超过 \(Int(store.maxPower))W）。自由流会按需自动调度，一般无需手动分配。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.gray)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                ForEach(store.facts.ports, id: \.index) { port in
                    VStack(spacing: 2) {
                        Text(port.connectorType == "A" ? "A" : port.name).font(.system(size: 10, weight: .bold))
                        Text("\(Int(port.power))W").font(.system(size: 10)).foregroundStyle(Theme.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.cream))
                }
            }
            Button { showAllocation = true } label: {
                Text("调整分配")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
        }
        .candyCard()
    }
}

// MARK: - Allocation sheet

struct AllocationSheet: View {
    @EnvironmentObject private var store: ChargerStore
    @Environment(\.dismiss) private var dismiss
    @State private var values: [Int: Double] = [:]

    private var total: Double { values.values.reduce(0, +) }
    private var budget: Double { store.maxPower }
    private var overBudget: Bool { total > budget }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("临时功率分配").font(.system(size: 22, weight: .heavy))
                Text("0W 表示关闭该口，开启的端口至少 18W，总和不超过 \(Int(budget))W。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.gray)
            }

            VStack(spacing: 14) {
                ForEach(store.facts.ports, id: \.index) { port in
                    let value = values[port.index] ?? 0
                    HStack(spacing: 12) {
                        Text(port.connectorType == "A" ? "USB-A" : port.name)
                            .font(.system(size: 12, weight: .heavy))
                            .frame(width: 44, alignment: .leading)
                        Slider(value: Binding(
                            get: { value },
                            set: { newValue in
                                let snapped = newValue < 9 ? 0 : max(18, newValue.rounded())
                                values[port.index] = min(snapped, port.power)
                            }
                        ), in: 0...port.power)
                        .tint(Theme.orange)
                        Text(value == 0 ? "关闭" : "\(Int(value))W")
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(value == 0 ? Theme.gray : Theme.orange)
                            .frame(width: 48, alignment: .trailing)
                    }
                }
            }
            .candyCard()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("合计").font(.system(size: 12)).foregroundStyle(Theme.gray)
                    Spacer()
                    Text("\(Int(total)) / \(Int(budget))W")
                        .font(.system(size: 17, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(overBudget ? Theme.red : Theme.ink)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white)
                        Capsule().fill(overBudget ? Theme.red : Theme.orange)
                            .frame(width: geo.size.width * min(total / max(budget, 1), 1))
                    }
                }
                .frame(height: 8)
                if overBudget {
                    Text("超出总功率预算 \(Int(total - budget))W").font(.system(size: 11)).foregroundStyle(Theme.red)
                }
            }

            HStack {
                Button("均分") { distributeEvenly() }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("应用分配") {
                    let watts = store.facts.ports.sorted { $0.index < $1.index }.map { Int(values[$0.index] ?? 0) }
                    store.applyAllocation(watts)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(overBudget || total == 0)
            }
            .tint(Theme.orange)
        }
        .padding(24)
        .frame(width: 500)
        .background(Theme.cream)
        .foregroundStyle(Theme.ink)
        .onAppear(perform: distributeEvenly)
    }

    private func distributeEvenly() {
        let ports = store.facts.ports
        guard !ports.isEmpty else { return }
        let share = (budget / Double(ports.count)).rounded(.down)
        for port in ports { values[port.index] = min(max(share, 18), port.power) }
    }
}

// MARK: - Device info

struct DeviceInfoSheet: View {
    @EnvironmentObject private var store: ChargerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CoCan Mirror").font(.system(size: 12, weight: .heavy).italic()).foregroundStyle(Theme.orange)
                    Text(store.deviceName).font(.system(size: 22, weight: .heavy))
                }
                Spacer()
            }
            DetailList(title: "硬件") {
                DetailRow("产品", "\(store.facts.brandZh ?? "") \(store.facts.friendlyNameZh ?? "")")
                DetailRow("产品系列", store.facts.productFamily)
                DetailRow("型号", store.info?.model)
                DetailRow("序列号 PSN", store.info?.psn)
                DetailRow("最大总功率", "\(Int(store.facts.maxPowerBudget))W")
                DetailRow("端口", store.facts.ports.map { "\($0.name) \(Int($0.power))W" }.joined(separator: " · "))
            }
            DetailList(title: "固件与网络") {
                DetailRow("固件版本", store.info?.appVersion)
                DetailRow("FPGA 版本", store.info?.fpgaVersion)
                DetailRow("Wi-Fi", store.info?.ssid)
                DetailRow("信号强度", store.info?.rssi.map { "\($0) dBm" })
                DetailRow("信道", store.info?.channel.map(String.init))
            }
            HStack {
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction).tint(Theme.orange)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Theme.cream)
        .foregroundStyle(Theme.ink)
    }
}
