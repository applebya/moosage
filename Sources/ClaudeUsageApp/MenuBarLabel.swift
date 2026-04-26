import SwiftUI
import ClaudeUsageCore

struct MenuBarLabel: View {
    let snapshot: UsageSnapshot

    var body: some View {
        HStack(spacing: 4) {
            BatteryIconView(fill: snapshot.fillRatio)
                .frame(width: 24, height: 12)
            Text(snapshot.resetTimeShort)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}
