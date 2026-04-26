import SwiftUI
import MoosageCore

struct PopoverView: View {
    @EnvironmentObject var store: UsageStore
    @StateObject private var launch = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            providerPanel(
                snap: store.claudeSnapshot,
                accent: .orange,
                planControl: AnyView(claudePlanPicker)
            )

            Divider()

            providerPanel(
                snap: store.codexSnapshot,
                accent: .green,
                planControl: nil
            )

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Moosage")
                .font(.headline)
            Text("🐮")
                .font(.headline)
            Spacer()
        }
    }

    private var claudePlanPicker: some View {
        Picker("", selection: $store.claudePlan) {
            ForEach(Plan.allCases, id: \.self) { p in
                Text(p.displayName).tag(p)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .frame(maxWidth: 110)
    }

    @ViewBuilder
    private func providerPanel(
        snap: ProviderSnapshot,
        accent: Color,
        planControl: AnyView?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(snap.providerName)
                    .font(.system(.subheadline, weight: .semibold))
                if let plan = snap.planName {
                    Text(plan)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let planControl { planControl }
            }

            if snap.primaryResetTime == nil {
                Text(snap.isStale ? "No recent activity" : "Waiting for first event…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                primarySection(snap)
                if snap.weeklyFillRatio != nil {
                    weeklySection(snap)
                }
                if let last = snap.lastActivity {
                    Text("Last activity \(Formatters.relative(last))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func primarySection(_ snap: ProviderSnapshot) -> some View {
        let pct = Int((snap.primaryFillRatio * 100).rounded())
        return VStack(alignment: .leading, spacing: 5) {
            ProgressView(value: snap.primaryFillRatio)
                .progressViewStyle(.linear)
                .tint(barTint(snap.primaryFillRatio))
            HStack {
                Text("\(pct)%")
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .foregroundColor(barTint(snap.primaryFillRatio))
                Spacer()
                if let used = snap.primaryUsedTokens {
                    if let limit = snap.primaryLimitTokens {
                        Text("\(Formatters.compactTokens(used)) / \(Formatters.compactTokens(limit))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(Formatters.compactTokens(used)) tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if let reset = snap.primaryResetTime {
                let remaining = reset.timeIntervalSince(snap.generatedAt)
                Text("Resets in \(Formatters.remaining(remaining))  (at \(Formatters.clockTime(reset)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func weeklySection(_ snap: ProviderSnapshot) -> some View {
        let weekly = snap.weeklyFillRatio ?? 0
        let pct = Int((weekly * 100).rounded())
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Weekly")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(pct)%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            ProgressView(value: weekly)
                .progressViewStyle(.linear)
                .tint(barTint(weekly))
            if let reset = snap.weeklyResetTime {
                Text("Resets \(Formatters.weekday(reset)) at \(Formatters.clockTime(reset))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { launch.isEnabled },
                set: { launch.setEnabled($0) }
            )) {
                Text("Launch at login")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            if let err = launch.lastError {
                Text(err).font(.caption2).foregroundColor(.red)
            }

            HStack(spacing: 8) {
                Button("Refresh") { Task { await store.refresh() } }
                Menu("Open…") {
                    Button("~/.claude") { store.openClaudeFolder() }
                    Button("~/.codex")  { store.openCodexFolder() }
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
    }

    private func barTint(_ ratio: Double) -> Color {
        if ratio >= 0.90 { return .red }
        if ratio >= 0.75 { return .yellow }
        return .accentColor
    }
}
