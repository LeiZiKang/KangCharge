import SwiftUI
import Charts
import KangChargeCore
import KangChargeUI

enum SidebarDestination: Hashable {
    case overview
    case energy
    case controls
    case device
    case port(Int)
}

/// Apple Music-inspired native macOS workspace:
/// translucent vibrancy sidebar on the left, borderless editorial canvas on the right,
/// and a subtle floating frosted-glass control capsule anchored at the bottom.
struct DashboardView: View {
    @EnvironmentObject private var store: ChargerStore
    @EnvironmentObject private var updater: UpdateChecker
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: SidebarDestination = .overview
    @State private var confirmingStrategy: ChargingStrategy?

    init(initialSelection: SidebarDestination = .overview) {
        _selection = State(initialValue: initialSelection)
    }

    private var canvasBg: Color { KCStyle.canvasBackground(for: colorScheme) }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 205, ideal: 226, max: 260)
        } detail: {
            ZStack(alignment: .bottom) {
                detailCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(canvasBg)

                // Soft ceramic fade scrim & floating capsule (hidden on Controls canvas to avoid overlapping sliders)
                if selection != .controls {
                    LinearGradient(
                        colors: [canvasBg.opacity(0), canvasBg.opacity(0.88), canvasBg],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 82)
                    .allowsHitTesting(false)
                }

                VStack(spacing: 10) {
                    if let toast = store.toast {
                        ToastPill(toast: toast)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if selection != .controls {
                        FloatingControlBar(confirmingStrategy: $confirmingStrategy)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: selection)
                .padding(.bottom, 14)
                .padding(.horizontal, 20)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task { await store.refreshAll() }
                } label: {
                    Label(L("Refresh", "刷新"), systemImage: "arrow.clockwise")
                }
                .help(L("Refresh now (⌘R)", "立即刷新 (⌘R)"))

                SettingsLink {
                    Label(L("Settings", "设置"), systemImage: "gearshape")
                }
                .help(L("Settings (⌘,)", "设置 (⌘,)"))
            }
        }
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

    // MARK: - Sidebar (macOS Vibrancy)

    private var sidebar: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: SidebarDestination.overview) {
                    Label {
                        Text(L("Overview", "总览"))
                    } icon: {
                        Image(systemName: "bolt.circle").foregroundStyle(.secondary)
                    }
                }
                NavigationLink(value: SidebarDestination.energy) {
                    HStack {
                        Label {
                            Text(L("Daily Energy", "每日用电"))
                        } icon: {
                            Image(systemName: "calendar").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(KCFormat.energy(wattHours: store.energySummary.todayWattHours))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                NavigationLink(value: SidebarDestination.controls) {
                    Label {
                        Text(L("Controls", "设备控制"))
                    } icon: {
                        Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
                    }
                }
                NavigationLink(value: SidebarDestination.device) {
                    Label {
                        Text(L("Hardware", "硬件信息"))
                    } icon: {
                        Image(systemName: "cpu").foregroundStyle(.secondary)
                    }
                }
            }

            Section(L("Ports", "端口")) {
                ForEach(store.ports) { port in
                    NavigationLink(value: SidebarDestination.port(port.index)) {
                        HStack(spacing: 8) {
                            Image(systemName: DeviceSymbol.systemName(for: port))
                                .font(.system(size: 13))
                                .foregroundStyle(port.isCharging ? .primary : .secondary)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(port.deviceName ?? KCFormat.portDisplayName(port))
                                    .font(.callout)
                                    .foregroundStyle(port.enabled ? .primary : .secondary)
                                    .lineLimit(1)
                                if port.deviceName != nil {
                                    Text(KCFormat.portDisplayName(port))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            Spacer(minLength: 4)

                            if port.isCharging {
                                Text("\(KCFormat.watts(port.power)) W")
                                    .font(.caption.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Circle()
                                    .fill(KCStyle.charging)
                                    .frame(width: 5, height: 5)
                            } else if !port.enabled {
                                Text(L("Off", "关"))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    StatusDot(connection: store.connection)
                    Text(store.deviceName)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }
                HStack(spacing: 4) {
                    Text(store.facts.localizedName)
                    if store.isDemo {
                        Text("·")
                        Text(L("Sample", "示例"))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Detail Canvas Router

    @ViewBuilder
    private var detailCanvas: some View {
        switch selection {
        case .overview:
            OverviewCanvas(onSelectPort: { selection = .port($0.index) })
        case .energy:
            EnergyCalendarCanvas()
        case .controls:
            ControlsCanvas()
        case .device:
            DeviceInfoCanvas()
        case .port(let index):
            PortDetailCanvas(portIndex: index)
        }
    }
}

// MARK: - Overview Canvas (Borderless Editorial Layout)

struct OverviewCanvas: View {
    var onSelectPort: (PortSnapshot) -> Void

    var body: some View {
        ScrollView {
            OverviewBody(onSelectPort: onSelectPort)
        }
    }
}

struct OverviewBody: View {
    @EnvironmentObject private var store: ChargerStore
    @EnvironmentObject private var updater: UpdateChecker
    var onSelectPort: (PortSnapshot) -> Void

    private var fraction: Double {
        store.maxPower > 0 ? store.totalPower / store.maxPower : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if case .available(let version, let url, _) = updater.status {
                UpdateBanner(version: version, url: url)
            }

            // Editorial page title
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Overview", "总览"))
                        .font(.system(size: 26, weight: .bold))
                    Text(overviewSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

                // Borderless hero power (circular ring gauge) + live curve
                HStack(alignment: .center, spacing: 32) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .center, spacing: 18) {
                            ZStack {
                                Circle()
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                                Circle()
                                    .trim(from: 0, to: fraction)
                                    .stroke(
                                        KCStyle.accent,
                                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                                    .animation(.easeInOut(duration: 0.35), value: fraction)
                                VStack(spacing: 0) {
                                    Text("\(Int((fraction * 100).rounded()))%")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                    Text(L("of \(Int(store.maxPower))W", "/ \(Int(store.maxPower))W"))
                                        .font(.system(size: 9.5, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                        .monospacedDigit()
                                }
                            }
                            .frame(width: 76, height: 76)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(KCFormat.watts(store.totalPower))
                                        .font(.system(size: 50, weight: .medium, design: .rounded))
                                        .monospacedDigit()
                                        .contentTransition(.numericText(value: store.totalPower))
                                    Text("W")
                                        .font(.system(size: 20, weight: .regular, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Text(L(
                                    "\(KCFormat.watts(max(store.maxPower - store.totalPower, 0))) W headroom free",
                                    "剩余可用余量 \(KCFormat.watts(max(store.maxPower - store.totalPower, 0))) W"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            }
                        }

                        HStack(spacing: 22) {
                            EditorialStat(label: L("Charging", "充电中"), value: "\(store.snapshot?.chargingCount ?? 0) of \(store.facts.ports.count)")
                            EditorialStat(label: L("Session", "本次累计"), value: store.sessionEnergyMwh > 0 ? KCFormat.energy(mWh: store.sessionEnergyMwh) : "—")
                            EditorialStat(label: L("Today", "今日用电"), value: KCFormat.energy(wattHours: store.energySummary.todayWattHours))
                        }
                    }
                    .frame(width: 316, alignment: .leading)

                    liveChart
                        .frame(maxWidth: .infinity)
                }

                Divider().opacity(0.6)

                // Ports stream (no heavy card boxes, Apple Music track-list cadence)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L("Ports", "端口"))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text(L("Select a port for PD & cable telemetry", "点按任意端口查看 PD 协议与线材详情"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(spacing: 2) {
                        ForEach(store.ports) { port in
                            PortListRow(port: port, onSelect: { onSelectPort(port) })
                        }
                    }
                }

                Divider().opacity(0.6)

                // Daily Energy Heatmap integrated cleanly on canvas
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(L("Daily Energy", "每日用电量"))
                            .font(.title3.weight(.semibold))
                        Spacer()
                        if EnergyLedger.shared.isCloudAvailable && AppConfig.iCloudEnergySyncEnabled {
                            Label(L("Synced via iCloud", "iCloud 同步"), systemImage: "icloud")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L("Last 46 weeks", "近 46 周"))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    EnergyHeatmapView(
                        summary: EnergySummary(
                            days: Array(store.energySummary.days.suffix(46 * 7)),
                            todayKey: store.energySummary.days.last?.dayKey ?? ""
                        ),
                        tint: KCStyle.charging,
                        cellSpacing: 3.5,
                        cornerRadius: 3,
                        maxCellSize: 12.5,
                        interactive: true,
                        showLegend: true,
                        showHeader: true
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 86) // Breathing room above floating glass bar
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewSubtitle: String {
        var parts = [store.facts.localizedName]
        if let version = store.info?.appVersion { parts.append("Firmware \(version)") }
        if let updated = store.lastUpdated {
            parts.append(L("Updated \(updated.formatted(date: .omitted, time: .shortened))", "更新于 \(updated.formatted(date: .omitted, time: .shortened))"))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var liveChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("Live Load", "实时曲线"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let peak = store.totalHistory.map(\.watts).max(), peak > 0 {
                    Text(L("Peak \(KCFormat.watts(peak)) W", "峰值 \(KCFormat.watts(peak)) W"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            if store.totalHistory.count >= 2 {
                let peakY = max((store.totalHistory.map(\.watts).max() ?? 100) * 1.25, 40)
                Chart(store.totalHistory, id: \.date) { point in
                    AreaMark(x: .value("Time", point.date), y: .value("Watts", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [KCStyle.accent.opacity(0.18), KCStyle.accent.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    LineMark(x: .value("Time", point.date), y: .value("Watts", point.watts))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(KCStyle.accent)
                        .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
                .chartYScale(domain: 0...peakY)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.primary.opacity(0.07))
                        AxisValueLabel {
                            if let w = value.as(Double.self), w > 0 {
                                Text("\(Int(w)) W")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .frame(height: 138)
            } else {
                Text(L("Collecting live readings…", "正在采集数据…"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 138)
            }
        }
    }
}

// MARK: - Dedicated Energy Calendar Canvas

struct EnergyCalendarCanvas: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Daily Energy", "每日用电量"))
                        .font(.system(size: 28, weight: .bold))
                    Text(L("Hardware-metered charging energy accumulated per day.", "基于硬件会话电量精确累加的每日用电日历。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 32) {
                    EditorialHeroMetric(label: L("Today", "今日"), value: KCFormat.energy(wattHours: store.energySummary.todayWattHours), highlight: true)
                    EditorialHeroMetric(label: L("Last 7 Days", "近 7 天"), value: KCFormat.energy(wattHours: store.energySummary.last7DaysWattHours))
                    EditorialHeroMetric(label: L("Peak Day", "单日峰值"), value: KCFormat.energy(wattHours: store.energySummary.peakWattHours))
                    EditorialHeroMetric(label: L("Active Streak", "连续天数"), value: L("\(store.energySummary.currentStreak) days", "\(store.energySummary.currentStreak) 天"))
                    Spacer()
                }

                Divider().opacity(0.6)

                EnergyHeatmapView(
                    summary: store.energySummary,
                    tint: KCStyle.charging,
                    cellSpacing: 4,
                    cornerRadius: 3.5,
                    maxCellSize: 13,
                    interactive: true,
                    showLegend: true,
                    showHeader: true,
                    showAxisLabels: true
                )

                Divider().opacity(0.6)

                EnergyEquivalentsCard(totalWattHours: store.energySummary.totalWattHours)

                Divider().opacity(0.6)

                HStack(alignment: .top, spacing: 28) {
                    PortEnergyDonutChart(shares: store.energyAnalytics.portShares)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    EnergyTimePatternChart(analytics: store.energyAnalytics)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider().opacity(0.6)

                HStack(spacing: 10) {
                    Image(systemName: EnergyLedger.shared.isCloudAvailable && AppConfig.iCloudEnergySyncEnabled ? "icloud" : "internaldrive")
                        .foregroundStyle(.secondary)
                    Text(
                        EnergyLedger.shared.isCloudAvailable && AppConfig.iCloudEnergySyncEnabled
                            ? L("Daily totals stay synced across your Mac and iPhone through your private iCloud Key-Value Store.", "每日电量通过你的私有 iCloud 自动在 Mac 与 iPhone 间合并同步。")
                            : L("Stored locally on this Mac. Enable iCloud Sync in signed builds to share this heatmap with iPhone.", "数据保存在本机。开启 iCloud 签名构建后可与 iPhone 同步热力图。")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Apple Music-Style Floating Frosted Control Capsule

struct FloatingControlBar: View {
    @EnvironmentObject private var store: ChargerStore
    @Binding var confirmingStrategy: ChargingStrategy?

    var body: some View {
        HStack(spacing: 14) {
            // Left: Live summary
            HStack(spacing: 8) {
                StatusDot(connection: store.connection)
                Text("\(KCFormat.watts(store.totalPower)) W")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(store.lastStrategy?.localizedName ?? L("Smart", "自由流"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 16)

            // Center: Restrained quick mode switcher
            HStack(spacing: 4) {
                ForEach([ChargingStrategy.fast, .slow, .highPerformance]) { strategy in
                    let selected = store.lastStrategy == strategy
                    Button {
                        if strategy.needsConfirmation { confirmingStrategy = strategy }
                        else { store.setStrategy(strategy) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: strategy.symbol)
                                .font(.caption2)
                            Text(strategy.localizedName)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(selected ? Color.primary.opacity(0.11) : Color.clear)
                        )
                        .foregroundStyle(selected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.busy.contains("strategy"))
                }
            }

            Divider().frame(height: 16)

            // Right: Thermal toggle
            if let thermal = store.temperatureMode {
                Button {
                    store.setTemperature(thermal == .power ? .temperature : .power)
                } label: {
                    Label(thermal.localizedName, systemImage: thermal.symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(store.busy.contains("temperature"))
                .help(L("Toggle thermal mode", "切换温控策略"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}

// MARK: - Editorial Typography Helpers

struct EditorialStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }
}

struct EditorialHeroMetric: View {
    let label: String
    let value: String
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? KCStyle.charging : .primary)
        }
    }
}

struct StatusDot: View {
    var connection: ChargerStore.Connection

    private var color: Color {
        switch connection {
        case .online: return KCStyle.charging
        case .connecting: return KCStyle.caution
        case .offline: return .secondary
        }
    }

    private var label: String {
        switch connection {
        case .online: return L("Live via MCP", "MCP 在线")
        case .connecting: return L("Connecting…", "连接中…")
        case .offline(let msg): return msg
        }
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .help(label)
    }
}

struct UpdateBanner: View {
    let version: String
    let url: URL

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(KCStyle.accent)
            Text(L("SugarWatt \(version) is available.", "发现新版本 SugarWatt \(version)。"))
                .font(.callout.weight(.medium))
            Spacer()
            Link(L("Download", "前往下载"), destination: url)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(KCStyle.accent.opacity(0.08)))
    }
}

struct ToastPill: View {
    var toast: ChargerStore.Toast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? KCStyle.hot : KCStyle.charging)
            Text(toast.message)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.75))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}
