import Foundation
import SwiftUI
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
    private var fileSource: DispatchSourceFileSystemObject?
    private var watchedFD: Int32 = -1
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
        fileSource?.cancel()
        if watchedFD >= 0 { close(watchedFD) }
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

    private func recomputeFromCurrentEntries() {
        let blocks = BlockBuilder.buildBlocks(from: lastEntries)
        let now = Date()
        let block = BlockBuilder.currentBlock(in: blocks, now: now)
        snapshot = UsageSnapshot(plan: plan, block: block, generatedAt: now)
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { await self.refresh() }
        }
    }

    private func startFileWatch() {
        let path = root.path
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }
        watchedFD = fd

        let queue = DispatchQueue(label: "claudeusage.fswatch", qos: .utility)
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .rename, .delete],
            queue: queue
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.scheduleDebouncedRefresh() }
        }
        src.setCancelHandler { [fd] in close(fd) }
        src.resume()
        fileSource = src
    }

    private func scheduleDebouncedRefresh() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            await self?.refresh()
        }
    }
}
