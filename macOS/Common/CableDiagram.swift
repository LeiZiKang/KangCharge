import SwiftUI

/// The signature CANDYSIGN picture: a row of port chips on top, each wired with an
/// orange cable down into the charger sitting in the bottom-right corner.
struct CableDiagram: View {
    var ports: [PortSnapshot]
    var chipScale: CGFloat = 1
    var chargerScale: CGFloat = 1.6
    var cableWidth: CGFloat = 5
    var animated = false
    var onTap: ((PortSnapshot) -> Void)? = nil

    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let layout = Layout(size: geo.size, count: ports.count, chipScale: chipScale, chargerScale: chargerScale, ports: ports)

            ZStack(alignment: .topLeading) {
                ForEach(Array(ports.enumerated()), id: \.element.id) { i, port in
                    let path = cable(from: layout.chipAnchor(i), to: layout.portCenter(i))
                    path.stroke(port.enabled ? Theme.orange.opacity(port.isCharging ? 1 : 0.75) : Color(hex: 0xE1E1E1),
                                style: StrokeStyle(lineWidth: cableWidth, lineCap: .round))
                    if animated && port.isCharging {
                        path.stroke(Color.white.opacity(0.55),
                                    style: StrokeStyle(lineWidth: cableWidth * 0.35, lineCap: .round, dash: [2, 14], dashPhase: -phase))
                    }
                }

                ChargerIllustration(ports: ports, scale: chargerScale)
                    .frame(width: layout.chargerFrame.width, height: layout.chargerFrame.height)
                    .offset(x: layout.chargerFrame.minX, y: layout.chargerFrame.minY)

                ForEach(Array(ports.enumerated()), id: \.element.id) { i, port in
                    let frame = layout.chipFrame(i)
                    chip(port)
                        .frame(width: frame.width)
                        .offset(x: frame.minX, y: frame.minY)
                }
            }
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { phase = 16 }
        }
    }

    @ViewBuilder
    private func chip(_ port: PortSnapshot) -> some View {
        if let onTap {
            PortChip(port: port, scale: chipScale)
                .contentShape(Rectangle())
                .onTapGesture { onTap(port) }
        } else {
            PortChip(port: port, scale: chipScale)
        }
    }

    private func cable(from start: CGPoint, to end: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            let dy = end.y - start.y
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: start.y + dy * 0.62),
                control2: CGPoint(x: end.x, y: end.y - dy * 0.55)
            )
        }
    }

    struct Layout {
        var size: CGSize
        var count: Int
        var chipScale: CGFloat
        var chargerScale: CGFloat
        var ports: [PortSnapshot]

        var spacing: CGFloat { 10 * chipScale }
        var chipWidth: CGFloat {
            let available = (size.width - spacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
            return min(available, 96 * chipScale)
        }
        var rowOffset: CGFloat {
            let row = chipWidth * CGFloat(count) + spacing * CGFloat(max(count - 1, 0))
            return (size.width - row) / 2
        }
        var chipHeight: CGFloat { 62 * chipScale }

        func chipFrame(_ i: Int) -> CGRect {
            CGRect(x: rowOffset + CGFloat(i) * (chipWidth + spacing), y: 0, width: chipWidth, height: chipHeight)
        }

        func chipAnchor(_ i: Int) -> CGPoint {
            let frame = chipFrame(i)
            return CGPoint(x: frame.midX, y: frame.maxY - 4 * chipScale)
        }

        var chargerFrame: CGRect {
            let s = ChargerIllustration.baseSize
            let w = s.width * chargerScale, h = s.height * chargerScale
            return CGRect(x: size.width - w - 4, y: size.height - h - 4, width: w, height: h)
        }

        func portCenter(_ i: Int) -> CGPoint {
            let local = ChargerIllustration.portCenters(ports: ports, scale: chargerScale)
            let point = i < local.count ? local[i] : .zero
            return CGPoint(x: chargerFrame.minX + point.x, y: chargerFrame.minY + point.y)
        }
    }
}

/// Flat drawing of the charger: cream body, a small status screen and five ports.
struct ChargerIllustration: View {
    static let baseSize = CGSize(width: 112, height: 58)

    var ports: [PortSnapshot]
    var scale: CGFloat = 1

    static func slotSize(_ port: PortSnapshot) -> CGSize {
        port.connector == "A" ? CGSize(width: 14, height: 5) : CGSize(width: 10, height: 5)
    }

    static func portCenters(ports: [PortSnapshot], scale: CGFloat) -> [CGPoint] {
        var x: CGFloat = 12
        return ports.map { port in
            let slot = slotSize(port)
            let center = CGPoint(x: (x + slot.width / 2) * scale, y: 38 * scale)
            x += slot.width + 6
            return center
        }
    }

    var body: some View {
        let centers = Self.portCenters(ports: ports, scale: scale)
        let total = ports.filter(\.enabled).reduce(0) { $0 + $1.power }

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 11 * scale, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFFDF7), Color(hex: 0xEEE7D8)], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 11 * scale, style: .continuous).strokeBorder(Color(hex: 0xDCD3C1), lineWidth: 1))
                .shadow(color: Color(hex: 0x7A5A2A).opacity(0.16), radius: 8 * scale, y: 5 * scale)

            RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                .fill(Theme.ink)
                .frame(width: 30 * scale, height: 13 * scale)
                .overlay(
                    Text("\(Int(total.rounded()))W")
                        .font(.system(size: 6.5 * scale, weight: .heavy))
                        .foregroundStyle(Theme.orange)
                )
                .offset(x: 12 * scale, y: 12 * scale)

            ForEach(Array(ports.enumerated()), id: \.element.id) { i, port in
                let slot = Self.slotSize(port)
                RoundedRectangle(cornerRadius: (port.connector == "A" ? 1 : 2.5) * scale, style: .continuous)
                    .fill(Theme.ink.opacity(0.82))
                    .frame(width: slot.width * scale, height: slot.height * scale)
                    .position(centers[i])
            }
        }
    }
}
