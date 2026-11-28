import SwiftUI
import KangChargeCore
import KangChargeUI

// MARK: - Inline Controls Canvas (v2.1 Tactile Hardware Deck)

private enum AllocationPreset: String, CaseIterable, Identifiable {
    case laptop
    case even
    case trio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .laptop: return L("Laptop Priority", "笔记本优先")
        case .even: return L("Split Evenly", "5 口均分")
        case .trio: return L("Desk Trio", "桌搭三口")
        }
    }

    var symbol: String {
        switch self {
        case .laptop: return "laptopcomputer"
        case .even: return "equal.circle"
        case .trio: return "rectangle.3.group"
        }
    }

    var tip: String {
        switch self {
        case .laptop: return L("Dedicates 100 W to C1 for MacBook fast charging, sharing the remaining 60 W with other ports.", "优先给 C1 分配 100 W 供笔记本快充，剩余 60 W 分配给其他端口。")
        case .even: return L("Divides the full 160 W budget equally (32 W each) across all 5 ports.", "将 160 W 总功率平均分配给全部 5 个接口（每口 32 W）。")
        case .trio: return L("Optimized for 3-device desks: 65 W (C1) + 45 W (C2) + 32 W (C3/C4), leaving unused ports off.", "专为三设备桌搭优化：65 W + 45 W + 32 W，闲置接口关闭。")
        }
    }
}

struct ControlsCanvas: View {
    var showBrightnessPreview: Bool = true

    @EnvironmentObject private var store: ChargerStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmingStrategy: ChargingStrategy?
    @State private var allocationValues: [Int: Double] = [:]
    @State private var initialAllocationValues: [Int: Double] = [:]
    @State private var appliedPreset: AllocationPreset? = .even
    @State private var draftPreset: AllocationPreset? = .even
    @State private var hoveredPreset: AllocationPreset?
    @State private var hoveredPriority: StatusDisplayMode?
    @State private var hoveredIdle: IdleDisplay?

    private var allocationTotal: Double { allocationValues.values.reduce(0, +) }
    private var budget: Double { store.maxPower }
    private var overBudget: Bool { allocationTotal > budget }

