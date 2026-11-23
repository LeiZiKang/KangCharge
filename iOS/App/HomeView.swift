import SwiftUI
import Charts

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var settings = false
    @State private var detail: PortSnapshot?
    @State private var pendingOff: PortSnapshot?
    var body: some View {
        NavigationStack {
            List {
                if let snapshot = model.snapshot {
                    Section { hero(snapshot) }
                    Section("Ports") {
                        ForEach(snapshot.ports) { port in
                            HStack(spacing: 12) {
                                Button { detail = port } label: {
                                    HStack(spacing: 12) {
                                        PortBadge(port: port)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(port.deviceName ?? (port.enabled ? String(localized: "Idle") : String(localized: "Off")))
                                                .foregroundStyle(.primary)
                                            if port.isCharging { Text(portSubtitle(port)).font(.caption).foregroundStyle(.secondary) }
                                        }
                                        Spacer(minLength: 0)
                                        Text("\(Fmt.watts(port.power)) W").monospacedDigit().foregroundStyle(KC.tint(for: port))
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                Toggle("Enable \(port.name)", isOn: Binding(get: { port.enabled }, set: { on in
                                    if !on && port.isCharging { pendingOff = port }
                                    else { Task { await model.setPort(port.index, on: on) } }
                                })).labelsHidden().tint(KC.charging).fixedSize()
                                    .disabled(model.busyPorts.contains(port.index))
                            }.padding(.vertical, 4)
                        }
                    }
                    Section("Charging") {
                        NavigationLink { ModePickerView() } label: {
                            LabeledContent("Mode", value: model.strategy?.name ?? String(localized: "Not set"))
                        }
                        VStack(alignment: .leading) {
                            Text("Thermal").font(.subheadline)
                            Picker("Thermal", selection: Binding(get: { model.thermal }, set: { value in Task { await model.setThermal(value) } })) {
                                ForEach(TemperatureMode.allCases) { Text($0.name).tag($0) }
                            }.pickerStyle(.segmented).disabled(model.controlling)
                        }
                    }
                    Section {} footer: { Text("Add the Kang Charge widget to your Home Screen or Lock Screen to see power at a glance.") }
                } else {
                    Section {
                        if let error = model.lastError {
                            ContentUnavailableView { Label("Charger Offline", systemImage: "wifi.exclamationmark") } description: { Text(error) } actions: {
                                Button("Try Again") { Task { await model.refresh() } }
                            }
                        } else { ProgressView("Loading charger…") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(model.snapshot?.deviceName ?? AppConfig.deviceName)
            .toolbar { Button("Settings", systemImage: "gearshape") { settings = true } }
            .refreshable { await model.refresh() }
            .sheet(isPresented: $settings) { SettingsView() }
            .sheet(item: $detail) { PortDetailView(port: $0).presentationDetents([.medium]) }
            .confirmationDialog("Turn off \(pendingOff?.name ?? "")?", isPresented: Binding(get: { pendingOff != nil }, set: { if !$0 { pendingOff = nil } }), titleVisibility: .visible) {
                if let port = pendingOff {
                    Button("Turn Off", role: .destructive) { Task { await model.setPort(port.index, on: false) }; pendingOff = nil }
                }
                Button("Cancel", role: .cancel) { pendingOff = nil }
            } message: {
                Text("\(pendingOff?.deviceName ?? String(localized: "The connected device")) will stop charging.")
            }
            .overlay(alignment: .bottom) {
                if let toast = model.toast {
                    Text(toast).font(.callout).padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .padding().accessibilityAddTraits(.updatesFrequently).allowsHitTesting(false)
                }
            }
        }
    }
    private func hero(_ snapshot: ChargerSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.watts(snapshot.totalPower)).font(.system(size: 56, weight: .semibold, design: .rounded))
                    .monospacedDigit().contentTransition(.numericText()).minimumScaleFactor(0.6).lineLimit(1)
                Text("W").font(.title2).foregroundStyle(.secondary)
            }.accessibilityElement(children: .combine)
            Text("of \(Fmt.watts(snapshot.maxPower)) W · \(snapshot.chargingCount) charging").foregroundStyle(.secondary)
            LoadBar(fraction: snapshot.totalPower / max(snapshot.maxPower, 1))
            HStack {
                Circle().fill(model.isOnline ? KC.charging : Color.secondary).frame(width: 6, height: 6)
                if model.isOnline { Text("Live") }
                else { Text("Offline · Updated \(snapshot.fetchedAt, style: .relative)") }
                if ChargerSource.isDemo { Text("Sample data").font(.caption2).padding(.horizontal, 6).padding(.vertical, 3).background(.quaternary, in: Capsule()) }
            }.font(.caption).foregroundStyle(.secondary)
            Chart(Array(snapshot.history.suffix(60)), id: \.date) { point in
                AreaMark(x: .value("Time", point.date), y: .value("Power", point.watts))
                    .foregroundStyle(KC.accent.opacity(0.25).gradient)
                LineMark(x: .value("Time", point.date), y: .value("Power", point.watts)).foregroundStyle(KC.accent)
            }.chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 70)
                .accessibilityLabel("Recent power history")
        }.padding(.vertical, 8)
    }
    private func portSubtitle(_ port: PortSnapshot) -> String {
        [Fmt.protocolTag(port.protocolName), port.voltage > 0 ? Fmt.volts(port.voltage) : nil,
         port.current > 0 ? Fmt.amps(port.current) : nil].compactMap { $0 }.joined(separator: " · ")
    }
}
struct PortBadge: View {
    let port: PortSnapshot
    var body: some View {
        Text(port.name).font(.caption.bold()).frame(width: 36, height: 36)
            .foregroundStyle(port.isCharging ? Color.white : KC.tint(for: port))
            .background { Circle().fill(port.isCharging ? KC.charging : .clear) }
            .overlay { if !port.isCharging { Circle().strokeBorder(KC.tint(for: port), lineWidth: 1) } }
            .opacity(port.enabled ? 1 : 0.5)
    }
}
struct PortDetailView: View {
    let port: PortSnapshot
    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("Voltage", value: Fmt.volts(port.voltage))
                LabeledContent("Current", value: Fmt.amps(port.current))
                LabeledContent("Power", value: "\(Fmt.watts(port.power)) W")
                LabeledContent("Protocol", value: port.protocolName ?? "—")
                LabeledContent("Temperature", value: Temperature.name(port.temperature) ?? "—")
                LabeledContent("Max Power", value: "\(Fmt.watts(port.maxPower)) W")
            }.navigationTitle(port.name).navigationBarTitleDisplayMode(.inline)
        }
    }
}
struct ModePickerView: View {
    @EnvironmentObject var model: AppModel
    @State private var pending: ChargingStrategy?
    var body: some View {
        List(ChargingStrategy.allCases) { strategy in
            Button {
                if strategy.needsConfirmation { pending = strategy }
                else { Task { await model.setStrategy(strategy) } }
            } label: {
                HStack {
                    Image(systemName: strategy.symbol).foregroundStyle(KC.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(strategy.name).foregroundStyle(.primary)
                        Text(strategy.summary).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.strategy == strategy { Image(systemName: "checkmark").foregroundStyle(KC.accent) }
                }.padding(.vertical, 4)
            }.disabled(model.controlling)
        }.navigationTitle("Mode")
            .alert("Change charging mode?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
                Button("Apply") { if let pending { Task { await model.setStrategy(pending) } }; pending = nil }
                Button("Cancel", role: .cancel) { pending = nil }
            } message: { Text(pending?.summary ?? "") }
    }
}
