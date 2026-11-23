import SwiftUI

/// Shared form for pasting the MCP address; used by first-run setup and Settings.
struct ConnectionForm: View {
    @EnvironmentObject private var store: ChargerStore
    @State private var address = AppConfig.serverURL?.absoluteString ?? ""
    @State private var nickname = AppConfig.customDeviceName ?? ""
    @State private var connecting = false
    @State private var error: String?
    var submitTitle = "连接"

    private var url: URL? { AppConfig.validatedServerURL(address) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MCP 服务器地址").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gray)
                TextField("https://mcp.thecandysign.com/…/sse", text: $address, axis: .vertical)
                    .lineLimit(2...3)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(address.isEmpty || url != nil ? Theme.line : Theme.red))
                    .accessibilityIdentifier("serverURL")
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("给它起个名字（可选）").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.gray)
                TextField("例如：书桌小电拼", text: $nickname)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.cream))
                    .accessibilityIdentifier("nickname")
            }
            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                guard let url else { return }
                connecting = true
                error = nil
                Task {
                    defer { connecting = false }
                    do {
                        try await store.connect(to: url, nickname: nickname)
                        store.show("已连接到\(store.deviceName)", isError: false)
                    } catch {
                        self.error = "连接失败：\(error.localizedDescription)。请确认地址完整、小电拼已联网。"
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if connecting { ProgressView().controlSize(.small).tint(.white) }
                    Text(connecting ? "正在连接小电拼…" : submitTitle)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(url == nil ? Theme.lightGray : Theme.orange))
            }
            .buttonStyle(.plain)
            .disabled(url == nil || connecting)
            .keyboardShortcut(.defaultAction)
        }
    }
}

struct SetupView: View {
    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CoCan Mirror").font(.system(size: 12, weight: .heavy).italic()).foregroundStyle(Theme.orange)
                        Text("连接你的小电拼").font(.system(size: 26, weight: .heavy))
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    SetupStep(number: 1, text: "打开手机或 Mac 上的 CANDYSIGN App，进入小电拼的 MCP / AI 接入设置。")
                    SetupStep(number: 2, text: "复制以 /sse 结尾的 MCP 服务器地址。")
                    SetupStep(number: 3, text: "粘贴到下面，点「连接」。Kang Charge 会先读取一次设备信息来确认地址可用。")
                }
                ConnectionForm()
                Label("地址里包含你设备的序列号和访问令牌，只保存在这台 Mac 上，不要分享给别人。", systemImage: "lock.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gray)
            }
            .padding(28)
            .frame(width: 520)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
        }
        .foregroundStyle(Theme.ink)
    }
}

struct SetupStep: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.orange))
            Text(text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
