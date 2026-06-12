import SwiftUI

struct ConnectionSettingsView: View {
    let baseURL: String
    let modelID: String
    let apiKeyPlaceholder: String
    let onCopyBaseURL: () -> Void
    let onCopyModelID: () -> Void
    let onCopyConfig: () -> Void
    let onCopyModelsCurl: () -> Void
    let onCopyChatCompletionsCurl: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OpenAI-Compatible Connection")
                .font(.headline)

            DetailGrid(rows: [
                ("Base URL", baseURL),
                ("Model ID", modelID),
                ("API Key", apiKeyPlaceholder)
            ])

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        onCopyBaseURL()
                    } label: {
                        Label("Copy Base URL", systemImage: "link")
                    }

                    Button {
                        onCopyModelID()
                    } label: {
                        Label("Copy Model ID", systemImage: "doc.on.doc")
                    }

                    Button {
                        onCopyConfig()
                    } label: {
                        Label("Copy Config", systemImage: "square.and.arrow.up")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onCopyModelsCurl()
                    } label: {
                        Label("Copy curl /v1/models", systemImage: "terminal")
                    }

                    Button {
                        onCopyChatCompletionsCurl()
                    } label: {
                        Label("Copy curl /v1/chat/completions", systemImage: "terminal")
                    }
                }
            }
        }
        .panelStyle()
    }
}
