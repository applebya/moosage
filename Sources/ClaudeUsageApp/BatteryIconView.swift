import SwiftUI

struct BatteryIconView: View {
    let fill: Double // 0…1

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bodyWidth = w * 0.86
            let nubWidth = w * 0.08
            let nubHeight = h * 0.45
            let strokeW: CGFloat = max(1, h * 0.08)
            let inset: CGFloat = strokeW + 1

            ZStack(alignment: .leading) {
                // Body outline
                RoundedRectangle(cornerRadius: h * 0.22, style: .continuous)
                    .stroke(Color.primary, lineWidth: strokeW)
                    .frame(width: bodyWidth, height: h)

                // Inner fill
                RoundedRectangle(cornerRadius: max(0, h * 0.12), style: .continuous)
                    .fill(fillColor)
                    .frame(
                        width: max(0, (bodyWidth - inset * 2) * CGFloat(clampedFill)),
                        height: h - inset * 2
                    )
                    .padding(.leading, inset)

                // Nub on the right of the body
                RoundedRectangle(cornerRadius: nubWidth * 0.4, style: .continuous)
                    .fill(Color.primary)
                    .frame(width: nubWidth, height: nubHeight)
                    .offset(x: bodyWidth, y: (h - nubHeight) / 2)
            }
            .frame(width: w, height: h, alignment: .leading)
        }
    }

    private var clampedFill: Double { min(max(fill, 0), 1) }

    private var fillColor: Color {
        switch clampedFill {
        case ..<0.10: return .red
        case ..<0.25: return .yellow
        default:      return .primary
        }
    }
}
