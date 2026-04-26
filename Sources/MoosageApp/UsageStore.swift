import Foundation
import SwiftUI
import CoreServices
import MoosageCore

/// Holds the live `[ProviderSnapshot]` for the UI and orchestrates refresh.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderSnapshot] = []
    @Published var claudePlan: Plan {
        didSet {
            UserDefaults.standard.set(claudePlan.rawValue, forKey: Self.planKey)
            claudeProvider.plan = claudePlan
            Task { await refresh() }
        }
    }

    private static let planKey = "moosage.claude.plan"

    let claudeProvider: ClaudeProvider
    let codexProvider: CodexProvider
    private var providers: [UsageProvider] { [claudeProvider, codexProvider] }

    private var pollTimer: Timer?
    private var eventStreams: [FSEventStreamRef] = []
    private var debounceTask: Task<Void, Never>?

    init() {
        let storedPlanRaw = UserDefaults.standard.string(forKey: Self.planKey) ?? Plan.max5x.rawValue
        let plan = Plan(rawValue: storedPlanRaw) ?? .max5x
        self.claudePlan = plan
        self.claudeProvider = ClaudeProvider(plan: plan)
        self.codexProvider = CodexProvider()

        Task { await self.refresh() }
        startPolling()
        startFileWatch()
    }

    deinit {
        pollTimer?.invalidate()
        for stream in eventStreams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    func snapshot(for providerId: String) -> ProviderSnapshot? {
        snapshots.first { $0.providerId == providerId }
    }

    var claudeSnapshot: ProviderSnapshot {
        snapshot(for: "claude") ?? .empty(providerId: "claude", providerName: "Claude Code", providerLetter: "C", generatedAt: Date())
    }

    var codexSnapshot: ProviderSnapshot {
        snapshot(for: "codex") ?? .empty(providerId: "codex", providerName: "Codex", providerLetter: "O", generatedAt: Date())
    }

    func refresh() async {
        let provs = self.providers
        let now = Date()
        let snaps: [ProviderSnapshot] = await Task.detached(priority: .utility) {
            provs.map { $0.snapshot(now: now) }
        }.value
        await MainActor.run {
            self.snapshots = snaps
        }
    }

    func openClaudeFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString("~/.claude").expandingTildeInPath))
    }

    func openCodexFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: NSString("~/.codex").expandingTildeInPath))
    }

    fileprivate func handleFileSystemEvent() {
        scheduleDebouncedRefresh()
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
    }

    private func startFileWatch() {
        let paths = Array(Set(providers.flatMap { $0.watchedPaths }))
        for url in paths {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        let cfPaths = paths.map { $0.path } as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let store = Unmanaged<UsageStore>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { store.handleFileSystemEvent() }
        }

        let flags = UInt32(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagUseCFTypes
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(
            stream,
            DispatchQueue(label: "moosage.fsevents", qos: .utility)
        )
        FSEventStreamStart(stream)
        eventStreams.append(stream)
    }

    private func scheduleDebouncedRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await self?.refresh()
        }
    }
}
