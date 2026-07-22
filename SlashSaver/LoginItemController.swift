import ServiceManagement

final class LoginItemController {
    enum RegistrationState {
        case disabled
        case enabled
        case requiresApproval
        case unavailable
    }

    var state: RegistrationState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    var isRegistered: Bool {
        state == .enabled || state == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard !isRegistered else { return }
            try SMAppService.mainApp.register()
        } else {
            guard isRegistered else { return }
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
