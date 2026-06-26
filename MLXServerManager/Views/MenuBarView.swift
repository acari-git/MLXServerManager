import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var menuBarTitle: String {
        if viewModel.restartRequired {
            return "MLX: \(viewModel.runtimeState.menuBarStatus) - \(t("restart required", "再起動が必要"))"
        }

        return "MLX: \(viewModel.runtimeState.menuBarStatus)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(menuBarTitle)
                .font(.headline)

            Text(viewModel.runtimeState.badgeDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button(strings.text(.start)) {
                viewModel.startRequested()
            }

            Button(strings.text(.stop)) {
                viewModel.stopRequested()
            }
            .disabled(!viewModel.canStopManagedServer)

            Button(strings.text(.restart)) {
                viewModel.restartRequested()
            }
            .disabled(!viewModel.canRestartManagedServer)

            if viewModel.canAdoptExternalServer {
                Button(t("Adopt External Server", "外部サーバーを採用")) {
                    viewModel.adoptExternalServerRequested()
                }
            }

            if viewModel.canForgetExternalServer {
                Button(t("Forget External Server", "外部サーバーを解除")) {
                    viewModel.forgetExternalServerRequested()
                }
            }

            Button(strings.text(.runDiagnostics)) {
                viewModel.runDiagnosticsRequested()
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text(t("Connection Settings", "接続設定"))
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

            Button(t("Open App", "アプリを開く")) {
                openMainWindow()
            }

            Divider()

            Button(t("Quit", "終了")) {
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
