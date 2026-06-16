import SwiftUI

struct DashboardOverviewView: View {
    let targetSummary: ConnectionTargetSummary
    let runtimeState: ModelRuntimeState
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool

    var body: some View {
        DashboardSectionView(
            title: "Dashboard",
            subtitle: "Current target and server state at a glance. Lifecycle actions remain explicit below."
        ) {
            HStack(alignment: .top, spacing: 12) {
                DashboardCurrentTargetCard(
                    summary: targetSummary,
                    runtimeState: runtimeState
                )
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardServerStateCard(
                    runtimeState: runtimeState,
                    memoryUsageText: memoryUsageText,
                    selectedModelText: selectedModelText,
                    runningModelText: runningModelText,
                    restartRequired: restartRequired
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct DashboardSectionView<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardCurrentTargetCard: View {
    let summary: ConnectionTargetSummary
    let runtimeState: ModelRuntimeState

    var body: some View {
        DashboardStatusCard(
            title: "Current Target",
            systemImage: display.iconName,
            accentColor: display.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                DashboardKeyValueRow(label: "Target Type", value: display.targetType)
                DashboardKeyValueRow(label: "Endpoint", value: display.endpoint)
                DashboardKeyValueRow(label: "Selected Model", value: display.modelID)
                DashboardKeyValueRow(label: "Readiness", value: display.readiness)
                DashboardKeyValueRow(label: "Ownership", value: display.ownership)

                if let lifecycleNote = display.lifecycleNote {
                    Label(lifecycleNote, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(summary.directModeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var display: DashboardCurrentTargetDisplay {
        DashboardCurrentTargetDisplay(summary: summary, runtimeState: runtimeState)
    }
}

private struct DashboardCurrentTargetDisplay {
    let title: String
    let message: String
    let targetType: String
    let endpoint: String
    let modelID: String
    let readiness: String
    let ownership: String
    let lifecycleNote: String?
    let iconName: String
    let accentColor: Color

    init(summary: ConnectionTargetSummary, runtimeState: ModelRuntimeState) {
        self.modelID = summary.modelID

        switch runtimeState {
        case let .externalServerDetected(host, port, baseURL, _):
            title = "External server detected"
            message = "A compatible endpoint responded on the selected host and port. It is not managed until you explicitly adopt it as connection context."
            targetType = "External Server Detected"
            endpoint = "\(baseURL) (\(host):\(port))"
            readiness = "Ready - /v1/models responded successfully"
            ownership = "External server, not owned by MLX Server Manager"
            lifecycleNote = "Adopt is connection context only. Stop and Restart remain unavailable for this external process."
            iconName = "network"
            accentColor = .orange
        case let .adoptedExternalServer(host, port, baseURL, _):
            title = "Adopted external server"
            message = "This endpoint is being used as connection context only. MLX Server Manager does not own or control the process."
            targetType = "Adopted External Server"
            endpoint = "\(baseURL) (\(host):\(port))"
            readiness = "Ready - /v1/models responded successfully"
            ownership = "Connection context only"
            lifecycleNote = "Forget External Server only clears app-side context. It does not stop the server."
            iconName = "link"
            accentColor = .orange
        case let .ready(host, port, processIdentifier):
            title = "Managed server ready"
            message = "The selected endpoint is ready for an OpenAI-compatible client. MLX Server Manager owns this managed process when a pid is attached."
            targetType = "Managed Server"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Ready - /v1/models responded successfully"
            if let processIdentifier {
                ownership = "Managed by MLX Server Manager, pid \(processIdentifier)"
            } else {
                ownership = "Ready endpoint, no managed pid attached"
            }
            lifecycleNote = "Start, Stop, and Restart controls apply only when an app-managed process is attached."
            iconName = "server.rack"
            accentColor = .green
        case let .starting(host, port):
            title = "Managed server starting"
            message = "A managed launch is in progress. Readiness has not completed yet."
            targetType = "Managed Server"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Not checked - waiting for /v1/models"
            ownership = "Managed launch requested by MLX Server Manager"
            lifecycleNote = "Lifecycle actions remain explicit; no automatic restart is triggered by this card."
            iconName = "server.rack"
            accentColor = .orange
        case let .loading(host, port, processIdentifier):
            title = "Managed server loading"
            message = "A managed process is attached and the endpoint is still loading."
            targetType = "Managed Server"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Checking - waiting for /v1/models"
            ownership = "Managed by MLX Server Manager, pid \(processIdentifier)"
            lifecycleNote = "Stop and Restart apply to the managed process only."
            iconName = "server.rack"
            accentColor = .orange
        case let .checkingReady(host, port):
            title = "Checking readiness"
            message = "The app is checking the selected endpoint with /v1/models."
            targetType = summary.targetType
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Checking - /v1/models request in progress"
            ownership = summary.ownershipNote
            lifecycleNote = "Readiness check does not send inference requests."
            iconName = summary.isActiveTarget ? "server.rack" : "power"
            accentColor = .orange
        case let .readyCheckFailed(host, port, message):
            title = "Target readiness failed"
            self.message = "The selected endpoint did not pass the /v1/models readiness check: \(message)"
            targetType = summary.targetType
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Failed - readiness check failed"
            ownership = summary.ownershipNote
            lifecycleNote = "No automatic recovery is attempted. Use existing controls after checking setup and logs."
            iconName = "exclamationmark.triangle"
            accentColor = .red
        case let .portBusy(host, port):
            title = "Endpoint unavailable"
            message = "The selected host and port are busy, but no target has been adopted or attached here."
            targetType = "Unavailable"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Unavailable - port is busy"
            ownership = "No app-managed process attached"
            lifecycleNote = "Start will not launch a second server on this port."
            iconName = "exclamationmark.triangle"
            accentColor = .red
        case let .portCheckFailed(host, port, message):
            title = "Endpoint check failed"
            self.message = "The selected endpoint could not be checked: \(message)"
            targetType = "Unavailable"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Failed - endpoint check failed"
            ownership = "No app-managed process attached"
            lifecycleNote = "No automatic recovery is attempted."
            iconName = "exclamationmark.triangle"
            accentColor = .red
        case let .checkingPort(host, port):
            title = "Checking endpoint"
            message = "The app is checking whether the selected host and port can be used."
            targetType = "No Current Target"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Not checked - port check in progress"
            ownership = "No app-managed process attached"
            lifecycleNote = "Port checks do not start or stop servers."
            iconName = "power"
            accentColor = .orange
        case let .portAvailable(host, port):
            title = "No current target"
            message = "The selected host and port are available. Start a managed server or adopt an external server through the existing controls."
            targetType = "No Current Target"
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = "Not checked - no active target"
            ownership = "No app-managed process attached"
            lifecycleNote = "Start remains an explicit user action."
            iconName = "power"
            accentColor = .secondary
        case .stopped:
            title = "No current target"
            message = "No managed server is running and no external server is adopted."
            targetType = "No Current Target"
            endpoint = summary.baseURL
            readiness = "Not checked - no active target"
            ownership = "No app-managed process attached"
            lifecycleNote = "Start a managed server, or adopt a detected external server after readiness succeeds."
            iconName = "power"
            accentColor = .secondary
        case .stopping:
            title = "Managed server stopping"
            message = "The app-managed process is stopping. The current target is becoming unavailable."
            targetType = "Managed Server"
            endpoint = summary.baseURL
            readiness = "Unavailable - process is stopping"
            ownership = "Managed process is stopping"
            lifecycleNote = "Stop applies only to the app-managed process."
            iconName = "server.rack"
            accentColor = .orange
        case let .error(message), let .unknown(message):
            title = "Target state needs attention"
            self.message = message
            targetType = summary.isActiveTarget ? summary.targetType : "Unavailable"
            endpoint = summary.baseURL
            readiness = "Unavailable - check status and logs"
            ownership = summary.ownershipNote
            lifecycleNote = "No automatic recovery is attempted."
            iconName = "exclamationmark.triangle"
            accentColor = .red
        }
    }
}

struct DashboardServerStateCard: View {
    let runtimeState: ModelRuntimeState
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool

    var body: some View {
        DashboardStatusCard(
            title: "Server State",
            systemImage: "gauge",
            accentColor: indicatorColor
        ) {
            VStack(alignment: .leading, spacing: 8) {
                DashboardKeyValueRow(label: "State", value: runtimeState.title)
                DashboardKeyValueRow(label: "Endpoint", value: endpointText)
                DashboardKeyValueRow(label: "Process", value: processText)
                DashboardKeyValueRow(label: "Lifecycle", value: lifecycleText)
                DashboardKeyValueRow(label: "Memory", value: normalizedMemoryText)

                Text(selectedModelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(runningModelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if restartRequired {
                    Label("Restart required to apply selected model.", systemImage: "arrow.clockwise.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var endpointText: String {
        switch runtimeState {
        case .stopped, .stopping, .error, .unknown:
            "No active endpoint"
        case let .starting(host, port),
             let .loading(host, port, _),
             let .checkingPort(host, port),
             let .portAvailable(host, port),
             let .portBusy(host, port),
             let .portCheckFailed(host, port, _),
             let .checkingReady(host, port),
             let .readyCheckFailed(host, port, _):
            "\(host):\(port)"
        case let .externalServerDetected(_, _, baseURL, _),
             let .adoptedExternalServer(_, _, baseURL, _):
            baseURL
        case let .ready(host, port, _):
            "\(host):\(port)"
        }
    }

    private var processText: String {
        switch runtimeState {
        case let .loading(_, _, processIdentifier),
             let .stopping(processIdentifier):
            "Managed pid \(processIdentifier)"
        case let .ready(_, _, processIdentifier):
            if let processIdentifier {
                "Managed pid \(processIdentifier)"
            } else {
                "Ready endpoint, no managed pid"
            }
        case .externalServerDetected:
            "External, not managed"
        case .adoptedExternalServer:
            "Connection context only"
        default:
            "No managed process attached"
        }
    }

    private var lifecycleText: String {
        switch runtimeState {
        case .externalServerDetected:
            "Adopt available; Stop and Restart disabled"
        case .adoptedExternalServer:
            "Forget context only; external process untouched"
        case .loading, .ready, .starting:
            "Start, Stop, and Restart stay explicit"
        case .stopping:
            "Stopping app-managed process"
        default:
            "Start is explicit; no automatic lifecycle action"
        }
    }

    private var normalizedMemoryText: String {
        memoryUsageText.replacingOccurrences(of: "Memory: ", with: "")
    }

    private var indicatorColor: Color {
        switch runtimeState {
        case .stopped:
            .secondary
        case .starting, .loading, .stopping, .checkingPort, .checkingReady:
            .orange
        case .portAvailable, .ready:
            .green
        case .externalServerDetected, .adoptedExternalServer:
            .orange
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error:
            .red
        case .unknown:
            .yellow
        }
    }
}

struct DashboardStatusCard<Content: View>: View {
    let title: String
    let systemImage: String
    let accentColor: Color
    let content: Content

    init(
        title: String,
        systemImage: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(accentColor)
                    .frame(width: 18)

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

struct DashboardKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
