import SwiftUI
import MoosageCore

/// Two side-by-side mini batteries — `[C 94%] [O 18%]` — colored independently.
struct MenuBarLabel: View {
    let claude: ProviderSnapshot
    let codex: ProviderSnapshot

    var body: some View {
        HStack(spacing: 8) {
            providerCell(claude)
            providerCell(codex)
        }
    }

    @ViewBuilder
    private func providerCell(_ snap: ProviderSnapshot) -> some View {
        HStack(spacing: 3) {
            Text(snap.providerLetter)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .opacity(snap.isStale ? 0.45 : 0.85)
            BatteryIconView(fill: snap.primaryFillRatio)
                .frame(width: 22, height: 11)
                .opacity(snap.isStale ? 0.5 : 1.0)
            Text(percentText(snap))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(percentColor(snap))
                .monospacedDigit()
        }
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
