import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel
    @State private var url = ""
    @State private var nickname = ""
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "bolt.fill").font(.largeTitle).foregroundStyle(.white)
                            .frame(width: 72, height: 72).background(KC.accent, in: RoundedRectangle(cornerRadius: 18))
                        Text("Kang Charge").font(.largeTitle.bold())
                        Text("Monitor and control your CANDYSIGN charger.").foregroundStyle(.secondary)
                    }.padding(.vertical)
                }.listRowBackground(Color.clear)
                Section {
                    HStack {
                        TextField("MCP server URL", text: $url).textContentType(.URL).keyboardType(.URL)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                        Button("Paste") { url = UIPasteboard.general.string ?? "" }.buttonStyle(.borderless)
                    }
                    TextField("Nickname (optional)", text: $nickname)
                    Button { Task { await model.connect(urlString: url, nickname: nickname) } } label: {
                        HStack { Spacer(); if model.connecting { ProgressView() }; Text("Connect"); Spacer() }
                    }.buttonStyle(.borderedProminent).disabled(url.isEmpty || model.connecting)
                    if let error = model.lastError { Text(error).font(.callout).foregroundStyle(.red) }
                } footer: { Text("The address stays on this iPhone, in the Keychain.") }
                Section {
                    DisclosureGroup("Where do I find this?") {
                        Text("In the CANDYSIGN app, open your charger's MCP settings and copy the server URL. It looks like https://mcp.thecandysign.com/…/sse.")
                    }
                    Button("Try with Sample Data") { model.startDemo() }.disabled(model.connecting)
                } footer: { Text("Kang Charge is an independent app and is not affiliated with CANDYSIGN.") }
            }.disabled(model.connecting)
        }
    }
}
