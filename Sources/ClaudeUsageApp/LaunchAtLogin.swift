import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLogin: ObservableObject {
    @Published var isEnabled: Bool
    @Published var lastError: String?

    init() {
        self.isEnabled = (SMAppService.mainApp.status == .enabled)
    }

    func refresh() {
        isEnabled = (SMAppService.mainApp.status == .enabled)
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}
