import SwiftUI
import AppKit

/// Visual language borrowed from the official CANDYSIGN app:
/// warm cream canvas, white cards, one orange accent, near-black ink.
enum Theme {
    static let orange = Color(hex: 0xFF4600)
    static let orangeSoft = Color(hex: 0xFF4600).opacity(0.10)
    static let cream = Color(hex: 0xF8F5EC)
    static let card = Color.white
    static let ink = Color(hex: 0x121212)
    static let gray = Color(hex: 0x808080)
    static let lightGray = Color(hex: 0xCCCCCC)
    static let line = Color(hex: 0xE8E8E8)
    static let green = Color(hex: 0x00AD38)
    static let amber = Color(hex: 0xFFA51E)
    static let red = Color(hex: 0xE64340)

    static func temperatureColor(_ raw: String?) -> Color {
        switch raw?.lowercased() {
        case "cool": return green
        case "moderate": return amber
        case "warm": return red
        default: return gray
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: opacity)
    }
}

enum Format {
    static func watts(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        return String(format: "%.1f", value)
    }

    static func volts(_ value: Double) -> String { String(format: "%.2fV", value) }
    static func amps(_ value: Double) -> String { String(format: "%.2fA", value) }

    static func energy(mWh: Double) -> String {
        if mWh >= 100_000 { return String(format: "%.0f Wh", mWh / 1000) }
        if mWh >= 1000 { return String(format: "%.1f Wh", mWh / 1000) }
        return String(format: "%.0f mWh", mWh)
    }

    /// Short protocol tag shown under each port, like the official app (PD / FCP …).
    static func protocolTag(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let upper = raw.uppercased()
        if upper.contains("PPS") { return "PPS" }
        if upper.contains("PD") { return "PD" }
        if upper.contains("FCP") { return "FCP" }
        if upper.contains("SCP") { return "SCP" }
        if upper.contains("QC") || upper.contains("QUICK") { return "QC" }
        if upper.contains("AFC") { return "AFC" }
        if upper.contains("LEGACY") || upper.contains("BC") { return "BC1.2" }
        return String(raw.split(separator: " ").first ?? "")
    }

    static func portLabel(_ port: PortSnapshot) -> String {
        port.connector == "A" ? "USB-A" : port.name
    }
}

// MARK: - Shared components

struct CardModifier: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.card))
    }
}

extension View {
    func candyCard(padding: CGFloat = 18, radius: CGFloat = 16) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

/// Orange-outlined port chip: label above, power inside, protocol + limit below the divider.
struct PortChip: View {
    var port: PortSnapshot
    var scale: CGFloat = 1

    private var accent: Color { port.enabled ? Theme.orange : Theme.lightGray }

    var body: some View {
        VStack(spacing: 3 * scale) {
            Text(Format.portLabel(port))
                .font(.system(size: 10 * scale, weight: .bold))
                .foregroundStyle(port.enabled ? Theme.ink : Theme.gray)
            VStack(spacing: 0) {
                Text(port.enabled ? "\(Format.watts(port.power))W" : "OFF")
                    .font(.system(size: 15 * scale, weight: .bold))
                    .foregroundStyle(accent)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.vertical, 5 * scale)
                Rectangle().fill(accent.opacity(0.6)).frame(height: 1)
                Text(port.enabled ? Format.protocolTag(port.protocolName) : "\(Int(port.maxPower))W")
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .foregroundStyle(port.enabled ? Theme.ink : Theme.gray)
                    .lineLimit(1)
                    .padding(.vertical, 3 * scale)
            }
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 7 * scale, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 7 * scale, style: .continuous).strokeBorder(accent, lineWidth: 1.5 * scale))
        }
    }
}

/// Orange pill switch in the CANDYSIGN style (also renders in offscreen snapshots,
/// unlike the native NSSwitch).
struct CandyToggle: View {
    @Binding var isOn: Bool
    var label: String = ""
    var scale: CGFloat = 1
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let width = 34 * scale, height = 20 * scale, knob = 16 * scale
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(isOn ? Theme.orange : Color(hex: 0xDEDBD4))
            Circle()
                .fill(Color.white)
                .frame(width: knob, height: knob)
                .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                .padding(2 * scale)
        }
        .frame(width: width, height: height)
        .opacity(isEnabled ? 1 : 0.5)
        .contentShape(Capsule())
        .onTapGesture {
            guard isEnabled else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isOn.toggle() }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "开" : "关")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if isEnabled { isOn.toggle() } }
    }
}
