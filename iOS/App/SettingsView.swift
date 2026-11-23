import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var disconnecting = false
    private var nickname: Binding<String> {
        Binding(get: { AppConfig.customDeviceName ?? "" }, set: { model.rename($0) })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Device") {
                    TextField("Device nickname", text: nickname)
                    LabeledContent("Model", value: SnapshotStore.loadFacts()?.localizedName ?? model.snapshot?.modelName ?? "—")
                    LabeledContent("Connection", value: ChargerSource.isDemo ? String(localized: "Sample data") : (AppConfig.serverURL?.host ?? "—"))
                    Button("Disconnect", role: .destructive) { disconnecting = true }
                        .disabled(!model.busyPorts.isEmpty || model.controlling)
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Link("Source code on GitHub", destination: URL(string: "https://github.com/LeiZiKang/KangCharge")!)
                    Text("MIT License")
                } header: { Text("About") } footer: { Text("Kang Charge is an independent app and is not affiliated with CANDYSIGN.") }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Disconnect this charger?", isPresented: $disconnecting, titleVisibility: .visible) {
                    Button("Disconnect", role: .destructive) { Task { await model.disconnect(); dismiss() } }
                    Button("Cancel", role: .cancel) {}
                } message: { Text("The saved address and charger data will be removed from this iPhone.") }
        }
    }
}
