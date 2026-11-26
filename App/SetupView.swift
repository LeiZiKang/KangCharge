import AppKit
import SwiftUI
import KangChargeCore
import KangChargeUI

struct ConnectionForm: View {
    @EnvironmentObject private var store: ChargerStore
    @State private var address = AppConfig.serverURL?.absoluteString ?? ""
    @State private var nickname = AppConfig.customDeviceName ?? ""
    @State private var connecting = false
    @State private var error: String?
    @State private var extractedHint: String?
    var submitTitle = L("Connect", "连接")

    private var url: URL? { AppConfig.validatedServerURL(address) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L("MCP Server URL", "MCP 服务器地址"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        pasteFromClipboard()
                    } label: {
                        Label(L("Paste", "粘贴"), systemImage: "doc.on.clipboard")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(L("Paste and auto-extract the MCP server URL from your clipboard", "从剪贴板粘贴并自动提取 MCP 服务器地址"))
                }

                TextField(L("Paste CANDYSIGN MCP text or https://…/sse", "粘贴制糖工厂复制的整段文本或 https://…/sse"), text: $address, axis: .vertical)
                    .lineLimit(2...3)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.callout, design: .monospaced))
                    .accessibilityIdentifier("serverURL")
                    .onChange(of: address) { _, newValue in
                        if let extracted = AppConfig.extractMCPInput(from: newValue), extracted.extractedFromText {
                            address = extracted.url.absoluteString
                            if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                               let suggested = extracted.suggestedNickname {
                                nickname = suggested
                            }
                            extractedHint = L("Extracted MCP server URL automatically.", "已自动从复制内容中提取 MCP 地址。")
                            error = nil
                        }
                    }

                if let extractedHint {
                    Label(extractedHint, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(KCStyle.charging)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(L("Nickname (optional)", "设备名称（可选）"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField(L("e.g. Desk Charger", "例如：书桌小电拼"), text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("nickname")
            }

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(KCStyle.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button {
                    guard let url else { return }
                    connecting = true
                    error = nil
                    Task {
                        defer { connecting = false }
                        do {
                            try await store.connect(to: url, nickname: nickname)
                            store.show(L("Connected to \(store.deviceName)", "已连接到 \(store.deviceName)"), isError: false)
                        } catch {
                            self.error = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if connecting { ProgressView().controlSize(.small) }
                        Text(connecting ? L("Connecting…", "正在连接…") : submitTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(url == nil || connecting)
                .keyboardShortcut(.defaultAction)

                Spacer()
            }
        }
    }

    private func pasteFromClipboard() {
        guard let raw = NSPasteboard.general.string(forType: .string),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = L("Clipboard is empty.", "剪贴板为空，请先复制 MCP 内容。")
            extractedHint = nil
            return
        }
        if let extracted = AppConfig.extractMCPInput(from: raw) {
            address = extracted.url.absoluteString
            if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let suggested = extracted.suggestedNickname {
                nickname = suggested
            }
            extractedHint = extracted.extractedFromText
                ? L("Extracted MCP server URL from copied text.", "已自动从复制内容中提取 MCP 地址。")
                : L("Pasted MCP server URL.", "已粘贴 MCP 地址。")
            error = nil
        } else {
            address = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            extractedHint = nil
            error = L("Couldn't find an MCP server URL ending in /sse in the clipboard.", "未在剪贴板内容中找到以 /sse 结尾的 MCP 服务器地址。")
        }
    }
}

struct SetupView: View {
    @EnvironmentObject private var store: ChargerStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SugarWatt")
                            .font(.title.weight(.semibold))
                        Text(L("Connect your CANDYSIGN CoCan charger over MCP.", "通过官方 MCP 地址连接你的制糖工厂小电拼。"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SetupStepRow(index: 1, text: L("Open the CANDYSIGN app and locate your charger's MCP settings.", "打开 CANDYSIGN App，进入充电器的 MCP / AI 接入设置。"))
                    SetupStepRow(index: 2, text: L("Tap Copy in the MCP panel — you can copy the entire prompt text as-is.", "在 MCP 页面点复制——直接复制整段文案即可，无需手动截取。"))
                    SetupStepRow(index: 3, text: L("Click Paste below. SugarWatt extracts the /sse URL automatically and verifies once.", "点击下方「粘贴」，SugarWatt 会自动提取 /sse 地址并完成校验。"))
                }

                ConnectionForm()

                Divider()

                HStack {
                    Label(L("Stored locally only. Never uploaded.", "仅保存在本机，不会上传到任何服务器。"), systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Try Sample Data", "体验示例数据")) {
                        store.loadDemo()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.75)
            )
            .frame(maxWidth: 480)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SetupStepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(index)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.primary.opacity(0.08)))
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
