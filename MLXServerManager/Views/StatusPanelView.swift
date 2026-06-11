import SwiftUI

struct StatusPanelView: View {
    let runtimeState: ModelRuntimeState
    let onCheckPort: () -> Void
    let onCheckReady: () -> Void
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)

            HStack(spacing: 12) {
                statusBadge

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

                Button {
                    onRestart()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
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