    private var cardSurface: Color {
        colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.03)
    }

    private var cardBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.08)
    }

    private let primaryStrategies: [ChargingStrategy] = [.fast, .slow, .highPerformance]
    private let specialStrategies: [ChargingStrategy] = [.usbA, .singlePort]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                // 1. Tactile 5-Card Charging Mode Deck (3 + 2 Bento Grid)
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Text(L("Charging Mode", "充电策略"))
                            .font(.headline)
                        Spacer()
                        if store.busy.contains("strategy") {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.mini)
                                Text(L("Applying…", "下发中…"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(primaryStrategies) { strategy in
                                strategyCard(for: strategy)
                            }
                        }
                        HStack(spacing: 10) {
                            ForEach(specialStrategies) { strategy in
                                strategyCard(for: strategy)
                            }
                        }
                    }
                    .disabled(store.busy.contains("strategy"))
                }

                // 2. Compact Single-Row Thermal Policy Strip (zero wasted vertical space)
                compactThermalBar

                // 3. Full-Width Status Display Card (Industrial Brightness Slider + Optional OLED Preview + Hover Tips)
                statusDisplayCard

                // 4. Temporary Power Allocation with Live Stacked Budget Bar & Quick Presets
                powerAllocationCard
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 36)
            .frame(maxWidth: 920, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            if allocationValues.isEmpty {
                distributeEvenly()
                initialAllocationValues = allocationValues
                appliedPreset = .even
                draftPreset = .even
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Controls", "设备控制"))
                    .font(.system(size: 28, weight: .bold))
                Text(L("Charging strategy, thermal policy, status display, and temporary wattage caps.", "充电策略、温控模式、状态屏与临时功率分配。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle()
                    .fill(store.totalPower > 0.5 ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(String(format: "%.1f W", store.totalPower))
                    .monospacedDigit()
                    .fontWeight(.semibold)
                if let strategy = store.lastStrategy {
                    Text("·").foregroundStyle(.tertiary)
                    Text(strategy.localizedName)
                        .foregroundStyle(.secondary)
                }
                if let thermal = store.temperatureMode {
                    Text("·").foregroundStyle(.tertiary)
                    Text(thermal.localizedName)
                        .foregroundStyle(thermalAccent(thermal))
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(cardSurface)
                    .overlay(Capsule().strokeBorder(cardBorder, lineWidth: 1))
            )
        }
    }

    // MARK: - Mode Deck Card (with inline Popover confirm that works in Xcode Previews)

    private func strategyCard(for strategy: ChargingStrategy) -> some View {
        let selected = store.lastStrategy == strategy
        let accent = strategyAccent(strategy)

        return ChargingModeCard(
            strategy: strategy,
            accentColor: accent,
            specBadge: strategySpecBadge(strategy),
            warningHint: strategyWarning(strategy),
            isSelected: selected
        ) {
            if strategy.needsConfirmation && !selected {
                confirmingStrategy = strategy
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    store.setStrategy(strategy)
                }
            }
        }
        .popover(
            isPresented: Binding(
                get: { confirmingStrategy == strategy },
                set: { if !$0 && confirmingStrategy == strategy { confirmingStrategy = nil } }
            ),
            arrowEdge: .top
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: strategy.symbol)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(L("Switch to \(strategy.localizedName)?", "切换到「\(strategy.localizedName)」？"))
                        .font(.headline)
                }
                Text(strategy.localizedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button(L("Cancel", "取消")) {
                        confirmingStrategy = nil
                    }
                    .controlSize(.small)
                    Button(L("Switch Mode", "确认切换")) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            store.setStrategy(strategy)
                        }
                        confirmingStrategy = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .frame(width: 270)
        }
    }

    private func strategyAccent(_ strategy: ChargingStrategy) -> Color {
        switch strategy {
        case .fast: return KCStyle.accent
        case .slow: return Color.indigo
        case .usbA: return Color.teal
        case .highPerformance: return Color.red
        case .singlePort: return Color.orange
        }
    }

    private func strategySpecBadge(_ strategy: ChargingStrategy) -> String {
        switch strategy {
        case .fast: return L("Dynamic", "动态分配")
        case .slow: return L("Quiet · Cool", "静音低温")
        case .usbA: return L("C4 Low-Draw", "小电流")
        case .highPerformance: return L("Max \(Int(budget))W", "满载 \(Int(budget))W")
        case .singlePort: return L("C1 140W Solo", "C1 独享")
        }
    }

    private func strategyWarning(_ strategy: ChargingStrategy) -> String? {
        switch strategy {
        case .usbA: return L("Ports reconnect briefly", "切换时端口会短时重连")
        case .singlePort: return L("Turns off other ports", "会关闭除 C1 外所有端口")
        default: return nil
        }
    }

    // MARK: - Compact Single-Row Thermal Policy Strip

    private func thermalAccent(_ mode: TemperatureMode) -> Color {
        mode == .power ? KCStyle.accent : Color.cyan
    }

    private var compactThermalBar: some View {
        let activeMode = store.temperatureMode ?? .power
        let tint = thermalAccent(activeMode)

        return HStack(spacing: 14) {
            Image(systemName: activeMode.symbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(L("Thermal Policy", "温控策略"))
                    .font(.callout.weight(.semibold))
                Text(activeMode.localizedDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            TactileSegmentedControl(
                options: TemperatureMode.allCases,
                selection: Binding(
                    get: { activeMode },
                    set: { store.setTemperature($0) }
                ),
                title: { $0.localizedName },
                symbol: { $0.symbol },
                accentColor: { thermalAccent($0) },
                tooltip: { $0.localizedDetail }
            )
            .frame(width: 248)
            .disabled(store.temperatureMode == nil || store.busy.contains("temperature"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(tint.opacity(colorScheme == .dark ? 0.065 : 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(tint.opacity(0.28), lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: activeMode)
    }

    // MARK: - Status Display Card (Industrial Slider + Optional OLED Preview + Hover Tips)

    private func priorityAccent(_ mode: StatusDisplayMode) -> Color {
        mode == .animation ? Color.purple : KCStyle.accent
    }

    private func prioritySymbol(_ mode: StatusDisplayMode) -> String {
        mode == .animation ? "sparkles" : "bolt.fill"
    }

    private func priorityTip(_ mode: StatusDisplayMode) -> String {
        mode == .animation
            ? L("Shows ambient idle animations on the charger screen whenever possible.", "优先展示酷炫待机动画，桌面氛围感更强。")
            : L("Keeps real-time wattage and port telemetry front and center on the screen.", "始终优先展示实时功率与端口读数，数据一目了然。")
    }

    private func idleAccent(_ item: IdleDisplay) -> Color {
        switch item {
        case .meteor: return Color.indigo
        case .petals: return Color.pink
        case .life: return Color.mint
        case .clock: return Color.orange
        }
    }

    private func idleTip(_ item: IdleDisplay) -> String {
        switch item {
        case .meteor: return L("Meteor — Drifting starlight trails across the OLED display when idle.", "流星 — 待机时屏幕划过微光流星轨迹。")
        case .petals: return L("Petals — Gentle falling petals ambient animation.", "落花 — 待机时柔和飘落的像素花瓣动画。")
        case .life: return L("Life — Classic Conway's Game of Life evolving pixel grid.", "生命游戏 — 经典的康威生命游戏元胞自动机演化画面。")
        case .clock: return L("Clock — Crisp digital desk clock while your charger is idle.", "时间 — 待机时化身为极简桌面数字时钟。")
        }
    }

    private var statusDisplayCard: some View {
        let currentLevel = DisplayLevel(rawValue: store.display?.level ?? "") ?? .medium
        let currentPriority = StatusDisplayMode(rawValue: store.display?.displayMode ?? "") ?? .power
        let currentIdle = IdleDisplay(rawValue: store.display?.idleDisplay ?? "") ?? .clock

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(L("Status Display", "状态屏"), systemImage: "display")
                    .font(.headline)
                Spacer()
                Text(currentLevel.localizedName)
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(IndustrialBrightnessSlider.color(for: currentLevel).opacity(0.18), in: Capsule())
                    .foregroundStyle(IndustrialBrightnessSlider.color(for: currentLevel))
            }

            // 1. Industrial Brightness Slider (+ optional live OLED brightness preview)
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("Brightness", "屏幕亮度"))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(L("Drag or click LED track", "可拖动滑块或直接点按档位"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    IndustrialBrightnessSlider(
                        level: Binding(
                            get: { currentLevel },
                            set: { store.setDisplayLevel($0) }
                        )
                    )
                }
                .frame(maxWidth: .infinity)

                if showBrightnessPreview {
                    LiveOLEDPreview(
                        level: currentLevel,
                        priority: currentPriority,
                        idle: currentIdle,
                        idleColor: idleAccent(currentIdle),
                        watts: store.totalPower
                    )
                }
            }

            if store.facts.supportsExtendedDisplay {
                Divider().opacity(0.45)

                // 2. Display Priority + Instant Hover Tip
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(L("Priority", "屏显优先"))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        TactileSegmentedControl(
                            options: StatusDisplayMode.allCases,
                            selection: Binding(
                                get: { currentPriority },
                                set: { store.setStatusDisplayMode($0) }
                            ),
                            title: { $0.localizedName },
                            symbol: { prioritySymbol($0) },
                            accentColor: { priorityAccent($0) },
                            tooltip: { priorityTip($0) },
                            onHoverOption: { hoveredPriority = $0 }
                        )
                        .frame(width: 240)
                    }

                    let tipPriority = hoveredPriority ?? currentPriority
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(priorityAccent(tipPriority))
                        Text(priorityTip(tipPriority))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .animation(.easeInOut(duration: 0.15), value: tipPriority)
                }

                // 3. Visual Mini OLED Idle Screen Tiles + Instant Hover Tip
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("Idle Screen", "待机屏保"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(IdleDisplay.allCases) { item in
                            IdleScreenTile(
                                item: item,
                                accentColor: idleAccent(item),
                                tip: idleTip(item),
                                isSelected: currentIdle == item,
                                onHoverChanged: { hovering in
                                    hoveredIdle = hovering ? item : (hoveredIdle == item ? nil : hoveredIdle)
                                }
                            ) {
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                                    store.setIdleDisplay(item)
                                }
                            }
                        }
                    }

                    let tipIdle = hoveredIdle ?? currentIdle
                    HStack(spacing: 6) {
                        Image(systemName: tipIdle.symbol)
                            .font(.caption2)
                            .foregroundStyle(idleAccent(tipIdle))
                        Text(idleTip(tipIdle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .animation(.easeInOut(duration: 0.15), value: tipIdle)
                }

                Divider().opacity(0.45)

                // 4. Hourly Chime with brief helper caption
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Hourly Chime", "整点报时"))
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(L("Plays a gentle tone on the charger at the top of every hour.", "每逢整点时，小电拼发出轻柔提示音报时。"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { store.display?.hourlyChime ?? false },
                        set: { store.setHourlyChime($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardBorder, lineWidth: 1))
        )
        .disabled(store.display == nil)
        .opacity(store.display == nil ? 0.5 : 1)
    }

    // MARK: - Temporary Power Allocation Card (Live 160W Donut Chart + Physical USB-A/C Icons)

    private var hasPendingAllocationChanges: Bool {
        allocationValues != initialAllocationValues
    }

    private var appliedModeLabel: String {
        appliedPreset?.title ?? L("Custom", "自定义")
    }

    private var draftModeLabel: String {
        draftPreset?.title ?? L("Custom", "自定义")
    }

    private var powerAllocationCard: some View {
        let sortedPorts = store.facts.ports.sorted { $0.index < $1.index }
        let freeWatts = max(0, budget - allocationTotal)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Label(L("Temporary Power Allocation", "临时功率分配"), systemImage: "chart.pie.fill")
                            .font(.headline)

                        // Clear hardware-active vs unapplied-preview status badge
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(L("Active: \(appliedModeLabel)", "当前生效：\(appliedModeLabel)"))
                                .font(.system(size: 10.5, weight: .semibold))
                            if hasPendingAllocationChanges {
                                Text("→")
                                    .foregroundStyle(.tertiary)
                                Text(L("Previewing: \(draftModeLabel)", "预览中：\(draftModeLabel)"))
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundStyle(KCStyle.accent)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(hasPendingAllocationChanges ? KCStyle.accent.opacity(0.12) : Color.green.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(hasPendingAllocationChanges ? KCStyle.accent.opacity(0.35) : Color.green.opacity(0.30), lineWidth: 1)
                                )
                        )
                    }
                    Text(L("Cap each port's max wattage within the \(Int(budget)) W total charger budget (active ports ≥ 18 W).", "在 \(Int(budget)) W 总功率上限内为每个接口分配最大功率（开启口 ≥ 18 W）。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(allocationTotal)) / \(Int(budget)) W")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(overBudget ? KCStyle.hot : .secondary)
            }

            // Interactive preset pills: green check = currently applied on hardware; orange outline = previewing draft
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    ForEach(AllocationPreset.allCases) { preset in
                        let isApplied = appliedPreset == preset
                        let isPreviewing = hasPendingAllocationChanges && draftPreset == preset

                        Button {
                            applyPreset(preset)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: preset.symbol)
                                    .font(.caption.weight(.semibold))
                                Text(preset.title)
                                    .font(.caption.weight(.semibold))
                                if isApplied {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(isPreviewing ? Color.white : Color.green)
                                } else if isPreviewing {
                                    Text(L("Preview", "预览"))
                                        .font(.system(size: 9.5, weight: .bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.white.opacity(0.22), in: Capsule())
                                }
                            }
                            .foregroundStyle(isPreviewing ? Color.white : Color.primary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        isPreviewing
                                            ? KCStyle.accent
                                            : (isApplied ? Color.green.opacity(colorScheme == .dark ? 0.14 : 0.10) : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                isPreviewing
                                                    ? KCStyle.accent
                                                    : (isApplied ? Color.green.opacity(0.55) : Color.primary.opacity(0.12)),
                                                lineWidth: (isApplied || isPreviewing) ? 1.2 : 1
                                            )
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                hoveredPreset = hovering ? preset : (hoveredPreset == preset ? nil : hoveredPreset)
                            }
                        }
                        .overlay(alignment: .top) {
                            if hoveredPreset == preset {
                                FloatingHoverTip(
                                    symbol: preset.symbol,
                                    title: preset.title,
                                    message: preset.tip,
                                    accent: isApplied ? Color.green : KCStyle.accent
                                )
                                .offset(y: -86)
                                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                                .allowsHitTesting(false)
                            }
                        }
                        .zIndex(hoveredPreset == preset ? 50 : 1)
                    }

                    // Reset to currently applied allocation state
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                            allocationValues = initialAllocationValues
                            draftPreset = appliedPreset
                        }
                    } label: {
                        Label(L("Reset", "恢复当前"), systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(hasPendingAllocationChanges ? Color.primary : Color.secondary.opacity(0.45))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(hasPendingAllocationChanges ? 0.22 : 0.10), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasPendingAllocationChanges)

                    Spacer()

                    Button(L("Apply Allocation", "应用分配")) {
                        let watts = sortedPorts.map { Int(allocationValues[$0.index] ?? 0) }
                        store.applyAllocation(watts)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            initialAllocationValues = allocationValues
                            appliedPreset = draftPreset
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KCStyle.accent)
                    .disabled(overBudget || allocationTotal == 0 || !hasPendingAllocationChanges)
                }

                // Subtle status/tip footer line
                if let tipPreset = hoveredPreset {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(KCStyle.accent)
                        Text(tipPreset.tip)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if hasPendingAllocationChanges {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.caption2)
                            .foregroundStyle(KCStyle.accent)
                        Text(L("Previewing \(draftModeLabel) — click \"Apply Allocation\" to send to charger, or Reset to revert.", "正在预览「\(draftModeLabel)」——点击「应用分配」下发到小电拼，或点「恢复当前」撤销。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Side-by-side: Live 160W Donut Chart on the left + 5 Port Sliders with distinct colors & USB-A/USB-C icons on the right
            HStack(alignment: .center, spacing: 24) {
                // Pure SwiftUI 160W Donut / Pie Chart (zero Swift Charts SectorMark crash risk)
                PowerBudgetDonut(
                    slices: sortedPorts.enumerated().map { pos, port in
                        PowerBudgetSlice(
                            id: port.index,
                            watts: allocationValues[port.index] ?? 0,
                            color: portColor(at: pos)
                        )
                    },
                    budget: budget,
                    total: allocationTotal,
                    freeWatts: freeWatts,
                    overBudget: overBudget
                )
                .frame(width: 146, height: 146)

                // 5 Port Sliders with physical USB-A / USB-C connector icons and 5 distinct hues
                VStack(spacing: 11) {
                    ForEach(Array(sortedPorts.enumerated()), id: \.element.index) { pos, port in
                        let value = allocationValues[port.index] ?? 0
                        let tint = portColor(at: pos)
                        let isUSBA = port.connectorType == "A"

                        HStack(spacing: 10) {
                            HStack(spacing: 7) {
                                PortConnectorIcon(isUSBA: isUSBA, tint: value > 0 ? tint : .secondary)
                                Text(isUSBA ? "USB-A" : port.name)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(value > 0 ? .primary : .secondary)
                            }
                            .frame(width: 82, alignment: .leading)

                            Slider(value: Binding(
                                get: { value },
                                set: { newValue in
                                    let snapped = newValue < 9 ? 0 : max(18, newValue.rounded())
                                    allocationValues[port.index] = min(snapped, port.power)
                                    draftPreset = nil
                                }
                            ), in: 0...port.power)
                            .tint(tint)

                            Text(value == 0 ? L("Off", "关") : "\(Int(value)) W")
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(value == 0 ? .tertiary : .primary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardBorder, lineWidth: 1))
        )
    }

    private func applyPreset(_ preset: AllocationPreset) {
        draftPreset = preset
        switch preset {
        case .laptop: applyLaptopPriority()
        case .even: distributeEvenly()
        case .trio: applyDeskTrio()
        }
    }

    private func portColor(at position: Int) -> Color {
        // 5 maximally distinct hues across USB-A, C1, C2, C3, C4
        let palette: [Color] = [
            Color(red: 0.22, green: 0.74, blue: 0.97), // USB-A: Sky Cyan
            KCStyle.accent,                             // C1: Ember Orange
            Color(red: 0.66, green: 0.33, blue: 0.97), // C2: Electric Purple
            Color(red: 0.96, green: 0.62, blue: 0.04), // C3: Amber Gold
            Color(red: 0.13, green: 0.77, blue: 0.37)  // C4: Emerald Green
        ]
        return palette[abs(position) % palette.count]
    }

    private func distributeEvenly() {
        let ports = store.facts.ports
        guard !ports.isEmpty else { return }
        let share = (budget / Double(ports.count)).rounded(.down)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            for port in ports { allocationValues[port.index] = min(max(share, 18), port.power) }
        }
    }

    private func applyLaptopPriority() {
        let ports = store.facts.ports.sorted { $0.index < $1.index }
        guard !ports.isEmpty else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            for port in ports { allocationValues[port.index] = 0 }
            var remaining = budget
            if let c1 = ports.first(where: { $0.name.uppercased() == "C1" }) ?? ports.first {
                let cap = min(100, min(c1.power, remaining))
                allocationValues[c1.index] = cap
                remaining -= cap
            }
            for port in ports where (allocationValues[port.index] ?? 0) == 0 && remaining >= 18 {
                let share = min(30, min(port.power, remaining))
                if share >= 18 {
                    allocationValues[port.index] = share.rounded(.down)
                    remaining -= allocationValues[port.index] ?? 0
                }
            }
        }
    }

    private func applyDeskTrio() {
        let ports = store.facts.ports.sorted { $0.index < $1.index }
        guard !ports.isEmpty else { return }
        let targets: [Double] = [65, 45, 32, 18]
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            for port in ports { allocationValues[port.index] = 0 }
            let usbCPorts = ports.filter { $0.connectorType != "A" }
            let ordered = usbCPorts + ports.filter { $0.connectorType == "A" }
            var remaining = budget
            for (idx, port) in ordered.prefix(3).enumerated() {
                let desired = idx < targets.count ? targets[idx] : 18
                let cap = min(desired, min(port.power, remaining))
                if cap >= 18 {
                    allocationValues[port.index] = cap.rounded(.down)
                    remaining -= allocationValues[port.index] ?? 0
                }
            }
        }
    }
}

// MARK: - Pure SwiftUI 160W Donut Chart & Floating Hover Tip Bubble

private struct PowerBudgetSlice: Identifiable {
    let id: Int
    let watts: Double
    let color: Color
}

private struct PowerBudgetDonut: View {
    let slices: [PowerBudgetSlice]
    let budget: Double
    let total: Double
    let freeWatts: Double
    let overBudget: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var denominator: Double {
        max(1, max(budget, total))
    }

    private var segments: [(id: Int, start: Double, end: Double, color: Color)] {
        var cursor = 0.0
        var result: [(Int, Double, Double, Color)] = []
        let gap = 0.008
        for slice in slices where slice.watts > 0 {
            let frac = slice.watts / denominator
            let start = cursor + gap / 2
            let end = max(start, cursor + frac - gap / 2)
            result.append((slice.id, start, end, slice.color))
            cursor += frac
        }
        return result
    }

    var body: some View {
        ZStack {
            // Unallocated track ring
            Circle()
                .stroke(
                    Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08),
                    style: StrokeStyle(lineWidth: 22, lineCap: .butt)
                )

            // Colored port allocation arcs
            ForEach(segments, id: \.id) { seg in
                Circle()
                    .trim(from: seg.start, to: seg.end)
                    .stroke(seg.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 2) {
                Text("\(Int(total)) W")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(overBudget ? KCStyle.hot : .primary)
                if overBudget {
                    Text("+\(Int(total - budget)) W")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KCStyle.hot)
                } else if freeWatts > 0 {
                    Text(L("\(Int(freeWatts))W free", "余 \(Int(freeWatts))W"))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text(L("100% full", "满额分配"))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(11)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: total)
    }
}

/// TipKit-style floating frosted speech bubble shown on mouse hover without stealing focus.
private struct FloatingHoverTip: View {
    let symbol: String
    let title: String
    let message: String
    let accent: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 24, height: 24)
                    .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .frame(width: 240, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(colorScheme == .dark ? Color(white: 0.16) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(accent.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
            )

            // Downward speech-bubble pointer
            TrianglePointer()
                .fill(colorScheme == .dark ? Color(white: 0.16) : Color.white)
                .frame(width: 12, height: 6)
        }
    }
}

private struct TrianglePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Physical USB-A & USB-C Hardware Connector Icon

private struct PortConnectorIcon: View {
    let isUSBA: Bool
    let tint: Color

    var body: some View {
        ZStack {
            if isUSBA {
                // Classic rectangular USB-A receptacle with upper contact block
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(tint, lineWidth: 1.5)
                    .frame(width: 22, height: 11)
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(tint)
                    .frame(width: 15, height: 3)
                    .offset(y: -1.8)
            } else {
                // Sleek pill-shaped USB-C receptacle with centered tongue
                Capsule()
                    .strokeBorder(tint, lineWidth: 1.5)
                    .frame(width: 22, height: 10)
                Capsule()
                    .fill(tint)
                    .frame(width: 12, height: 2.2)
            }
        }
        .frame(width: 24, height: 14)
    }
}

// MARK: - Tactile Charging Mode Card

private struct ChargingModeCard: View {
    let strategy: ChargingStrategy
    let accentColor: Color
    let specBadge: String
    let warningHint: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    private var baseFill: Color {
        if isSelected {
            return accentColor.opacity(colorScheme == .dark ? 0.16 : 0.10)
        }
        if isHovering {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
        return colorScheme == .dark ? Color.white.opacity(0.045) : Color.black.opacity(0.03)
    }

    private var strokeColor: Color {
        if isSelected { return accentColor.opacity(0.85) }
        if isHovering { return colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.16) }
        return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? accentColor : Color.primary.opacity(0.08))
                            .frame(width: 30, height: 30)
                        Image(systemName: strategy.symbol)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.78))
                    }

                    Spacer()

                    Text(specBadge)
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(isSelected ? accentColor.opacity(0.22) : Color.primary.opacity(0.06))
                        )
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                }

                HStack(spacing: 6) {
                    Text(strategy.localizedName)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    if isSelected {
                        Circle()
                            .fill(accentColor)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(strategy.localizedSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let warningHint {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9.5))
                        Text(warningHint)
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(Color.orange)
                    .padding(.top, 1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(baseFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(strokeColor, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isHovering)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Industrial 4-Stop Discrete LED Brightness Slider (1 Block = 1 Hardware State)

private struct IndustrialBrightnessSlider: View {
    @Binding var level: DisplayLevel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDragging = false

    private let levels = DisplayLevel.allCases

    static func color(for level: DisplayLevel) -> Color {
        switch level {
        case .off: return Color.secondary
        case .low: return Color.teal
        case .medium: return Color.orange
        case .high: return KCStyle.accent
        }
    }

    private func stepIndex(for level: DisplayLevel) -> Int {
        levels.firstIndex(of: level) ?? 2
    }

    var body: some View {
        let activeColor = Self.color(for: level)
        let step = stepIndex(for: level)

        VStack(spacing: 8) {
            GeometryReader { geo in
                let count = max(1, levels.count)
                let trackPad: CGFloat = 5
                let spacing: CGFloat = 5
                let cellW = max(1, (geo.size.width - trackPad * 2 - spacing * CGFloat(count - 1)) / CGFloat(count))
                let thumbW: CGFloat = 20
                let thumbCenterX = trackPad + CGFloat(step) * (cellW + spacing) + cellW / 2
                let thumbX = thumbCenterX - thumbW / 2

                ZStack(alignment: .leading) {
                    // 4 honest discrete LED blocks — 1-to-1 with Off / Low / Med / High API stops
                    HStack(spacing: spacing) {
                        ForEach(Array(levels.enumerated()), id: \.element.id) { idx, item in
                            let isLit = (step == 0 && idx == 0) || (step > 0 && idx > 0 && idx <= step)
                            let blockColor = Self.color(for: item)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    isLit
                                        ? (idx == 0 ? Color.secondary.opacity(0.32) : blockColor)
                                        : Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.07)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(
                                            idx == step ? blockColor.opacity(0.85) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: (isLit && idx > 0) ? blockColor.opacity(0.45) : .clear, radius: 4)
                        }
                    }
                    .padding(trackPad)
                    .frame(height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.46) : Color.black.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(activeColor.opacity(step > 0 ? 0.35 : 0.14), lineWidth: 1)
                            )
                    )

                    // Tactile machined slider handle snapped directly to each stop's center
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(colorScheme == .dark ? Color(white: 0.92) : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(activeColor, lineWidth: 1.5)
                        )
                        .overlay(
                            HStack(spacing: 2) {
                                Capsule().fill(activeColor.opacity(0.85)).frame(width: 1.5, height: 11)
                                Capsule().fill(activeColor.opacity(0.85)).frame(width: 1.5, height: 11)
                            }
                        )
                        .frame(width: thumbW, height: 32)
                        .shadow(color: Color.black.opacity(0.32), radius: 4, y: 1)
                        .scaleEffect(isDragging ? 1.07 : 1.0)
                        .offset(x: thumbX)
                        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: step)
                        .animation(.easeOut(duration: 0.12), value: isDragging)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let ratio = min(max(value.location.x / max(1, geo.size.width), 0), 0.999)
                            let idx = Int(ratio * CGFloat(count))
                            let next = levels[min(max(idx, 0), count - 1)]
                            if next != level {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                                    level = next
                                }
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 34)

            HStack(spacing: 5) {
                ForEach(levels) { item in
                    let isSelected = item == level
                    let itemColor = Self.color(for: item)
                    Button {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            level = item
                        }
                    } label: {
                        Text(item.localizedName)
                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? itemColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(isSelected ? itemColor.opacity(0.14) : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Live Miniature OLED Brightness Preview

private struct LiveOLEDPreview: View {
    let level: DisplayLevel
    let priority: StatusDisplayMode
    let idle: IdleDisplay
    let idleColor: Color
    let watts: Double

    private var screenOpacity: Double {
        switch level {
        case .off: return 0.0
        case .low: return 0.36
        case .medium: return 0.72
        case .high: return 1.0
        }
    }

    private var glowRadius: CGFloat {
        switch level {
        case .off: return 0
        case .low: return 2
        case .medium: return 6
        case .high: return 11
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Dark glass hardware bezel
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)
                    )

                if level == .off {
                    Text("OFF")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.18))
                } else if priority == .power {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", watts))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.white)
                        Text("WATTS")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(KCStyle.accent)
                    }
                    .opacity(screenOpacity)
                    .shadow(color: KCStyle.accent.opacity(0.6), radius: glowRadius)
                } else {
                    VStack(spacing: 4) {
                        Image(systemName: idle.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(idleColor)
                        Text(idle.localizedName)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                    .opacity(screenOpacity)
                    .shadow(color: idleColor.opacity(0.75), radius: glowRadius)
                }
            }
            .frame(width: 112, height: 64)
            .animation(.easeInOut(duration: 0.22), value: level)
            .animation(.easeInOut(duration: 0.22), value: priority)
            .animation(.easeInOut(duration: 0.22), value: idle)

            Text(L("OLED Preview", "屏幕亮度预览"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Visual Mini OLED Idle Screen Tile (with Tooltip & Hover Callback)

private struct IdleScreenTile: View {
    let item: IdleDisplay
    let accentColor: Color
    let tip: String
    let isSelected: Bool
    let onHoverChanged: (Bool) -> Void
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black.opacity(colorScheme == .dark ? 0.65 : 0.86))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(isSelected ? accentColor.opacity(0.8) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
                        )
                        .frame(height: 36)
                    Image(systemName: item.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? accentColor : Color.white.opacity(0.55))
                        .shadow(color: isSelected ? accentColor.opacity(0.7) : .clear, radius: 5)
                }

                Text(item.localizedName)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? accentColor : .secondary)
                    .lineLimit(1)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? accentColor.opacity(0.12) : (isHovering ? Color.primary.opacity(0.05) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovering)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tip)
        .onHover { hovering in
            isHovering = hovering
            onHoverChanged(hovering)
        }
    }
}

// MARK: - Smooth Sliding Segmented Control (Per-Option Semantic Color + Hover Tips)

private struct TactileSegmentedControl<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String
    var symbol: ((T) -> String)? = nil
    var accentColor: (T) -> Color = { _ in KCStyle.accent }
    var tooltip: ((T) -> String)? = nil
    var onHoverOption: ((T?) -> Void)? = nil

    @Namespace private var pillNamespace
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options) { option in
                let isSelected = selection == option
                let tint = accentColor(option)
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.82)) {
                        selection = option
                    }
                } label: {
                    HStack(spacing: 5) {
                        if let symbol {
                            Image(systemName: symbol(option))
                                .font(.caption2.weight(.semibold))
                        }
                        Text(title(option))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tint)
                                .matchedGeometryEffect(id: "activeSegment", in: pillNamespace)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tooltip?(option) ?? "")
                .onHover { hovering in
                    onHoverOption?(hovering ? option : nil)
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
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

// MARK: - Xcode Live Previews (Compare With vs Without OLED Brightness Preview)

#Preview("1. Controls · With OLED Preview") {
    ControlsCanvas(showBrightnessPreview: true)
        .environmentObject(ChargerStore(previewDemo: true))
        .frame(width: 960, height: 860)
        .preferredColorScheme(.dark)
}

#Preview("2. Controls · Clean (No OLED Preview)") {
    ControlsCanvas(showBrightnessPreview: false)
        .environmentObject(ChargerStore(previewDemo: true))
        .frame(width: 960, height: 860)
        .preferredColorScheme(.dark)
}

#Preview("3. Controls · Light Mode") {
    ControlsCanvas(showBrightnessPreview: true)
        .environmentObject(ChargerStore(previewDemo: true))
        .frame(width: 960, height: 860)
        .preferredColorScheme(.light)
}
