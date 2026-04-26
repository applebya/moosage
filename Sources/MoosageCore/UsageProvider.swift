import Foundation

/// A source of agent usage data (Claude Code, Codex, …).
///
/// Implementations are expected to be cheap to instantiate and safe to call
/// `snapshot()` repeatedly off the main actor. They should not retain UI
/// state — the host (`UsageStore`) handles persistence and refresh cadence.
public protocol UsageProvider: AnyObject, Sendable {
    var id: String { get }              // stable, e.g. "claude" / "codex"
    var displayName: String { get }     // e.g. "Claude Code"
    var letter: String { get }          // single-char menu-bar tag

    /// Filesystem locations this provider reads — used by the host to set
    /// up file-system event watching.
    var watchedPaths: [URL] { get }

    /// Compute the latest snapshot from local sources. Must be safe to call
    /// from a background task. Return `.empty(...)` if no data is available.
    func snapshot(now: Date) -> ProviderSnapshot
}
