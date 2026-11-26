import SwiftUI
import KangChargeCore

/// Maps connected device names and port types to crisp, restrained Apple SF Symbols.
enum DeviceSymbol {
    static func systemName(for port: PortSnapshot) -> String {
        if !port.enabled { return "power" }
        let name = (port.deviceName ?? "").lowercased()
        if name.contains("macbook") || name.contains("laptop") || name.contains("thinkpad") {
            return "laptopcomputer"
        }
        if name.contains("iphone") || name.contains("phone") || name.contains("pixel") || name.contains("galaxy") {
            return "iphone"
        }
        if name.contains("ipad") || name.contains("tablet") {
            return "ipad"
        }
        if name.contains("watch") {
            return "applewatch"
        }
        if name.contains("airpods") || name.contains("buds") {
            return "airpodspro"
        }
        if name.contains("headphone") || name.contains("max") {
            return "headphones"
        }
        if name.contains("switch") || name.contains("steam") || name.contains("deck") {
            return "gamecontroller"
        }
        if name.contains("camera") {
            return "camera"
        }
        if port.isCharging {
            return "bolt.fill"
        }
        return port.connector == "A" ? "cable.connector" : "bolt.horizontal"
    }
}
