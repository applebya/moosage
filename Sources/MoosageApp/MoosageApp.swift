import SwiftUI
import MoosageCore

@main
struct MoosageApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(
                claude: store.claudeSnapshot,
                codex: store.codexSnapshot,
                isLoading: !store.hasInitialLoad
            )
        }
        .menuBarExtraStyle(.window)
    }
}
