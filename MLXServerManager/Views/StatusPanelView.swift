import SwiftUI

struct StatusPanelView: View {
    let runtimeState: ModelRuntimeState
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool
    let isExternalServerDetected: Bool
    let isAdoptedExternalServer: Bool
    let canStopManagedServer: Bool
    let canRestartManagedServer: Bool
    let canAdoptExternalServer: Bool
    let canForgetExternalServer: Bool
    let onCheckPort: () -> Void
    let onCheckReady: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void
    let onAdoptExternalServer: () -> Void
    let onForgetExternalServer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    statusBadge
                    memoryBadge
                    selectedModelBadge
                    runningModelBadge
                    if restartRequired {
                        restartRequiredBadge
                    }
                    if isExternalServerDetected {
                        externalServerBadge
                    }
                    if isAdoptedExternalServer {
                        adoptedExternalServerBadge
                    }
                }

                Spacer()

                Button {
                    onCheckPort()
                } label: {
                    Label("Check Port", systemImage: "network")
                }

                Button {
                    onCheckReady()
                } label: {
                    Label("Check Ready", systemImage: "checkmark.seal")
                }

                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onStop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!canStopManagedServer)

                Button {
                    onRestart()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .disabled(!canRestartManagedServer)

                if isExternalServerDetected {
                    Button {
                        onAdoptExternalServer()
                    } label: {
                        Label("Adopt External Server", systemImage: "link.badge.plus")
                    }
                    .disabled(!canAdoptExternalServer)
                }

                if isAdoptedExternalServer {
                    Button {
                        onForgetExternalServer()
                    } label: {
                        Label("Forget External Server", systemImage: "xmark.circle")
                    }
                    .disabled(!canForgetExternalServer)
                }
            }
        }
        .panelStyle()
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 9, height: 9)
            Text(runtimeState.title)
                .font(.body.weight(.semibold))
            Text(runtimeState.badgeDetail)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var memoryBadge: some View {
        Label(memoryUsageText, systemImage: "memorychip")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var selectedModelBadge: some View {
        Label(selectedModelText, systemImage: "checkmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var runningModelBadge: some View {
        Label(runningModelText, systemImage: "server.rack")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var restartRequiredBadge: some View {
        Label("Restart required to apply selected model.", systemImage: "arrow.clockwise.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
    }

    private var externalServerBadge: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("External server detected", systemImage: "network")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("This server was not started by MLX Server Manager.")
            Text("Stop and Restart are unavailable for external servers.")
            Text("Use connection settings to connect a client to this endpoint.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var adoptedExternalServerBadge: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Adopted external server", systemImage: "link")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Connection context only.")
            Text("Not managed by MLX Server Manager.")
            Text("Forget removes the app-side context only.")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var indicatorColor: Color {
        switch runtimeState {
        case .stopped:
            .secondary
        case .starting, .loading, .stopping, .checkingPort:
            .orange
        case .portAvailable, .ready:
            .green
        case .checkingReady:
            .orange
        case .externalServerDetected, .adoptedExternalServer:
            .orange
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error:
            .red
        case .unknown:
            .yellow
        }
    }
}

struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
}
