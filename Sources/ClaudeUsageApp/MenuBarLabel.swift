import SwiftUI
import ClaudeUsageCore

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 5) {
            BatteryIconView(fill: snapshot.fillRatio)
                .frame(width: 28, height: 13)
            Text(percentText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(percentColor)
                .monospacedDigit()
        }
    }

    private var percentText: String {
        guard snapshot.block != nil else { return "—" }
        let pct = Int((snapshot.fillRatio * 100).rounded())
        return "\(pct)%"
    }

    private var percentColor: Color {
        let f = snapshot.fillRatio
        if f >= 0.90 { return .red }
        if f >= 0.75 { return .yellow }
        return .primary
    }
}
