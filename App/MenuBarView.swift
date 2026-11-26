import SwiftUI
import KangChargeCore
import KangChargeUI

struct MenuBarPanel: View {
    @EnvironmentObject private var store: ChargerStore
    @Environment(\.openWindow) private var openWindow
    var onOpenMainWindow: (() -> Void)? = nil

    var body: some View {
        if store.isConfigured {
            connectedPanel
        } else {
            setupPrompt
        }
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.circle.fill")
                    .font(.title2)
                    .foregroundStyle(KCStyle.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SugarWatt")
                        .font(.headline)
                    Text(L("Not connected yet", "尚未连接充电器"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(L("Open the main window and paste your CANDYSIGN MCP address to get started.", "打开主窗口并粘贴 CANDYSIGN 的 MCP 地址即可开始。"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button(L("Set Up", "开始设置")) {
                    openMainWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Spacer()
                Button(L("Quit", "退出")) { NSApp.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 290)
    }

    private var connectedPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        StatusDot(connection: store.connection)
                        Text(store.deviceName)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Text(L(
                        "\(store.snapshot?.chargingCount ?? 0) charging · Today \(KCFormat.energy(wattHours: store.energySummary.todayWattHours))",
                        "\(store.snapshot?.chargingCount ?? 0) 口充电中 · 今日 \(KCFormat.energy(wattHours: store.energySummary.todayWattHours))"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(KCFormat.watts(store.totalPower))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: store.totalPower))
                    Text("W")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            KCLoadBar(
                fraction: store.maxPower > 0 ? store.totalPower / store.maxPower : 0,
                color: KCStyle.accent,
                height: 5
            )

            Divider()

            // Ports
            VStack(spacing: 6) {
                ForEach(store.ports) { port in
                    HStack(spacing: 8) {
                        PortBadgeCircle(port: port, size: 22)
                        Text(port.deviceName ?? (port.isCharging ? (KCFormat.protocolTag(port.protocolName) ?? KCFormat.portDisplayName(port)) : KCFormat.portDisplayName(port)))
                            .font(.callout)
                            .foregroundStyle(port.isCharging ? .primary : .secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(port.isCharging ? "\(KCFormat.watts(port.power)) W" : "—")
                            .font(.callout.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(port.isCharging ? .primary : .secondary)
                        if port.isCharging {
                            KCSwitch(isOn: Binding(
                                get: { true },
                                set: { if !$0 { store.setPort(port.index, on: false) } }
                            ), scale: 0.88)
                            .disabled(store.busy.contains("port-\(port.index)"))
                        } else {
                            Button(L("Idle", "空闲")) {
                                store.setPort(port.index, on: true)
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .buttonStyle(.plain)
                            .frame(width: 30, alignment: .trailing)
                            .disabled(store.busy.contains("port-\(port.index)"))
                        }
                    }
                }
            }

            Divider()

            // Quick modes
            HStack(spacing: 6) {
                ForEach([ChargingStrategy.fast, .slow, .highPerformance]) { strategy in
                    let selected = store.lastStrategy == strategy
                    Button {
                        store.setStrategy(strategy)
                    } label: {
                        Text(strategy.localizedName)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(selected ? KCStyle.accent.opacity(0.16) : Color.primary.opacity(0.05))
                            )
                            .foregroundStyle(selected ? KCStyle.accent : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.busy.contains("strategy"))
                }
            }

            Divider()

            // Footer actions
            HStack(spacing: 8) {
                Button(L("Open SugarWatt", "打开主窗口")) {
                    openMainWindow()
                }
                .buttonStyle(.borderedProminent)
                .tint(KCStyle.accent)
                .controlSize(.small)

                Spacer()

                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(L("Refresh", "刷新"))

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .help(L("Quit SugarWatt", "退出 SugarWatt"))
            }

            if let toast = store.toast {
                Text(toast.message)
                    .font(.caption)
                    .foregroundStyle(toast.isError ? KCStyle.hot : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private func openMainWindow() {
        if let onOpenMainWindow {
            onOpenMainWindow()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
    }
}

// MARK: - Native macOS Settings

struct SettingsView: View {
    @EnvironmentObject private var store: ChargerStore
    @EnvironmentObject private var visibility: AppVisibility
    @EnvironmentObject private var updater: UpdateChecker
    @State private var confirmDisconnect = false
    @State private var confirmResetEnergy = false
    @State private var iCloudSync = AppConfig.iCloudEnergySyncEnabled

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label(L("General", "通用"), systemImage: "gearshape") }

            connectionTab
                .tabItem { Label(L("Connection", "连接"), systemImage: "bolt.horizontal") }

            #if !APP_STORE
            updatesTab
                .tabItem { Label(L("Updates", "更新"), systemImage: "arrow.down.circle") }
            #endif
        }
        .frame(width: 480, height: 340)
    }

    private var generalTab: some View {
        Form {
            Section(L("App Presence", "显示方式")) {
                Toggle(L("Keep in Dock", "在 Dock 栏常驻"), isOn: $visibility.showInDock)
                    .disabled(!visibility.showInMenuBar)
                Toggle(L("Show in Menu Bar", "在菜单栏显示"), isOn: $visibility.showInMenuBar)
                    .disabled(!visibility.showInDock)
                Text(L(
                    "At least one of Dock or Menu Bar stays enabled so you can always reach SugarWatt. Closing the window keeps polling in the background.",
                    "Dock 与菜单栏至少保留一项，防止无法找回窗口。关闭主窗口后程序会在后台继续记录用电量。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section(L("Daily Energy History", "每日用电量记录")) {
                Toggle(L("Sync daily energy via iCloud", "通过 iCloud 同步每日用电量"), isOn: Binding(
                    get: { iCloudSync },
                    set: { newValue in
                        iCloudSync = newValue
                        AppConfig.iCloudEnergySyncEnabled = newValue
                        if newValue {
                            EnergyLedger.shared.pullFromCloud()
                            EnergyLedger.shared.pushToCloudNow()
                        }
                    }
                ))
                if !EnergyLedger.shared.isCloudAvailable {
                    Text(L(
                        "Local-only in this unsigned/personal build. Signed builds with iCloud KVS enabled sync automatically with SugarWatt for iOS.",
                        "当前本地构建仅保存在本机。开启 iCloud KVS 签名的构建会自动与 iOS 版同步热力图数据。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Button(L("Clear Energy History…", "清除历史用电记录…"), role: .destructive) {
                    confirmResetEnergy = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(L("Clear daily energy history?", "清除所有每日用电量记录？"), isPresented: $confirmResetEnergy) {
            Button(L("Clear History", "确认清除"), role: .destructive) { store.resetEnergyHistory() }
            Button(L("Cancel", "取消"), role: .cancel) {}
        }
    }

    private var connectionTab: some View {
        Form {
            Section(L("Charger MCP Endpoint", "充电器 MCP 地址")) {
                ConnectionForm(submitTitle: L("Save & Reconnect", "保存并重连"))
            }

            Section {
                HStack {
                    Text(L("Stored locally on this Mac only.", "地址仅保存在本机，不上传任何第三方服务器。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Disconnect…", "断开连接…"), role: .destructive) {
                        confirmDisconnect = true
                    }
                    .disabled(!store.isConfigured)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(L("Disconnect this charger?", "断开充电器连接？"), isPresented: $confirmDisconnect) {
            Button(L("Disconnect & Clear", "断开并清除"), role: .destructive) { store.disconnect() }
            Button(L("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(L("Removes the saved MCP URL and cached readings from this Mac.", "将删除本机保存的 MCP 地址与缓存数据。"))
        }
    }

    private var updatesTab: some View {
        Form {
            Section(L("Software Updates", "软件更新")) {
                LabeledContent(L("Current Version", "当前版本"), value: updater.currentVersion)
                Toggle(L("Automatically check for updates", "自动检查更新"), isOn: $updater.autoCheckEnabled)

                HStack {
                    Button(L("Check Now", "立即检查")) {
                        Task { await updater.checkNow(silent: false) }
                    }
                    .disabled(updater.status == .checking)

                    Spacer()

                    switch updater.status {
                    case .idle:
                        EmptyView()
                    case .checking:
                        ProgressView().controlSize(.small)
                    case .upToDate:
                        Label(L("Up to date", "已是最新版本"), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(KCStyle.charging)
                    case .available(let version, let url, _):
                        Link(L("Download v\(version)", "下载 v\(version)"), destination: url)
                            .font(.caption.weight(.semibold))
                    case .failed:
                        Text(L("Couldn't reach GitHub", "无法检查更新"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(L("Open Source", "开源信息")) {
                Link(L("SugarWatt on GitHub", "GitHub 仓库"), destination: URL(string: "https://github.com/LeiZiKang/KangCharge")!)
                LabeledContent(L("License", "开源协议"), value: "MIT")
            }
        }
        .formStyle(.grouped)
    }
}
