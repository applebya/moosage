import SwiftUI

struct BatteryIconView: View {
    let fill: Double // 0…1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Apple-ish proportions: body ≈ 88% of width, nub a small bump on the right.
            let bodyWidth = w * 0.88
            let nubWidth = w * 0.06
            let nubHeight = h * 0.42
            let stroke: CGFloat = max(1, h * 0.10)
            let bodyCorner = h * 0.28
            let inset = stroke + 1

            ZStack(alignment: .leading) {
                // Body outline
                RoundedRectangle(cornerRadius: bodyCorner, style: .continuous)
                    .stroke(Color.primary, lineWidth: stroke)
                    .frame(width: bodyWidth, height: h)

                // Inner fill — width scales with usage
                RoundedRectangle(cornerRadius: max(0, bodyCorner - stroke), style: .continuous)
                    .fill(fillColor)
                    .frame(
                        width: max(0, (bodyWidth - inset * 2) * CGFloat(clampedFill)),
                        height: h - inset * 2
                    )
                    .padding(.leading, inset)

                // Nub on the right of the body
                RoundedRectangle(cornerRadius: nubWidth * 0.5, style: .continuous)
                    .fill(Color.primary)
                    .frame(width: nubWidth, height: nubHeight)
                    .offset(x: bodyWidth - 0.5, y: (h - nubHeight) / 2)
            }
            .frame(width: w, height: h, alignment: .leading)
        }
    }

    private var clampedFill: Double { min(max(fill, 0), 1) }

    /// Used-fill color: default tint until 75%, yellow at 75–89%, red at ≥90%.
    private var fillColor: Color {
        switch clampedFill {
        case 0.90...:        return .red
        case 0.75..<0.90:    return .yellow
        default:             return .primary
        }
    }
}
