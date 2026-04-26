import SwiftUI
import MoosageCore

/// Two side-by-side mini batteries — `[C 94%] [O 18%]` — colored independently.
/// Uses SF Symbols (not custom GeometryReader shapes) because MenuBarExtra
/// labels don't propagate parent constraints down, which collapses
/// GeometryReader-based custom shapes to zero size.
struct MenuBarLabel: View {
    let claude: ProviderSnapshot
    let codex: ProviderSnapshot
    let isLoading: Bool

    var body: some View {
        if isLoading {
            HStack(spacing: 4) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Moosage")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
        } else {
            HStack(spacing: 8) {
                providerCell(claude)
                providerCell(codex)
            }
        }
    }

    @ViewBuilder
    private func providerCell(_ snap: ProviderSnapshot) -> some View {
        HStack(spacing: 2) {
            Text(snap.providerLetter)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .opacity(snap.isStale ? 0.45 : 0.95)
            BatteryIconView(fill: snap.primaryFillRatio, pointSize: 13)
                .opacity(snap.isStale ? 0.5 : 1.0)
            Text(percentText(snap))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(percentColor(snap))
                .monospacedDigit()
        }
        .fixedSize()
    }

    private func percentText(_ snap: ProviderSnapshot) -> String {
        guard snap.primaryResetTime != nil else { return "—" }
        return "\(Int((snap.primaryFillRatio * 100).rounded()))%"
    }

    private func percentColor(_ snap: ProviderSnapshot) -> Color {
        if snap.isStale || snap.primaryResetTime == nil { return .secondary }
        let f = snap.primaryFillRatio
        if f >= 0.90 { return .red }
        if f >= 0.75 { return .yellow }
        return .primary
    }
}
