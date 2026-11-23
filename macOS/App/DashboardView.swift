import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: ChargerStore
    @State private var selectedPort: PortSnapshot?
    @State private var showAllocation = false
    @State private var showDeviceInfo = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HeaderView(showDeviceInfo: $showDeviceInfo)

                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 16) {
                            ModeCard()
                            PowerCard(onSelect: { selectedPort = $0 })
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 16) {
                            PortListCard(onSelect: { selectedPort = $0 })
                            DeviceCard()
                        }
                        .frame(width: 350)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        TemperatureCard()
                        DisplayCard()
                        AllocationCard(showAllocation: $showAllocation)
                            .frame(width: 350)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .frame(maxWidth: 1240)
                .frame(maxWidth: .infinity)
            }

            if let toast = store.toast {
                ToastView(toast: toast)
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.orange)
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: DebugSnapshot.openPortNotification)) { note in
            if let index = note.object as? Int { selectedPort = store.ports.first { $0.index == index } }
        }
        #endif
        .sheet(item: $selectedPort) { port in
            PortDetailSheet(portIndex: port.index)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAllocation) {
            AllocationSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $showDeviceInfo) {
            DeviceInfoSheet()
                .environmentObject(store)
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @EnvironmentObject private var store: ChargerStore
    @Binding var showDeviceInfo: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CoCan Mirror")
                    .font(.system(size: 13, weight: .heavy).italic())
                    .foregroundStyle(Theme.orange)
                HStack(spacing: 10) {
                    Text(store.deviceName)
                        .font(.system(size: 30, weight: .heavy))
                    Button {
                        showDeviceInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.gray)
                    }
                    .buttonStyle(.plain)
                    .help("设备信息")
                }
                HStack(spacing: 8) {
                    StatusBadge()
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gray)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                CircleButton(symbol: "arrow.clockwise", help: "立即刷新 (⌘R)") {
                    Task { await store.refreshAll() }
                }
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .help("设置")
            }
        }
        .padding(.horizontal, 4)
    }

    private var subtitle: String {
        var parts = ["\(store.facts.brandZh ?? "制糖工厂") \(store.facts.friendlyNameZh ?? "小电拼")"]
        if let info = store.info {
            if let ssid = info.ssid { parts.append("Wi-Fi \(ssid)\(info.rssi.map { " \($0)dBm" } ?? "")") }
            if let version = info.appVersion { parts.append("固件 \(version)") }
        }
        if let date = store.lastUpdated {
            parts.append("更新于 \(date.formatted(date: .omitted, time: .standard))")
        }
        return parts.joined(separator: " · ")
    }
}

struct StatusBadge: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        let (text, color): (String, Color) = {
            switch store.connection {
            case .online: return ("在线", Theme.green)
            case .connecting: return ("连接中", Theme.amber)
            case .offline: return ("离线", Theme.red)
            }
        }()
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
            .help({ if case .offline(let message) = store.connection { return message }; return "通过 MCP 实时连接" }())
    }
}

struct CircleButton: View {
    var symbol: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Mode card

struct ModeCard: View {
    @EnvironmentObject private var store: ChargerStore
    @State private var confirming: ChargingStrategy?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label {
                    Text("模式").font(.system(size: 13, weight: .semibold))
                } icon: {
                    Image(systemName: "slider.horizontal.below.rectangle").foregroundStyle(Theme.orange)
                }
                .foregroundStyle(Theme.gray)
                .fixedSize()

                HStack(spacing: 8) {
                        ForEach(ChargingStrategy.allCases) { strategy in
                            ModePill(
                                title: strategy.shortTitle,
                                symbol: strategy.symbol,
                                selected: store.lastStrategy == strategy,
                                busy: store.busy.contains("strategy")
                            ) {
                                if strategy.needsConfirmation { confirming = strategy } else { store.setStrategy(strategy) }
                            }
                            .help("\(strategy.title)（\(strategy.rawValue)）：\(strategy.detail)")
                    }
                }
                Spacer(minLength: 0)
            }

            Divider().overlay(Theme.line)

