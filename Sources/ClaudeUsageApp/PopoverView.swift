import SwiftUI
import ClaudeUsageCore

struct PopoverView: View {
    @EnvironmentObject var store: UsageStore
    @StateObject private var launch = LaunchAtLogin()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let block = store.snapshot.block {
                progressSection(block: block)
                Divider()
                modelBreakdown(block: block)
                Divider()
                Text("Last activity \(Formatters.relative(block.lastActivity))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No active 5-hour block")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Send a Claude Code message to start a new window.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("ClaudeUsage")
                .font(.headline)
            Spacer()
            Picker("", selection: $store.plan) {
                ForEach(Plan.allCases, id: \.self) { p in
                    Text(p.displayName).tag(p)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: 110)
        }
    }

    private func progressSection(block: SessionBlock) -> some View {
        let snap = store.snapshot
        let limit = snap.plan.tokensPer5hBlock
        let pct = Int((snap.fillRatio * 100).rounded())
        let remainingInterval = block.remaining(now: snap.generatedAt)
        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: snap.fillRatio)
                .progressViewStyle(.linear)
            HStack {
                Text("\(pct)%")
                    .font(.system(.body, design: .rounded).monospacedDigit())
                Spacer()
                Text("\(Formatters.compactTokens(block.totalTokens)) / \(Formatters.compactTokens(limit)) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("Resets in \(Formatters.remaining(remainingInterval))  (at \(Formatters.clockTime(block.endTime)))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func modelBreakdown(block: SessionBlock) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("By model")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(block.tokensByModel.sorted(by: { $0.value > $1.value }), id: \.key) { row in
                HStack {
                    Text(row.key)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text(Formatters.compactTokens(row.value))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
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
                Text(err)
                    .font(.caption2)
                    .foregroundColor(.red)
            }

            HStack(spacing: 8) {
                Button("Refresh") {
                    Task { await store.refresh() }
                }
                Button("Open ~/.claude") {
                    store.openClaudeFolder()
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .controlSize(.small)
        }
    }
}
