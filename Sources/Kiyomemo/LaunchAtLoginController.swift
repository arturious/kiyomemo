import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    static let shared = LaunchAtLoginController()

    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var statusMessage: String?

    private static let initialRegistrationAttemptedKey = "launchAtLoginInitialRegistrationAttempted"
    private let service = SMAppService.mainApp

    private init() {
        refresh()
        enableByDefaultIfNeeded()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            statusMessage = nil
        } catch {
            statusMessage = enabled ? "Unable to enable login launch" : "Unable to disable login launch"
        }

        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func enableByDefaultIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.initialRegistrationAttemptedKey) else { return }
        defaults.set(true, forKey: Self.initialRegistrationAttemptedKey)

        guard service.status == .notRegistered else {
            refresh()
            return
        }

        do {
            try service.register()
            statusMessage = nil
        } catch {
            statusMessage = "Enable in System Settings if requested"
        }

        refresh()
    }

    func refresh() {
        let status = service.status
        isEnabled = status == .enabled || status == .requiresApproval
        requiresApproval = status == .requiresApproval
    }
}
