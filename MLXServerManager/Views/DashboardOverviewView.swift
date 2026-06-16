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
                DashboardCurrentTargetCard(summary: targetSummary)
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

    var body: some View {
        DashboardStatusCard(
            title: "Current Target",
            systemImage: iconName,
            accentColor: accentColor
        ) {
            VStack(alignment: .leading, spacing: 8) {
                DashboardKeyValueRow(label: "Target", value: summary.targetType)
                DashboardKeyValueRow(label: "Base URL", value: summary.baseURL)
                DashboardKeyValueRow(label: "Model", value: summary.modelID)
                DashboardKeyValueRow(label: "Readiness", value: summary.readinessSummary)
                DashboardKeyValueRow(label: "Ownership", value: summary.ownershipNote)

                Text(summary.directModeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var iconName: String {
        switch summary.targetType {
        case "Managed Server":
            "server.rack"
        case "External Server Detected":
            "network"
        case "Adopted External Server":
            "link"
        default:
            "power"
        }
    }

    private var accentColor: Color {
        switch summary.targetType {
        case "Managed Server":
            .green
        case "External Server Detected", "Adopted External Server":
            .orange
        default:
            .secondary
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
    }
}
