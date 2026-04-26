import Foundation
import SwiftUI
import CoreServices
import ClaudeUsageCore

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot
    @Published var plan: Plan {
        didSet {
            UserDefaults.standard.set(plan.rawValue, forKey: Self.planKey)
            recomputeFromCurrentEntries()
        }
    }

    private static let planKey = "claudeusage.plan"

    private let root: URL
    private var pollTimer: Timer?
    private var eventStream: FSEventStreamRef?
    private var debounceTask: Task<Void, Never>?
    private var lastEntries: [UsageEntry] = []

    init(root: URL = UsageScanner.defaultRoot) {
        self.root = root
        let storedPlanRaw = UserDefaults.standard.string(forKey: Self.planKey) ?? Plan.max5x.rawValue
        let initialPlan = Plan(rawValue: storedPlanRaw) ?? .max5x
        self.plan = initialPlan
        self.snapshot = UsageSnapshot(plan: initialPlan, block: nil, generatedAt: Date())

        Task { await self.refresh() }
        startPolling()
        startFileWatch()
    }

    deinit {
        pollTimer?.invalidate()
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    func refresh() async {
        let rootURL = self.root
        let entries: [UsageEntry] = await Task.detached(priority: .utility) {
            UsageScanner.scan(root: rootURL)
        }.value
        await MainActor.run {
            self.lastEntries = entries
            self.recomputeFromCurrentEntries()
        }
    }

    func openClaudeFolder() {
        NSWorkspace.shared.open(root)
    }

    fileprivate func handleFileSystemEvent() {
        scheduleDebouncedRefresh()
    }

    private func recomputeFromCurrentEntries() {
        let blocks = BlockBuilder.buildBlocks(from: lastEntries)
        let now = Date()
        let block = BlockBuilder.currentBlock(in: blocks, now: now)
        snapshot = UsageSnapshot(plan: plan, block: block, generatedAt: now)
    }

    private func startPolling() {
        // 5s polling: cheap (small file set, streamed parsing) and ensures
        // the menu bar reflects new usage within seconds even if the file
        // watcher misses an event.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
    }

    private func startFileWatch() {
        // Ensure the watched directory exists so FSEventStreamCreate succeeds.
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let paths = [root.path] as CFArray
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
            DispatchQueue.main.async {
                store.handleFileSystemEvent()
            }
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
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // coalesce up to 500ms — keeps the UI responsive without thrashing
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(
            stream,
            DispatchQueue(label: "claudeusage.fsevents", qos: .utility)
        )
        FSEventStreamStart(stream)
        eventStream = stream
    }

    private func scheduleDebouncedRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s coalescing
            if Task.isCancelled { return }
            await self?.refresh()
        }
    }
}