            HStack(spacing: 10) {
                Circle()
                    .fill(isCharging ? Theme.orange : Theme.lightGray)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isCharging ? "正在充电" : "待机中")
                        .font(.system(size: 14, weight: .bold))
                    Text(store.lastStrategy.map { "\($0.title) · \($0.detail)" } ?? "实时监控充电功率、温度")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.gray)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    store.setTemperature(store.temperatureMode == .power ? .temperature : .power)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: store.temperatureMode?.symbol ?? "thermometer.medium")
                        Text(store.temperatureMode?.title ?? "温控")
                        Image(systemName: "arrow.left.arrow.right").font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.green)
                }
                .buttonStyle(.plain)
                .help("点按切换功率优先 / 温度优先")
                .disabled(store.temperatureMode == nil || store.busy.contains("temperature"))
            }
        }
        .candyCard()
        .confirmationDialog(confirming.map { "切换到「\($0.title)」？" } ?? "", isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }), presenting: confirming) { strategy in
            Button("确认切换") { store.setStrategy(strategy) }
        } message: { strategy in
            Text(strategy == .usbA ? "请确保 C4 口已连接小家电。切换将断电重连。" : "独享 · C1 模式下仅 C1 口输出，A、C2、C3、C4 口将被关闭。")
        }
    }

    private var isCharging: Bool { (store.snapshot?.chargingCount ?? 0) > 0 }
}

struct ModePill: View {
    var title: String
    var symbol: String
    var selected: Bool
    var busy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? Color.white : Theme.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Capsule().fill(selected ? Theme.orange : Color.white))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Color(hex: 0xE1E1E1), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}

extension ChargingStrategy {
    var shortTitle: String {
        switch self {
        case .fast: return "自由流"
        case .slow: return "睡眠充"
        case .usbA: return "小家电"
        case .highPerformance: return "无线损"
        case .singlePort: return "独享C1"
        }
    }
}

// MARK: - Power card (cable diagram)

struct PowerCard: View {
    @EnvironmentObject private var store: ChargerStore
    var onSelect: (PortSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack(alignment: .bottomLeading) {
                CableDiagram(ports: store.ports, chipScale: 1.05, chargerScale: 1.9, cableWidth: 5, animated: true, onTap: onSelect)

                VStack(alignment: .leading, spacing: 2) {
                    Text("实时充电功率")
                        .font(.system(size: 14, weight: .semibold))
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(Format.watts(store.totalPower))
                            .font(.system(size: 48, weight: .heavy))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: store.totalPower))
                        Text("W").font(.system(size: 32, weight: .heavy))
                    }
                    .foregroundStyle(Theme.orange)
                }
                .padding(.bottom, 4)
            }
            .overlay(alignment: .bottomTrailing) {
                BudgetBox(used: store.totalPower, budget: store.maxPower)
                    .offset(x: -8, y: 40)
            }
            .frame(height: 290)
            .padding(.bottom, 36)

            Divider().overlay(Theme.line)

            HStack {
                FooterStat(symbol: "clock", title: "充电中", value: "\(store.snapshot?.chargingCount ?? 0) / \(store.facts.ports.count) 口")
                Spacer()
                FooterStat(symbol: "bolt.circle", title: "本次累计", value: store.sessionEnergy > 0 ? Format.energy(mWh: store.sessionEnergy) : "—")
                Spacer()
                FooterStat(symbol: "gauge.with.dots.needle.33percent", title: "剩余功率", value: "\(Format.watts(max(store.maxPower - store.totalPower, 0)))W")
            }
        }
        .candyCard(padding: 20)
    }
}

struct BudgetBox: View {
    var used: Double
    var budget: Double

    var body: some View {
        VStack(spacing: 0) {
            Text("\(Int(budget))W")
                .font(.system(size: 20, weight: .heavy))
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
            Rectangle().fill(Theme.orange).frame(height: 1.5)
            Text("已使用 \(budget > 0 ? Int((used / budget * 100).rounded()) : 0)%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.orange)
                .padding(.vertical, 3)
        }
        .fixedSize()
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.orange, lineWidth: 1.5))
    }
}

struct FooterStat: View {
    var symbol: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(Theme.orange)
            Text(title).foregroundStyle(Theme.ink)
            Text(value).foregroundStyle(Theme.gray).monospacedDigit()
        }
        .font(.system(size: 13, weight: .semibold))
    }
}

// MARK: - Toast

struct ToastView: View {
    var toast: ChargerStore.Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? Theme.red : Theme.orange)
            Text(toast.message)
                .foregroundStyle(Theme.ink)
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 4)
    }
}

// MARK: - Device card

struct DeviceCard: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(title: "设备", detail: store.facts.productFamily)
            DetailRow("序列号", store.info?.psn)
            DetailRow("固件 / FPGA", store.info.map { "\($0.appVersion ?? "—") / \($0.fpgaVersion ?? "—")" })
            DetailRow("Wi-Fi", store.info.map { "\($0.ssid ?? "—") · \($0.rssi.map { "\($0) dBm" } ?? "—")" })
            DetailRow("最大总功率", "\(Int(store.facts.maxPowerBudget))W")
        }
        .candyCard()
    }
}
