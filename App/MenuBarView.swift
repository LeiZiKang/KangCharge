import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var store: ChargerStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if store.isConfigured { panel } else { setupPrompt }
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("还没有连接小电拼").font(.system(size: 16, weight: .heavy))
            Text("打开主窗口，粘贴 CANDYSIGN App 里的 MCP 地址即可开始。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.gray)
            HStack {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                } label: {
                    Text("开始设置")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.orange))
                }
                .buttonStyle(.plain)
                Spacer()
                CircleButton(symbol: "power", help: "退出 Kang Charge") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Theme.cream)
        .foregroundStyle(Theme.ink)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CoCan Mirror").font(.system(size: 11, weight: .heavy).italic()).foregroundStyle(Theme.orange)
                    Text(store.deviceName).font(.system(size: 20, weight: .heavy))
                    HStack(spacing: 6) {
                        StatusBadge()
                        Text("\(store.snapshot?.chargingCount ?? 0) 口充电中").font(.system(size: 11)).foregroundStyle(Theme.gray)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("实时充电功率").font(.system(size: 11, weight: .semibold))
                    Text("\(Format.watts(store.totalPower))W")
                        .font(.system(size: 30, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Theme.orange)
                        .contentTransition(.numericText(value: store.totalPower))
                }
            }

            HStack(spacing: 6) {
                ForEach(store.ports) { port in
                    PortChip(port: port, scale: 0.9)
                }
            }
            .candyCard(padding: 10, radius: 12)

            VStack(spacing: 0) {
                ForEach(store.ports) { port in
                    HStack(spacing: 10) {
                        PortTag(port: port, size: 26)
                        Text(port.deviceName ?? (port.enabled ? (port.protocolName ?? "空闲") : "已关闭"))
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        CandyToggle(isOn: Binding(get: { port.enabled }, set: { store.setPort(port.index, on: $0) }),
                                    label: "\(Format.portLabel(port)) 供电", scale: 0.85)
                    }
                    .padding(.vertical, 5)
                    if port.index != store.ports.last?.index { Divider().overlay(Theme.line) }
                }
            }
            .candyCard(padding: 10, radius: 12)

            HStack(spacing: 6) {
                ForEach([ChargingStrategy.fast, .slow, .highPerformance]) { strategy in
                    ModePill(title: strategy.shortTitle, symbol: strategy.symbol, selected: store.lastStrategy == strategy, busy: store.busy.contains("strategy")) {
                        store.setStrategy(strategy)
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                } label: {
                    Text("打开主窗口")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Theme.orange))
                }
                .buttonStyle(.plain)
                Spacer()
                CircleButton(symbol: "arrow.clockwise", help: "刷新") { Task { await store.refreshAll() } }
                CircleButton(symbol: "power", help: "退出 Kang Charge") { NSApp.terminate(nil) }
            }

            if let toast = store.toast {
                ToastView(toast: toast).frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(Theme.cream)
        .foregroundStyle(Theme.ink)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ChargerStore
    @State private var confirmDisconnect = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("小电拼连接").font(.system(size: 18, weight: .heavy))
            ConnectionForm(submitTitle: "保存并重新连接")
            Divider()
            HStack {
                Text("地址只保存在本机。更换设备时粘贴新地址即可。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gray)
                Spacer()
                Button("断开并清除数据", role: .destructive) { confirmDisconnect = true }
                    .disabled(!store.isConfigured)
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(Color.white)
        .foregroundStyle(Theme.ink)
        .confirmationDialog("断开小电拼？", isPresented: $confirmDisconnect) {
            Button("断开并清除", role: .destructive) { store.disconnect() }
        } message: {
            Text("会删除本机保存的 MCP 地址和缓存数据，小组件也会显示为未设置。")
        }
    }
}
