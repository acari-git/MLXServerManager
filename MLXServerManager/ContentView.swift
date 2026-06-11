//
//  ContentView.swift
//  MLXServerManager
//
//  Created by yoinkun on 2026/06/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            statusHeader

            Divider()

            HSplitView {
                ModelListView(
                    models: viewModel.models,
                    selectedModelID: $viewModel.selectedModelID
                )
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsPanelView(
                            executablePath: $viewModel.settings.mlxServerExecutablePath,
                            settingsDirectoryPath: viewModel.settingsDirectoryPath,
                            onSave: viewModel.saveSettingsRequested
                        )

                        StatusPanelView(
                            runtimeState: viewModel.runtimeState,
                            onCheckPort: viewModel.checkPortRequested,
                            onCheckReady: viewModel.checkReadyRequested,
                            onStart: viewModel.startRequested,
                            onStop: viewModel.stopRequested,
                            onRestart: viewModel.restartRequested
                        )

                        ModelDetailView(model: viewModel.selectedModel)

                        ConnectionSettingsView(
                            baseURL: viewModel.baseURL,
                            modelID: viewModel.selectedModelIdentifier,
                            apiKeyPlaceholder: viewModel.apiKeyPlaceholder,
                            onCopyBaseURL: viewModel.copyBaseURL,
                            onCopyModelID: viewModel.copyModelID,
                            onCopyConfig: viewModel.copyConfig
                        )

                        LogView(text: viewModel.logText)
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
                Text(viewModel.runtimeState.title)
                    .font(.headline)
                Text(viewModel.runtimeState.detail)
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
}

#Preview {
    ContentView()
}
