import SwiftUI
import KangChargeCore
import KangChargeUI

// MARK: - Inline Controls Canvas (Replaces Pop-Up Sheet)

struct ControlsCanvas: View {
    @EnvironmentObject private var store: ChargerStore
    @State private var confirmingStrategy: ChargingStrategy?
    @State private var allocationValues: [Int: Double] = [:]

    private var allocationTotal: Double { allocationValues.values.reduce(0, +) }
    private var budget: Double { store.maxPower }
    private var overBudget: Bool { allocationTotal > budget }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Controls", "设备控制"))
                        .font(.system(size: 28, weight: .bold))
                    Text(L("Charging strategy, thermal policy, status display, and temporary wattage caps.", "充电策略、温控模式、状态屏与临时功率分配。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                // Charging Strategy
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("Charging Mode", "充电策略"))
                        .font(.headline)

                    VStack(spacing: 4) {
                        ForEach(ChargingStrategy.allCases) { strategy in
                            let selected = store.lastStrategy == strategy
                            Button {
                                if strategy.needsConfirmation { confirmingStrategy = strategy }
                                else { store.setStrategy(strategy) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: strategy.symbol)
                                        .font(.callout)
                                        .foregroundStyle(selected ? KCStyle.accent : .secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(strategy.localizedName)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                        Text(strategy.localizedSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selected {
                                        Image(systemName: "checkmark")
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(KCStyle.accent)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(selected ? Color.primary.opacity(0.05) : .clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(store.busy.contains("strategy"))
                        }
                    }
                }

                Divider().opacity(0.6)

                // Thermal + Display
                HStack(alignment: .top, spacing: 36) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Thermal Policy", "温控策略"))
                            .font(.headline)
                        Picker("", selection: Binding(
                            get: { store.temperatureMode ?? .power },
                            set: { store.setTemperature($0) }
                        )) {
                            ForEach(TemperatureMode.allCases) { mode in
                                Label(mode.localizedName, systemImage: mode.symbol).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .disabled(store.temperatureMode == nil || store.busy.contains("temperature"))

                        if let mode = store.temperatureMode {
                            Text(mode.localizedDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L("Status Display", "状态屏"))
                            .font(.headline)

                        HStack {
                            Text(L("Brightness", "亮度")).font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { DisplayLevel(rawValue: store.display?.level ?? "") ?? .medium },
                                set: { store.setDisplayLevel($0) }
                            )) {
                                ForEach(DisplayLevel.allCases) { level in
                                    Text(level.localizedName).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 210)
                        }

                        if store.facts.supportsExtendedDisplay {
                            HStack {
                                Text(L("Priority", "屏显模式")).font(.callout).foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { StatusDisplayMode(rawValue: store.display?.displayMode ?? "") ?? .power },
                                    set: { store.setStatusDisplayMode($0) }
                                )) {
                                    ForEach(StatusDisplayMode.allCases) { mode in
                                        Text(mode.localizedName).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 210)
                            }

                            HStack {
                                Text(L("Idle Screen", "待机显示")).font(.callout).foregroundStyle(.secondary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { IdleDisplay(rawValue: store.display?.idleDisplay ?? "") ?? .clock },
                                    set: { store.setIdleDisplay($0) }
                                )) {
                                    ForEach(IdleDisplay.allCases) { item in
                                        Text(item.localizedName).tag(item)
                                    }
                                }
                                .frame(width: 150)
                            }

                            Toggle(L("Hourly Chime", "整点报时"), isOn: Binding(
                                get: { store.display?.hourlyChime ?? false },
                                set: { store.setHourlyChime($0) }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(store.display == nil)
                    .opacity(store.display == nil ? 0.5 : 1)
                }

                Divider().opacity(0.6)

                // Temporary Power Allocation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Temporary Power Allocation", "临时功率分配"))
                                .font(.headline)
                            Text(L("Optional wattage cap per port (active ports ≥ 18 W, sum ≤ \(Int(budget)) W).", "手动指定各口功率上限（开启口 ≥ 18 W，合计 ≤ \(Int(budget)) W）。"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(allocationTotal)) / \(Int(budget)) W")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(overBudget ? KCStyle.hot : .secondary)
                    }

                    VStack(spacing: 10) {
                        ForEach(store.facts.ports, id: \.index) { port in
                            let value = allocationValues[port.index] ?? 0
                            HStack(spacing: 12) {
                                Text(port.connectorType == "A" ? "USB-A" : port.name)
                                    .font(.callout.weight(.medium))
                                    .frame(width: 52, alignment: .leading)
                                Slider(value: Binding(
                                    get: { value },
                                    set: { newValue in
                                        let snapped = newValue < 9 ? 0 : max(18, newValue.rounded())
                                        allocationValues[port.index] = min(snapped, port.power)
                                    }
                                ), in: 0...port.power)
                                Text(value == 0 ? L("Off", "关") : "\(Int(value)) W")
                                    .font(.callout.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(value == 0 ? .tertiary : .primary)
                                    .frame(width: 52, alignment: .trailing)
                            }
                        }
                    }

                    HStack {
                        Button(L("Split Evenly", "均分")) { distributeEvenly() }
                        Spacer()
                        Button(L("Apply Allocation", "应用分配")) {
                            let watts = store.facts.ports.sorted { $0.index < $1.index }.map { Int(allocationValues[$0.index] ?? 0) }
                            store.applyAllocation(watts)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(overBudget || allocationTotal == 0)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 86)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: distributeEvenly)
        .confirmationDialog(
            confirmingStrategy.map { L("Switch to \($0.localizedName)?", "切换到「\($0.localizedName)」？") } ?? "",
            isPresented: Binding(get: { confirmingStrategy != nil }, set: { if !$0 { confirmingStrategy = nil } }),
            presenting: confirmingStrategy
        ) { strategy in
            Button(L("Switch Mode", "确认切换"), role: .destructive) {
                store.setStrategy(strategy)
                confirmingStrategy = nil
            }
            Button(L("Cancel", "取消"), role: .cancel) { confirmingStrategy = nil }
        } message: { strategy in
            Text(strategy.localizedSummary)
        }
    }

    private func distributeEvenly() {
        let ports = store.facts.ports
        guard !ports.isEmpty else { return }
        let share = (budget / Double(ports.count)).rounded(.down)
        for port in ports { allocationValues[port.index] = min(max(share, 18), port.power) }
    }
}

// MARK: - Inline Hardware Info Canvas

struct DeviceInfoCanvas: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Hardware", "硬件信息"))
                        .font(.system(size: 28, weight: .bold))
                    Text("\(store.facts.localizedBrand) \(store.facts.localizedName)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 40) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Specifications", "硬件规格"))
                            .font(.headline)
                        InfoLine(L("Product", "产品"), "\(store.facts.localizedBrand) \(store.facts.localizedName)")
                        InfoLine(L("Family", "系列"), store.facts.productFamily)
                        InfoLine(L("Model", "型号"), store.info?.model)
                        InfoLine(L("Serial (PSN)", "序列号"), store.info?.psn)
                        InfoLine(L("Max Output", "最大总功率"), "\(Int(store.facts.maxPowerBudget)) W")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L("Firmware & Network", "固件与网络"))
                            .font(.headline)
                        InfoLine(L("Firmware", "固件版本"), store.info?.appVersion)
                        InfoLine("FPGA", store.info?.fpgaVersion)
                        InfoLine("Wi-Fi", store.info?.ssid)
                        InfoLine(L("Signal", "信号强度"), store.info?.rssi.map { "\($0) dBm" })
                        InfoLine(L("Channel", "信道"), store.info?.channel.map(String.init))
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
    }
}

private struct InfoLine: View {
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
        .padding(.vertical, 3)
        Divider().opacity(0.35)
    }
}
