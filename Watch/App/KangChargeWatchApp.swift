import SwiftUI

@main
struct KangChargeWatchApp: App {
    @StateObject private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchHomeView(model: model)
                .tint(KC.accent)
                .task { model.setActive(scenePhase == .active) }
                .onChange(of: scenePhase) { _, phase in model.setActive(phase == .active) }
        }
    }
}

struct WatchHomeView: View {
    @ObservedObject var model: WatchModel
    @State private var pendingPort: PortSnapshot?

    var body: some View {
        Group {
            if !model.isConfigured {
                VStack(spacing: 12) {
                    Image(systemName: "bolt.fill").font(.largeTitle).foregroundStyle(KC.accent)
                    Text("Open Kang Charge on your iPhone to connect.").font(.footnote).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Button("Try Sample Data") { Task { await model.startDemo() } }
                }.padding()
            } else if let snapshot = model.snapshot {
                NavigationStack {
                TabView {
                    overview(snapshot)
                    List(snapshot.ports) { port in
                        Toggle(isOn: Binding(get: { port.enabled }, set: { on in
                            if !on && port.isCharging { pendingPort = port }
                            else { Task { await model.setPort(port.index, on: on) } }
                        })) {
                            HStack(spacing: 6) {
                                Text(port.name).font(.caption2.bold())
                                    .padding(5).background(KC.tint(for: port).opacity(0.2), in: Circle())
                                VStack(alignment: .leading) {
                                    Text(port.deviceName ?? (port.enabled ? String(localized: "Idle") : String(localized: "Off")))
                                        .font(.caption).lineLimit(1)
                                    Text("\(Int(port.power.rounded())) W").font(.caption2).monospacedDigit()
                                }
                            }
                        }.disabled(!model.busyPorts.isEmpty)
                    }
                }.tabViewStyle(.verticalPage)
                .navigationTitle(snapshot.deviceName)
                }
            } else {
                VStack(spacing: 12) {
                    if model.isOnline { ProgressView() }
                    Text("Waiting for charger readings.").multilineTextAlignment(.center)
                    Button("Refresh Charger") { Task { await model.refresh() } }
                }.padding()
            }
        }
        .confirmationDialog("Turn off this charging port?", isPresented: Binding(
            get: { pendingPort != nil }, set: { if !$0 { pendingPort = nil } }
        ), titleVisibility: .visible) {
            if let port = pendingPort {
                Button("Turn off \(port.name)", role: .destructive) {
                    pendingPort = nil
                    Task { await model.setPort(port.index, on: false) }
                }
            }
            Button("Cancel", role: .cancel) { pendingPort = nil }
        } message: { Text("Charging will stop for the connected device.") }
        .alert("Couldn't update the port.", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK", role: .cancel) { model.errorMessage = nil } }
            message: { Text(model.errorMessage ?? "") }
    }

    private func overview(_ snapshot: ChargerSnapshot) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(KC.accent.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(max(snapshot.totalPower / max(snapshot.maxPower, 1), 0), 1))
                    .stroke(KC.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(Fmt.watts(snapshot.totalPower))
                        .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText()).minimumScaleFactor(0.6).lineLimit(1)
                    Text("of \(Int(snapshot.maxPower)) W").font(.caption2).foregroundStyle(.secondary)
                }.padding(.horizontal, 10)
            }
            .frame(width: 96, height: 96)
            .accessibilityElement(children: .combine)
            Text("\(snapshot.chargingCount) charging").font(.subheadline.weight(.semibold))
            HStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                if model.isOnline && context.date.timeIntervalSince(snapshot.fetchedAt) < 60 {
                    Text("Live").foregroundStyle(KC.charging)
                } else {
                    Text("Updated \(snapshot.fetchedAt, style: .relative) ago").foregroundStyle(.secondary)
                }
            }
            if ChargerSource.isDemo { Text("· Sample").foregroundStyle(.secondary) }
            }.font(.caption2)
        }.padding(.top, 4)
    }
}
