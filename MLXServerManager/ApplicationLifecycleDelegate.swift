import AppKit

@MainActor
final class ApplicationLifecycleDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: AppViewModel?
    private var isSystemShutdownRequested = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceWillPowerOff(_:)),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isSystemShutdownRequested else {
            return viewModel?.applicationShouldTerminateForSystemShutdownRequested() ?? .terminateNow
        }
        return viewModel?.applicationShouldTerminateRequested() ?? .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func workspaceWillPowerOff(_ notification: Notification) {
        isSystemShutdownRequested = true
    }
}
