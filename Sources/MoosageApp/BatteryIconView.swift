import SwiftUI

/// Battery glyph backed by SF Symbols — renders correctly in MenuBarExtra
/// labels (where GeometryReader-based custom shapes collapse to zero).
struct BatteryIconView: View {
    let fill: Double // 0…1
    var pointSize: CGFloat = 14

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: pointSize, weight: .regular))
            .foregroundColor(tint)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel("Battery \(Int((clamped * 100).rounded()))%")
    }

    private var clamped: Double { min(max(fill, 0), 1) }

    /// Five-step SF Symbol — present in macOS 13+ (SF Symbols 4).
    private var symbol: String {
        switch clamped {
        case 0..<0.13: return "battery.0"
        case ..<0.38:  return "battery.25"
        case ..<0.63:  return "battery.50"
        case ..<0.88:  return "battery.75"
        default:        return "battery.100"
        }
    }

    private var tint: Color {
        if clamped >= 0.90 { return .red }
        if clamped >= 0.75 { return .yellow }
        return .primary
    }
}
