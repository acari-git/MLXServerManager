import SwiftUI

struct LogView: View {
    let entries: [LogEntry]
    let onCopy: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Logs")
                    .font(.headline)
                    .accessibilityIdentifier("log-view-title")

                Text("\(entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("log-view-entry-count")

                Spacer()

                Button {
                    onCopy()
                } label: {
                    Label("Copy Logs", systemImage: "doc.on.doc")
                }
                .accessibilityIdentifier("log-view-copy-button")

                Button {
                    onClear()
                } label: {
                    Label("Clear Logs", systemImage: "trash")
                }
                .accessibilityIdentifier("log-view-clear-button")
            }
            .accessibilityIdentifier("log-view-header")

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if entries.isEmpty {
                        Text("No logs")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("log-view-empty-state")
                    } else {
                        ForEach(entries) { entry in
                            LogEntryRow(entry: entry)
                        }
                    }
                }
                .padding(12)
                .accessibilityIdentifier("log-view-entry-list")
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
        .accessibilityIdentifier("log-view")
    }
}

private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(entry.category)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(categoryColor)
                .frame(width: 82, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private var categoryColor: Color {
        let category = entry.category.lowercased()

        if category.contains("error") || entry.message.localizedCaseInsensitiveContains("failed") {
            return .red
        }

        if category.contains("warning") || entry.message.localizedCaseInsensitiveContains("warning") {
            return .orange
        }

        switch category {
        case "start", "restart", "ready":
            return .green
        case "stop", "port":
            return .blue
        case "diagnostics", "profile", "model", "switching":
            return .purple
        case "process", "memory":
            return .secondary
        default:
            return .secondary
        }
    }
}
