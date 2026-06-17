import SwiftUI

struct DashboardOverviewView: View {
    let targetSummary: ConnectionTargetSummary
    let runtimeState: ModelRuntimeState
    let selectedModel: ModelConfig?
    let exportSummaryText: String
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool

    var body: some View {
        DashboardSectionView(
            title: "Dashboard v1",
            subtitle: "Stable scan: next action, target/state, client setup, troubleshooting, then profile context. Lifecycle actions remain explicit below."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                DashboardGroupHeader(
                    title: "1. Next action",
                    subtitle: "Start here for the safest next step in the current state."
                )

                DashboardNextStepsCard(
                    runtimeState: runtimeState,
                    targetSummary: targetSummary,
                    selectedModel: selectedModel
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardGroupHeader(
                    title: "2. Target and state",
                    subtitle: "Current Target explains connection context. Server State explains process, readiness, and lifecycle."
                )

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

                DashboardGroupHeader(
                    title: "3. Client setup",
                    subtitle: "Use the active endpoint, model ID, and readiness state before pasting values into an OpenAI-compatible client."
                )

                DashboardClientSetupCard(
                    runtimeState: runtimeState,
                    targetSummary: targetSummary,
                    selectedModel: selectedModel
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardGroupHeader(
                    title: "4. Troubleshooting",
                    subtitle: "Use diagnostics and logs when readiness, availability, or ownership is unclear."
                )

                DashboardDiagnosticsGuidanceCard(
                    runtimeState: runtimeState,
                    targetSummary: targetSummary
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardGroupHeader(
                    title: "5. Profile context",
                    subtitle: "Profiles and Import / Export are metadata context, not lifecycle or model-file actions."
                )

                DashboardProfileImportExportCard(
                    selectedModel: selectedModel,
                    targetSummary: targetSummary,
                    exportSummaryText: exportSummaryText
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct DashboardGroupHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
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

struct DashboardNextStepsCard: View {
    let runtimeState: ModelRuntimeState
    let targetSummary: ConnectionTargetSummary
    let selectedModel: ModelConfig?

    var body: some View {
        DashboardStatusCard(
            title: "Next Steps",
            systemImage: "list.bullet.clipboard",
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

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Primary Step", value: display.primaryStep)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Selected Profile", value: display.selectedProfile)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Managed Path", value: display.managedPath)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "External Path", value: display.externalPath)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Readiness", value: display.readiness)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Direct Mode", value: display.directMode)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardNextStepsDisplay {
        DashboardNextStepsDisplay(
            runtimeState: runtimeState,
            targetSummary: targetSummary,
            selectedModel: selectedModel
        )
    }
}

private struct DashboardNextStepsDisplay {
    let title: String
    let message: String
    let primaryStep: String
    let selectedProfile: String
    let managedPath: String
    let externalPath: String
    let readiness: String
    let directMode: String
    let safetyNote: String
    let accentColor: Color

    init(
        runtimeState: ModelRuntimeState,
        targetSummary: ConnectionTargetSummary,
        selectedModel: ModelConfig?
    ) {
        selectedProfile = Self.selectedProfileText(selectedModel)
        managedPath = Self.managedPathText(selectedModel)
        externalPath = "Adopt a detected external endpoint only when you want connection context; lifecycle and logs stay external."
        directMode = "\(targetSummary.directModeNote). No proxy or chat UI."

        switch runtimeState {
        case .stopped, .portAvailable:
            title = "Choose how to connect"
            message = "Start a managed server from the selected profile, or adopt an already-running external server after it is detected."
            primaryStep = selectedModel == nil
                ? "Create, select, or import a profile before managed Start."
                : "Run Diagnostics if needed, then press Start for a managed server."
            readiness = "Ready appears after /v1/models responds successfully."
            safetyNote = "Import Profiles restores metadata only; it does not download models or start servers."
            accentColor = .blue
        case .externalServerDetected:
            title = "External endpoint is available"
            message = "A compatible server responded on the selected endpoint, but it is not managed by MLX Server Manager."
            primaryStep = "Adopt External Server to use it as connection context, or leave it unmanaged."
            readiness = "Detection is based on /v1/models responding successfully."
            safetyNote = "Adopt is never process ownership. Stop and Restart remain unavailable for this external process."
            accentColor = .orange
        case .adoptedExternalServer:
            title = "External endpoint is adopted"
            message = "Use Connection Settings for clients, or Forget External Server when this app-side context is no longer useful."
            primaryStep = "Copy Base URL, Model ID, API key placeholder, or client config."
            readiness = "Readiness describes endpoint response, not external process ownership."
            safetyNote = "Forget External Server clears context only and does not stop the server."
            accentColor = .orange
        case .starting, .loading, .checkingReady:
            title = "Wait for readiness"
            message = "The target is not ready until /v1/models responds successfully."
            primaryStep = "Watch state and logs before pointing clients at the endpoint."
            readiness = "Running and Ready are separate states."
            safetyNote = "The app does not send inference requests, auto-restart, or kill processes while waiting."
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            if processIdentifier != nil {
                title = "Managed server is ready"
                message = "The selected managed endpoint is ready for OpenAI-compatible clients."
                primaryStep = "Copy connection settings and paste them into your client."
                safetyNote = "Stop and Restart affect only this app-managed process."
            } else {
                title = "Endpoint is ready"
                message = "The endpoint responded to readiness, but no app-managed pid is attached."
                primaryStep = "Use connection settings and verify process ownership outside the app."
                safetyNote = "The app does not infer ownership from readiness alone."
            }
            readiness = "Ready means /v1/models responded successfully."
            accentColor = .green
        case .stopping:
            title = "Managed server is stopping"
            message = "The app is stopping only the app-managed process."
            primaryStep = "Wait for stopped state before starting again or changing runtime expectations."
            readiness = "Readiness is unavailable while stopping."
            safetyNote = "External servers are not affected by managed Stop."
            accentColor = .orange
        case .checkingPort:
            title = "Checking endpoint availability"
            message = "The app is checking whether the selected host and port can be used safely."
            primaryStep = "Wait for the port check result before pressing Start."
            readiness = "Port availability is not readiness."
            safetyNote = "Port checks do not start, stop, adopt, or inspect external processes."
            accentColor = .orange
        case .portBusy:
            title = "Endpoint needs attention"
            message = "The selected port is busy. Confirm whether it is the server you intend to use."
            primaryStep = "Change port, stop your own external server manually, or adopt only after detection confirms compatibility."
            readiness = "Busy does not mean ready; /v1/models must respond."
            safetyNote = "The app does not kill or take ownership of busy external processes."
            accentColor = .red
        case .portCheckFailed, .readyCheckFailed, .error:
            title = "Check setup and logs"
            message = "The current state needs manual review before clients rely on this endpoint."
            primaryStep = "Check host, port, selected profile, diagnostics, and available logs."
            readiness = "Readiness has not been confirmed."
            safetyNote = "No automatic restart, cleanup, model download, or process takeover is attempted."
            accentColor = .red
        case .unknown:
            title = "State is unclear"
            message = "The app cannot confidently describe what should happen next."
            primaryStep = "Review logs, rerun diagnostics, or check readiness manually."
            readiness = "Unknown until a check succeeds or fails clearly."
            safetyNote = "Unknown state does not trigger automatic lifecycle actions."
            accentColor = .yellow
        }
    }

    private static func selectedProfileText(_ selectedModel: ModelConfig?) -> String {
        guard let selectedModel else {
            return "No selected profile. Create, select, or import profile metadata first."
        }

        let displayName = selectedModel.displayName.isEmpty
            ? selectedModel.modelID
            : selectedModel.displayName
        return "\(displayName) - \(selectedModel.modelID)"
    }

    private static func managedPathText(_ selectedModel: ModelConfig?) -> String {
        guard let selectedModel else {
            return "Managed Start needs a selected profile with model ID, host, and port."
        }

        return "Start launches app-managed mlx_lm.server using \(selectedModel.host):\(selectedModel.serverPort)."
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

struct DashboardClientSetupCard: View {
    let runtimeState: ModelRuntimeState
    let targetSummary: ConnectionTargetSummary
    let selectedModel: ModelConfig?

    var body: some View {
        DashboardStatusCard(
            title: "Client Setup",
            systemImage: "doc.on.clipboard",
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

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Client Base URL", value: display.clientBaseURL)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Model ID Guidance", value: display.modelIDGuidance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Endpoint Source", value: display.endpointSource)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Readiness Before Client Use", value: display.readinessGuidance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Profile Endpoint", value: display.profileEndpoint)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Copy From", value: display.copyGuidance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardClientSetupDisplay {
        DashboardClientSetupDisplay(
            runtimeState: runtimeState,
            targetSummary: targetSummary,
            selectedModel: selectedModel
        )
    }
}

private struct DashboardClientSetupDisplay {
    let title: String
    let message: String
    let clientBaseURL: String
    let modelIDGuidance: String
    let endpointSource: String
    let readinessGuidance: String
    let profileEndpoint: String
    let copyGuidance: String
    let safetyNote: String
    let accentColor: Color

    init(
        runtimeState: ModelRuntimeState,
        targetSummary: ConnectionTargetSummary,
        selectedModel: ModelConfig?
    ) {
        let selectedProfileEndpoint = selectedModel.map { "http://\($0.host):\($0.serverPort)/v1" }
        profileEndpoint = selectedProfileEndpoint ?? "No selected profile endpoint"

        let activeEndpoint = Self.activeEndpointText(
            runtimeState: runtimeState,
            fallbackBaseURL: targetSummary.baseURL
        )
        let activeRelationship = Self.activeRelationshipText(
            activeEndpoint: activeEndpoint,
            profileEndpoint: selectedProfileEndpoint,
            targetSummary: targetSummary
        )

        modelIDGuidance = Self.modelIDGuidanceText(
            selectedModel: selectedModel,
            targetSummary: targetSummary
        )
        copyGuidance = "Use Connection Settings to copy Base URL, Model ID, API key placeholder, JSON config, Hermes Agent config, or curl readiness command."
        safetyNote = "Direct Mode means clients connect directly to the active server endpoint. MLX Server Manager does not proxy inference requests or store API keys or tokens."

        switch runtimeState {
        case let .externalServerDetected(_, _, baseURL, _):
            title = "Detected external endpoint"
            message = "Adopt this endpoint only if you want MLX Server Manager to show it as connection context for client setup."
            clientBaseURL = baseURL
            endpointSource = "Detected external server. Not managed by MLX Server Manager. \(activeRelationship)"
            readinessGuidance = "Ready means /v1/models responded successfully. External lifecycle and logs stay outside the app."
            accentColor = .orange
        case let .adoptedExternalServer(_, _, baseURL, _):
            title = "Use the adopted endpoint"
            message = "OpenAI-compatible clients should point directly at the adopted external server."
            clientBaseURL = baseURL
            endpointSource = "Adopted external connection context only. \(activeRelationship)"
            readinessGuidance = "Use the external server's exposed model names when they differ from selected profile metadata."
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            title = "Copy the ready endpoint"
            message = "The current endpoint passed readiness and can be used by an OpenAI-compatible client."
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            if processIdentifier != nil {
                endpointSource = "App-managed server. \(activeRelationship)"
            } else {
                endpointSource = "Ready endpoint without managed pid. \(activeRelationship)"
            }
            readinessGuidance = "Ready means /v1/models responded successfully before client setup."
            accentColor = .green
        case .starting, .loading, .checkingReady:
            title = "Wait before client setup"
            message = "A target is starting or being checked; wait for Ready before expecting clients to work."
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = "Pending target. \(activeRelationship)"
            readinessGuidance = "Do not treat process startup as readiness; wait for /v1/models success."
            accentColor = .orange
        case .stopped, .portAvailable:
            title = "No active endpoint yet"
            message = "Start a managed server or adopt a detected external server before using client connection values."
            clientBaseURL = "No active endpoint"
            endpointSource = "Selected profile endpoint is saved configuration only. \(activeRelationship)"
            readinessGuidance = "Readiness is not checked until a server target exists."
            accentColor = .secondary
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            title = "Check endpoint before copying"
            message = "The current endpoint is unavailable, failed, or unclear. Verify state before pasting values into a client."
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = "Endpoint needs review. \(activeRelationship)"
            readinessGuidance = "Use Diagnostics, logs, and /v1/models readiness before relying on client setup."
            accentColor = .red
        case .checkingPort:
            title = "Endpoint check in progress"
            message = "The selected host and port are being checked; this does not create an active client target."
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = "Port check only. \(activeRelationship)"
            readinessGuidance = "Port availability is not readiness."
            accentColor = .orange
        case .stopping:
            title = "Endpoint is stopping"
            message = "Wait for the managed stop to complete before copying client connection values."
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = "Managed process is stopping. \(activeRelationship)"
            readinessGuidance = "The endpoint should be treated as unavailable while stopping."
            accentColor = .orange
        }
    }

    private static func activeEndpointText(
        runtimeState: ModelRuntimeState,
        fallbackBaseURL: String
    ) -> String? {
        switch runtimeState {
        case let .externalServerDetected(_, _, baseURL, _):
            return baseURL
        case let .adoptedExternalServer(_, _, baseURL, _):
            return baseURL
        case .stopped, .portAvailable:
            return nil
        default:
            return fallbackBaseURL
        }
    }

    private static func activeRelationshipText(
        activeEndpoint: String?,
        profileEndpoint: String?,
        targetSummary: ConnectionTargetSummary
    ) -> String {
        guard let activeEndpoint else {
            return "No active target is available yet."
        }

        guard let profileEndpoint else {
            return "No selected profile endpoint is available."
        }

        if activeEndpoint == profileEndpoint {
            return "Active endpoint matches the selected profile endpoint."
        }

        if targetSummary.targetType.localizedCaseInsensitiveContains("external") {
            return "Adopted or detected external endpoint may differ from selected profile metadata."
        }

        return "Active endpoint and saved profile endpoint differ; check selected/running model state."
    }

    private static func modelIDGuidanceText(
        selectedModel: ModelConfig?,
        targetSummary: ConnectionTargetSummary
    ) -> String {
        guard let selectedModel else {
            return "No selected profile model ID. Use the model name exposed by the active server."
        }

        if targetSummary.targetType.localizedCaseInsensitiveContains("external") {
            return "Selected profile model ID: \(selectedModel.modelID). External servers may expose a different model name."
        }

        return "Use selected profile model ID: \(selectedModel.modelID). If a client rejects it, check /v1/models or server logs."
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

                DashboardKeyValueRow(label: "Process State", value: display.processState)
                DashboardKeyValueRow(label: "Readiness", value: display.readiness)
                DashboardKeyValueRow(label: "Lifecycle", value: display.lifecycle)
                DashboardKeyValueRow(label: "Memory", value: display.memory)

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

                Label(display.lifecycleNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardServerStateDisplay {
        DashboardServerStateDisplay(
            runtimeState: runtimeState,
            memoryUsageText: memoryUsageText
        )
    }
}

private struct DashboardServerStateDisplay {
    let title: String
    let message: String
    let processState: String
    let readiness: String
    let lifecycle: String
    let memory: String
    let lifecycleNote: String
    let accentColor: Color

    init(runtimeState: ModelRuntimeState, memoryUsageText: String) {
        self.memory = memoryUsageText.replacingOccurrences(of: "Memory: ", with: "")

        switch runtimeState {
        case .stopped:
            title = "No server process attached"
            message = "No app-managed process is running and no external server context is active."
            processState = "Stopped"
            readiness = "Unavailable - no active server target"
            lifecycle = "Start is available through the existing controls"
            lifecycleNote = "Starting a managed server is always an explicit user action."
            accentColor = .secondary
        case let .starting(host, port):
            title = "Managed server starting"
            message = "MLX Server Manager has started a managed launch for \(host):\(port). Readiness is still separate from process startup."
            processState = "Starting managed process"
            readiness = "Not checked - waiting for /v1/models"
            lifecycle = "Lifecycle controls apply to the managed launch"
            lifecycleNote = "Running or starting does not necessarily mean ready; ready requires a successful /v1/models check."
            accentColor = .orange
        case let .loading(host, port, processIdentifier):
            title = "Managed process loading"
            message = "App-owned process pid \(processIdentifier) is attached at \(host):\(port), but readiness has not completed."
            processState = "Managed pid \(processIdentifier)"
            readiness = "Checking - waiting for /v1/models"
            lifecycle = "Stop and Restart apply to this managed process"
            lifecycleNote = "Readiness is distinct from process attachment."
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            title = "Server ready"
            message = "The readiness check succeeded. OpenAI-compatible clients can use the current connection target."
            if let processIdentifier {
                processState = "Managed pid \(processIdentifier)"
                lifecycle = "Stop and Restart apply to this managed process"
                lifecycleNote = "Ready means /v1/models responded successfully for the current endpoint."
            } else {
                processState = "Ready endpoint, no managed pid attached"
                lifecycle = "No app-owned process is attached"
                lifecycleNote = "Readiness can describe endpoint reachability without implying process ownership."
            }
            readiness = "Ready - /v1/models responded successfully"
            accentColor = .green
        case let .stopping(processIdentifier):
            title = "Managed server stopping"
            message = "MLX Server Manager is stopping app-owned process pid \(processIdentifier)."
            processState = "Stopping managed pid \(processIdentifier)"
            readiness = "Unavailable - process is stopping"
            lifecycle = "Stop applies only to the app-managed process"
            lifecycleNote = "External servers are not affected by this stop operation."
            accentColor = .orange
        case let .checkingPort(host, port):
            title = "Checking selected port"
            message = "The app is checking whether \(host):\(port) is available. This does not start or stop a server."
            processState = "No managed process attached"
            readiness = "Not checked - port check in progress"
            lifecycle = "No lifecycle action is running"
            lifecycleNote = "Port checks are informational and do not take ownership of external processes."
            accentColor = .orange
        case let .portAvailable(host, port):
            title = "Port available"
            message = "\(host):\(port) is available for an explicit managed Start."
            processState = "No managed process attached"
            readiness = "Not checked - no active server target"
            lifecycle = "Start remains an explicit user action"
            lifecycleNote = "Availability does not automatically start mlx_lm.server."
            accentColor = .green
        case let .portBusy(host, port):
            title = "Port busy"
            message = "\(host):\(port) is in use. MLX Server Manager will not launch a second server on this port."
            processState = "No managed process attached"
            readiness = "Unavailable - port is busy"
            lifecycle = "Start is blocked until the selected port is safe"
            lifecycleNote = "The app does not stop unknown external processes."
            accentColor = .red
        case let .externalServerDetected(host, port, _, _):
            title = "External server detected"
            message = "An external OpenAI-compatible endpoint responded at \(host):\(port). It is not app-managed."
            processState = "External process, not owned"
            readiness = "Ready - /v1/models responded successfully"
            lifecycle = "Adopt stores connection context only"
            lifecycleNote = "Stop and Restart remain unavailable for this external process."
            accentColor = .orange
        case let .adoptedExternalServer(host, port, _, _):
            title = "Adopted external context"
            message = "\(host):\(port) is adopted as connection context. MLX Server Manager does not own that process."
            processState = "External process, connection context only"
            readiness = "Ready - /v1/models responded successfully"
            lifecycle = "Forget clears app-side context only"
            lifecycleNote = "Forget External Server does not stop or restart the external server."
            accentColor = .orange
        case let .portCheckFailed(host, port, message):
            title = "Port check failed"
            self.message = "The app could not check \(host):\(port): \(message)"
            processState = "No managed process attached"
            readiness = "Failed - endpoint check failed"
            lifecycle = "No lifecycle action is running"
            lifecycleNote = "No automatic recovery is attempted."
            accentColor = .red
        case let .checkingReady(host, port):
            title = "Checking readiness"
            message = "The app is checking \(host):\(port) with /v1/models."
            processState = "Process ownership unchanged"
            readiness = "Checking - /v1/models request in progress"
            lifecycle = "Readiness check only"
            lifecycleNote = "Readiness checks do not send inference requests or change lifecycle state."
            accentColor = .orange
        case let .readyCheckFailed(host, port, message):
            title = "Readiness failed"
            self.message = "/v1/models did not confirm readiness for \(host):\(port): \(message)"
            processState = "Process ownership unchanged"
            readiness = "Failed - readiness check failed"
            lifecycle = "No automatic restart or recovery"
            lifecycleNote = "Use existing controls after checking setup, logs, and endpoint state."
            accentColor = .red
        case let .error(message):
            title = "Server state error"
            self.message = message
            processState = "Check logs"
            readiness = "Unavailable - error state"
            lifecycle = "No automatic recovery"
            lifecycleNote = "Existing lifecycle buttons remain the only way to start, stop, or restart."
            accentColor = .red
        case let .unknown(message):
            title = "Server state unknown"
            self.message = message
            processState = "Unknown"
            readiness = "Unavailable - check status and logs"
            lifecycle = "No automatic recovery"
            lifecycleNote = "The app does not infer or take ownership of unknown processes."
            accentColor = .yellow
        }
    }
}

struct DashboardDiagnosticsGuidanceCard: View {
    let runtimeState: ModelRuntimeState
    let targetSummary: ConnectionTargetSummary

    var body: some View {
        DashboardStatusCard(
            title: "Diagnostics & Logs Guidance",
            systemImage: "stethoscope",
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

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Next Step", value: display.nextStep)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Readiness", value: display.readiness)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Logs", value: display.logs)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Automation", value: display.automation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardDiagnosticsGuidanceDisplay {
        DashboardDiagnosticsGuidanceDisplay(
            runtimeState: runtimeState,
            targetSummary: targetSummary
        )
    }
}

private struct DashboardDiagnosticsGuidanceDisplay {
    let title: String
    let message: String
    let nextStep: String
    let readiness: String
    let logs: String
    let automation: String
    let safetyNote: String
    let accentColor: Color

    init(runtimeState: ModelRuntimeState, targetSummary: ConnectionTargetSummary) {
        switch runtimeState {
        case .stopped:
            title = "No active server target"
            message = "Start a managed server or adopt a detected external server through the existing controls."
            nextStep = "Run Diagnostics or press Start after setup is complete."
            readiness = "Not checked until a server target exists."
            logs = "Only app action logs are available while stopped."
            automation = "No background diagnostics or automatic Start is running."
            safetyNote = "The app waits for explicit user actions before changing lifecycle state."
            accentColor = .secondary
        case .starting, .loading:
            title = "Managed server is starting"
            message = "The app-managed process is attached or launching, but readiness may still be pending."
            nextStep = "Watch managed logs and wait for Ready before using clients."
            readiness = "Ready requires /v1/models to respond successfully."
            logs = "Managed server logs are available in the Logs section."
            automation = "The app does not send inference requests while waiting."
            safetyNote = "Running does not always mean ready; readiness and process state are separate."
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            if processIdentifier != nil {
                title = "Managed server ready"
                message = "The managed endpoint passed readiness and can be used by OpenAI-compatible clients."
                nextStep = "Copy connection settings or continue monitoring logs."
                logs = "Managed server logs remain available in the Logs section."
            } else {
                title = "Endpoint ready"
                message = "The endpoint passed readiness, but no app-managed pid is attached."
                nextStep = "Use connection settings, and check the endpoint owner for process logs."
                logs = "Only app logs are available unless this app started the server."
            }
            readiness = "Ready means /v1/models responded successfully."
            automation = "No automatic restart or request routing is active."
            safetyNote = "Clients connect directly to the target endpoint in Direct Mode."
            accentColor = .green
        case .stopping:
            title = "Managed server is stopping"
            message = "The app is stopping only the app-managed process."
            nextStep = "Wait for stopped state, then inspect logs if shutdown fails."
            readiness = "Unavailable while the managed process is stopping."
            logs = "Managed server logs may show shutdown details."
            automation = "External processes are not affected by this stop operation."
            safetyNote = "Stop remains scoped to the app-managed process only."
            accentColor = .orange
        case let .checkingPort(host, port):
            title = "Checking port availability"
            message = "The app is checking whether \(host):\(port) is safe for a managed launch."
            nextStep = "Wait for the port check result."
            readiness = "Readiness is not checked during a port availability check."
            logs = "App logs show the port check result."
            automation = "Port checks do not start, stop, or adopt servers."
            safetyNote = "This check is informational and does not take ownership of processes."
            accentColor = .orange
        case .portAvailable:
            title = "Port is available"
            message = "The selected port is available for an explicit managed Start."
            nextStep = "Press Start when you want MLX Server Manager to launch the server."
            readiness = "Not checked until a server is running or an endpoint is checked."
            logs = "App logs will show the next lifecycle action."
            automation = "No server is started automatically."
            safetyNote = "Availability is not a lifecycle action."
            accentColor = .green
        case let .portBusy(host, port):
            title = "Port is busy"
            message = "\(host):\(port) is already in use by another process or service."
            nextStep = "Change port, check the external owner, or adopt it only if readiness confirms the intended endpoint."
            readiness = "Busy does not mean ready; use /v1/models readiness to confirm compatibility."
            logs = "External process logs are not available in this app."
            automation = "The app does not kill or take ownership of the busy process."
            safetyNote = "Port busy guidance is informational; remediation stays manual."
            accentColor = .red
        case .externalServerDetected:
            title = "External server detected"
            message = "A compatible endpoint responded, but MLX Server Manager does not own the process."
            nextStep = "Adopt only if you want to use this endpoint as connection context."
            readiness = "Detection is based on /v1/models responding successfully."
            logs = "Check external logs in the terminal or app that launched the server."
            automation = "Adopt is not automatic and does not change process ownership."
            safetyNote = "Stop and Restart remain unavailable for detected external servers."
            accentColor = .orange
        case .adoptedExternalServer:
            title = "External context adopted"
            message = "The endpoint is saved as connection context only."
            nextStep = "Use copied connection settings, or Forget External Server to clear app-side context."
            readiness = "The app can describe connection status, not external process ownership."
            logs = "External server logs must be checked outside MLX Server Manager."
            automation = "Forget removes context only; it does not stop the external server."
            safetyNote = "Adopted external servers are not monitored for memory or managed logs."
            accentColor = .orange
        case let .portCheckFailed(host, port, _):
            title = "Port check needs attention"
            message = "The app could not determine the state of \(host):\(port)."
            nextStep = "Verify host, port, local networking, and app logs."
            readiness = "Readiness was not confirmed."
            logs = "Check app logs for the port check failure message."
            automation = "No automatic recovery is attempted."
            safetyNote = "The app does not start or stop processes after a failed port check."
            accentColor = .red
        case let .checkingReady(host, port):
            title = "Checking readiness"
            message = "The app is checking \(host):\(port) with /v1/models."
            nextStep = "Wait for the readiness result before troubleshooting further."
            readiness = "/v1/models request is in progress."
            logs = Self.isExternalTarget(targetSummary)
                ? "External process logs are outside this app."
                : "Managed logs are available if the app started the process."
            automation = "Readiness checks do not send chat completions."
            safetyNote = "Readiness checks do not change lifecycle state."
            accentColor = .orange
        case let .readyCheckFailed(host, port, _):
            title = "Readiness failed"
            message = "/v1/models did not confirm readiness for \(host):\(port)."
            nextStep = "Verify host, port, server logs, and whether the target is still starting or OpenAI-compatible."
            readiness = "Failed - /v1/models did not succeed."
            logs = Self.isExternalTarget(targetSummary)
                ? "Check external logs where that server was launched."
                : "Check managed server logs and endpoint settings."
            automation = "The app does not automatically restart or terminate processes."
            safetyNote = "Readiness failure is diagnostic information, not an ownership change."
            accentColor = .red
        case .error:
            title = "Error state"
            message = "The app reported an error for the current server state."
            nextStep = "Check app logs, managed server logs if available, and current settings."
            readiness = "Unavailable until the error is resolved and readiness succeeds."
            logs = "Logs are the first place to inspect the failure detail."
            automation = "No automatic recovery is attempted."
            safetyNote = "Use explicit lifecycle controls after reviewing the failure."
            accentColor = .red
        case .unknown:
            title = "Unknown state"
            message = "The app cannot confidently describe the current server state."
            nextStep = "Check logs and rerun diagnostics or readiness checks as needed."
            readiness = "Unknown until a check succeeds or fails clearly."
            logs = "App logs may explain the unknown state."
            automation = "The app does not infer ownership of unknown processes."
            safetyNote = "Unknown state does not trigger automatic Start, Stop, or Restart."
            accentColor = .yellow
        }
    }

    private static func isExternalTarget(_ targetSummary: ConnectionTargetSummary) -> Bool {
        targetSummary.targetType.localizedCaseInsensitiveContains("external")
            || targetSummary.ownershipNote.localizedCaseInsensitiveContains("external")
    }
}

struct DashboardProfileImportExportCard: View {
    let selectedModel: ModelConfig?
    let targetSummary: ConnectionTargetSummary
    let exportSummaryText: String

    var body: some View {
        DashboardStatusCard(
            title: "Profiles & Import / Export",
            systemImage: "list.bullet.rectangle",
            accentColor: .blue
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

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Selected Profile", value: display.selectedProfile)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Profile Endpoint", value: display.profileEndpoint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Current Target", value: display.currentTarget)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Relationship", value: display.relationship)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Export", value: display.exportSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Import", value: display.importSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardProfileImportExportDisplay {
        DashboardProfileImportExportDisplay(
            selectedModel: selectedModel,
            targetSummary: targetSummary,
            exportSummaryText: exportSummaryText
        )
    }
}

private struct DashboardProfileImportExportDisplay {
    let title: String
    let message: String
    let selectedProfile: String
    let profileEndpoint: String
    let currentTarget: String
    let relationship: String
    let exportSummary: String
    let importSummary: String
    let safetyNote: String

    init(
        selectedModel: ModelConfig?,
        targetSummary: ConnectionTargetSummary,
        exportSummaryText: String
    ) {
        if let selectedModel {
            let displayName = selectedModel.displayName.isEmpty
                ? selectedModel.modelID
                : selectedModel.displayName
            let profileBaseURL = "http://\(selectedModel.host):\(selectedModel.serverPort)/v1"
            let advancedText = selectedModel.advancedLaunchOptions?.isEmpty == false
                ? "Advanced options set"
                : "Simple launch defaults"

            title = "Selected profile metadata"
            message = "Selected profile is saved launch/configuration metadata. Current target is the active managed or adopted endpoint."
            selectedProfile = "\(displayName) - \(selectedModel.modelID)"
            profileEndpoint = "\(selectedModel.host):\(selectedModel.serverPort) (\(advancedText))"
            currentTarget = "\(targetSummary.targetType) - \(targetSummary.baseURL)"
            relationship = Self.relationshipText(
                profileBaseURL: profileBaseURL,
                targetSummary: targetSummary
            )
        } else {
            title = "No selected profile"
            message = "Create or import a profile before starting a managed server."
            selectedProfile = "No profile selected"
            profileEndpoint = "Unavailable"
            currentTarget = "\(targetSummary.targetType) - \(targetSummary.baseURL)"
            relationship = "A profile can be selected even when no managed server is running."
        }

        exportSummary = "\(exportSummaryText) Metadata only: profile names, model IDs, endpoints, and launch options when present."
        importSummary = "Preview validates first. Import Selected writes selected valid metadata. Rename changes imported display name; Replace updates one unambiguous local profile."
        safetyNote = "Import / Export does not download models, delete model files, import secrets, start servers, stop servers, or change external process ownership."
    }

    private static func relationshipText(
        profileBaseURL: String,
        targetSummary: ConnectionTargetSummary
    ) -> String {
        if !targetSummary.isActiveTarget {
            return "No active target. Start uses the selected profile for managed launch."
        }

        if targetSummary.baseURL == profileBaseURL {
            return "Active endpoint matches the selected profile endpoint."
        }

        if targetSummary.targetType.localizedCaseInsensitiveContains("external") {
            return "Current target is external connection context; selected profile remains metadata."
        }

        return "Profile endpoint and active endpoint differ; check selected/running model state."
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
