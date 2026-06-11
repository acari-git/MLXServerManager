import SwiftUI

struct ConnectionSettingsView: View {
    let baseURL: String
    let modelID: String
    let apiKeyPlaceholder: String
    let onCopyBaseURL: () -> Void
    let onCopyModelID: () -> Void
    let onCopyConfig: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OpenAI-Compatible Connection")
                .font(.headline)

            DetailGrid(rows: [
                ("Base URL", baseURL),
                ("Model ID", modelID),
                ("API Key", apiKeyPlaceholder)
            ])

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
        }
        .panelStyle()
    }
}

