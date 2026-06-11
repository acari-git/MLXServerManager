//
//  ContentView.swift
//  MLXServerManager
//
//  Created by yoinkun on 2026/06/11.
//

import SwiftUI
import AppKit
import Combine

struct ManagedModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let family: String
    let quantization: String
    let contextWindow: String
    let localName: String
    let notes: String
}

enum ServerDisplayStatus {
    case stopped

    var title: String {
        switch self {
        case .stopped:
            "Stopped"
        }
    }

    var detail: String {
        switch self {
        case .stopped:
            "mlx_lm.server is not running. Start / Stop / Restart wiring will be added after the UI skeleton is stable."
        }
    }
}

final class ServerDashboardViewModel: ObservableObject {
    @Published var selectedModelID: ManagedModel.ID?
    @Published private(set) var status: ServerDisplayStatus = .stopped
    @Published private(set) var logLines: [String] = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Process launch, port checks, and readiness checks are not implemented in Step 1."
    ]

    let models: [ManagedModel] = [
        ManagedModel(
            id: "mlx-community/Qwen3-8B-4bit",
            displayName: "Qwen3 8B 4-bit",
            family: "Qwen3",
            quantization: "4-bit",
            contextWindow: "Configured by mlx_lm.server",
            localName: "Qwen3-8B-4bit",
            notes: "Small local model profile for validating the manager UI."
        ),
        ManagedModel(
            id: "mlx-community/Qwen3-14B-4bit",
            displayName: "Qwen3 14B 4-bit",
            family: "Qwen3",
            quantization: "4-bit",
            contextWindow: "Configured by mlx_lm.server",
            localName: "Qwen3-14B-4bit",
            notes: "Medium local model profile reserved for later launch configuration."
        ),
        ManagedModel(
            id: "mlx-community/Qwen3-32B-4bit",
            displayName: "Qwen3 32B 4-bit",
            family: "Qwen3",
            quantization: "4-bit",
            contextWindow: "Configured by mlx_lm.server",
            localName: "Qwen3-32B-4bit",
            notes: "Larger local model profile for future memory monitoring work."
        )
    ]

    let host = "127.0.0.1"
    let port = 8000
    let apiBasePath = "/v1"

    init() {
        selectedModelID = models.first?.id
    }

    var selectedModel: ManagedModel? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    var baseURL: String {
        "http://\(host):\(port)\(apiBasePath)"
    }

    var selectedModelIdentifier: String {
        selectedModel?.id ?? "No model selected"
    }

    var copyableConfig: String {
        """
        Base URL: \(baseURL)
        Model: \(selectedModelIdentifier)
        API Key: not required locally, use a placeholder if your client requires one
        """
    }

    var logText: String {
        logLines.joined(separator: "\n")
    }

    func startRequested() {
        appendLog("[ui] Start requested. Process launch is intentionally not implemented in Step 1.")
    }

    func stopRequested() {
        appendLog("[ui] Stop requested. Process termination is intentionally not implemented in Step 1.")
    }

    func restartRequested() {
        appendLog("[ui] Restart requested. Restart wiring is intentionally not implemented in Step 1.")
    }

    func copyBaseURL() {
        copyToPasteboard(baseURL)
        appendLog("[ui] Copied Base URL.")
    }

    func copyModelID() {
        copyToPasteboard(selectedModelIdentifier)
        appendLog("[ui] Copied Model ID.")
    }

    func copyConfig() {
        copyToPasteboard(copyableConfig)
        appendLog("[ui] Copied OpenAI-compatible config.")
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ServerDashboardViewModel()

    var body: some View {
        VStack(spacing: 0) {
            statusHeader

            Divider()

            HSplitView {
                modelList
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        controlPanel
                        modelDetails
                        connectionPanel
                        logPanel
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private var statusHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("MLX Server Manager")
                    .font(.title2.weight(.semibold))
                Text("Direct Mode control surface for mlx_lm.server")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(viewModel.status.title)
                    .font(.headline)
                Text(viewModel.status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .frame(maxWidth: 430, alignment: .trailing)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Models")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider()

            List(viewModel.models, selection: $viewModel.selectedModelID) { model in
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.body.weight(.medium))
                    Text(model.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .tag(model.id)
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Status")

            HStack(spacing: 12) {
                statusBadge

                Spacer()

                Button {
                    viewModel.startRequested()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.stopRequested()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }

                Button {
                    viewModel.restartRequested()
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
                .fill(.secondary)
                .frame(width: 9, height: 9)
            Text(viewModel.status.title)
                .font(.body.weight(.semibold))
            Text("No process attached")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
    }

    private var modelDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Selected Model")

            if let model = viewModel.selectedModel {
                DetailGrid(rows: [
                    ("Model ID", model.id),
                    ("Display Name", model.displayName),
                    ("Family", model.family),
                    ("Quantization", model.quantization),
                    ("Context", model.contextWindow),
                    ("Local Name", model.localName),
                    ("Notes", model.notes)
                ])
            } else {
                Text("No model selected")
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("OpenAI-Compatible Connection")

            DetailGrid(rows: [
                ("Base URL", viewModel.baseURL),
                ("Model ID", viewModel.selectedModelIdentifier),
                ("API Key", "Not required locally; use a placeholder if your client requires one")
            ])

            HStack(spacing: 10) {
                Button {
                    viewModel.copyBaseURL()
                } label: {
                    Label("Copy Base URL", systemImage: "link")
                }

                Button {
                    viewModel.copyModelID()
                } label: {
                    Label("Copy Model ID", systemImage: "doc.on.doc")
                }

                Button {
                    viewModel.copyConfig()
                } label: {
                    Label("Copy Config", systemImage: "square.and.arrow.up")
                }
            }
        }
        .panelStyle()
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Logs")

            ScrollView {
                Text(viewModel.logText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            }
        }
        .panelStyle()
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }
}

private struct DetailGrid: View {
    let rows: [(String, String)]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach(rows, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)

                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct PanelStyle: ViewModifier {
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

private extension View {
    func panelStyle() -> some View {
        modifier(PanelStyle())
    }
}

#Preview {
    ContentView()
}
