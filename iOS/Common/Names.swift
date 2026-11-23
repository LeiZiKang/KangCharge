import Foundation

// English-first, localizable names for the iOS and watchOS UI. The shared models
// keep their original (Chinese) strings for the macOS app.

extension ChargingStrategy {
    var name: String {
        switch self {
        case .fast: return String(localized: "Smart")
        case .slow: return String(localized: "Sleep")
        case .usbA: return String(localized: "Small Appliance")
        case .highPerformance: return String(localized: "Performance")
        case .singlePort: return String(localized: "C1 Only")
        }
    }

    var summary: String {
        switch self {
        case .fast: return String(localized: "Power follows each device. Best for everyday use.")
        case .slow: return String(localized: "Gentle output on every port. Cool and quiet for the night.")
        case .usbA: return String(localized: "C4 behaves like a USB-A port for fans and lamps. Ports reconnect when you switch.")
        case .highPerformance: return String(localized: "Maximum efficiency for a quick top-up.")
        case .singlePort: return String(localized: "Only C1 delivers power, up to 140 W. The other ports turn off.")
        }
    }
}

extension TemperatureMode {
    var name: String {
        self == .power ? String(localized: "Power First") : String(localized: "Cool First")
    }
}

enum Temperature {
    static func name(_ raw: String?) -> String? {
        switch raw?.lowercased() {
        case "cool": return String(localized: "Cool")
        case "moderate": return String(localized: "Warm")
        case "warm": return String(localized: "Hot")
        default: return nil
        }
    }
}

extension MCPError {
    /// English-first message for the iOS UI (the shared `errorDescription` is Chinese for macOS).
    var message: String {
        switch self {
        case .badURL: return String(localized: "That address doesn't look right.")
        case .notConfigured: return String(localized: "Open Kang Charge to connect your charger.")
        case .timeout: return String(localized: "The charger didn't respond in time.")
        case .disconnected: return String(localized: "Lost the connection to the charger.")
        case .http(let code): return String(localized: "The server returned HTTP \(code).")
        case .server(let text): return String(localized: "Server error: \(text)")
        case .tool(let text): return String(localized: "The charger reported an error: \(text)")
        case .decoding: return String(localized: "Couldn't read the charger's response.")
        }
    }
}

func describe(_ error: Error) -> String {
    if let error = error as? MCPError { return error.message }
    if let error = error as? URLError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost: return String(localized: "You're offline.")
        case .timedOut: return String(localized: "The charger didn't respond in time.")
        default: break
        }
    }
    return error.localizedDescription
}
