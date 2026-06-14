import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.menuBarTitle)
                .font(.headline)

            Text(viewModel.runtimeState.badgeDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Start") {
                viewModel.startRequested()
            }

            Button("Stop") {
                viewModel.stopRequested()
            }
            .disabled(!viewModel.canStopManagedServer)

            Button("Restart") {
                viewModel.restartRequested()
            }
            .disabled(!viewModel.canRestartManagedServer)

            Button("Run Diagnostics") {
                viewModel.runDiagnosticsRequested()
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Settings")
                    .font(.caption.weight(.semibold))
                Text(viewModel.baseURL)
                    .font(.caption)
                    .textSelection(.enabled)
                Text(viewModel.selectedModelIdentifier)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Button("Open App") {
                openMainWindow()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 280, alignment: .leading)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
