import Foundation

extension AppViewModel {
    /// Requests that the main workspace show the Settings destination.
    ///
    /// Used by the standard Command-Comma menu command. The request is
    /// delivered through `pendingWorkspaceDestination` so it also works when
    /// the main window has to be reopened first.
    func openSettingsRequested() {
        requestWorkspaceDestination(.settings)
    }

    func requestWorkspaceDestination(_ destination: IntegratedWorkspaceDestination) {
        pendingWorkspaceDestination = destination
    }

    /// Returns and clears the pending destination request, if any.
    @discardableResult
    func consumePendingWorkspaceDestination() -> IntegratedWorkspaceDestination? {
        guard let destination = pendingWorkspaceDestination else {
            return nil
        }
        pendingWorkspaceDestination = nil
        return destination
    }
}
