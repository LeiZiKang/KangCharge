import SwiftUI

/// Visual language for the iOS app and widgets: system materials, one warm accent,
/// green for "delivering power", quiet grays for idle and off.
enum KC {
    static let accent = Color(red: 1.0, green: 0.45, blue: 0.10)
    static let charging = Color(red: 0.20, green: 0.78, blue: 0.35)

    static func tint(for port: PortSnapshot) -> Color {
        if !port.enabled { return .secondary.opacity(0.5) }
        return port.isCharging ? charging : .secondary
    }

    static func temperatureColor(_ raw: String?) -> Color {
        switch raw?.lowercased() {
        case "cool": return charging
        case "moderate": return .orange
        case "warm": return .red
        default: return .secondary
        }
    }
}

enum Fmt {
    /// "58.2" below 100 W, "140" above, no trailing unit.
    static func watts(_ value: Double) -> String {
        value >= 100 || value == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    static func volts(_ value: Double) -> String { String(format: "%.1f V", value) }
    static func amps(_ value: Double) -> String { String(format: "%.2f A", value) }

    /// Short charging-protocol tag: PD, PPS, QC …
    static func protocolTag(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let upper = raw.uppercased()
        for tag in ["PPS", "PD", "FCP", "SCP", "AFC"] where upper.contains(tag) { return tag }
        if upper.contains("QC") || upper.contains("QUICK") { return "QC" }
        if upper.contains("LEGACY") || upper.contains("BC") { return "BC 1.2" }
        return raw.split(separator: " ").first.map(String.init)
    }

    static func portName(_ port: PortSnapshot) -> String {
        port.connector == "A" && port.name == "A" ? "A" : port.name
    }
}

/// Thin horizontal meter used for total load and per-port load.
struct LoadBar: View {
    var fraction: Double
    var color: Color = KC.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color)
                    .frame(width: max(fraction > 0 ? height : 0, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}
