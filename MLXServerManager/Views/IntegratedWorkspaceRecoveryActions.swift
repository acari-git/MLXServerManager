import SwiftUI

extension IntegratedWorkspaceView {
    func handleRecoveryAction(_ action: RecoveryAction) {
        switch action.kind.rawValue {
        case "openSettings":
            selectedDestination = .settings
        case "openModels":
            selectedDestination = .models
        case "openDownloads":
            selectedDestination = .downloads
        case "openLogs":
            selectedDestination = .logs
        default:
            viewModel.performRecoveryAction(action)
        }
    }
}
