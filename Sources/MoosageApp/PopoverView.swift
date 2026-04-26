import SwiftUI
import MoosageCore

struct PopoverView: View {
    @EnvironmentObject var store: UsageStore
    @StateObject private var launch = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !store.hasInitialLoad {
                loadingView
            } else {
                providerRow
            }

            Divider()
            footer
        }
        .padding(14)
        .frame(width: 540)
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

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Reading your usage…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var providerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            providerColumn(snap: store.claudeSnapshot, accent: .orange, planControl: AnyView(claudePlanPicker))
            Divider()
            providerColumn(snap: store.codexSnapshot, accent: .green, planControl: nil)
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
        .frame(maxWidth: 90)
    }

    @ViewBuilder
    private func providerColumn(
        snap: ProviderSnapshot,
        accent: Color,
        planControl: AnyView?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(snap.providerName)
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let planControl { planControl }
            }
            if let plan = snap.planName {
                Text(plan)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if snap.primaryResetTime == nil {
                Text(snap.isStale ? "No recent activity" : "Waiting for first event…")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            } else {
                primarySection(snap)
                if snap.weeklyFillRatio != nil {
                    weeklySection(snap)
                        .padding(.top, 4)
                }
                if let last = snap.lastActivity {
                    Text("Last activity \(Formatters.relative(last))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .frame(minWidth: 230, alignment: .topLeading)
    }

    private func primarySection(_ snap: ProviderSnapshot) -> some View {
        let pct = Int((snap.primaryFillRatio * 100).rounded())
        return VStack(alignment: .leading, spacing: 4) {
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
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(Formatters.compactTokens(used)) tokens")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if let reset = snap.primaryResetTime {
                let remaining = reset.timeIntervalSince(snap.generatedAt)
                Text("Resets in \(Formatters.remaining(remaining)) (\(Formatters.clockTime(reset)))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func weeklySection(_ snap: ProviderSnapshot) -> some View {
        let weekly = snap.weeklyFillRatio ?? 0
        let pct = Int((weekly * 100).rounded())
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Weekly").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Text("\(pct)%")
                    .font(.caption2.monospacedDigit())
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
