import SwiftUI

struct LogView: View {
    let entries: [LogEntry]
    let language: AppLanguage
    let showsHeader: Bool
    let onCopy: () -> Void
    let onClear: () -> Void

    init(
        entries: [LogEntry],
        language: AppLanguage = .system,
        showsHeader: Bool = true,
        onCopy: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) {
        self.entries = entries
        self.language = language
        self.showsHeader = showsHeader
        self.onCopy = onCopy
        self.onClear = onClear
    }

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
                HStack {
                    Text(strings.text(.logs))
                        .font(.headline)
                        .accessibilityIdentifier("log-view-title")

                    Text(t("\(entries.count) entries", "\(entries.count)件"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("log-view-entry-count")

                    Spacer()

                    Button {
                        onCopy()
                    } label: {
                        Label(t("Copy Logs", "ログをコピー"), systemImage: "doc.on.doc")
                    }
                    .accessibilityIdentifier("log-view-copy-button")

                    Button {
                        onClear()
                    } label: {
                        Label(t("Clear Logs", "ログをクリア"), systemImage: "trash")
                    }
                    .accessibilityIdentifier("log-view-clear-button")
                }
                .accessibilityIdentifier("log-view-header")
            }

            List {
                if entries.isEmpty {
                    Text(t("No logs", "ログはありません"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("log-view-empty-state")
                } else {
                    ForEach(entries) { entry in
                        LogEntryRow(entry: entry)
                    }
                }
            }
            .listStyle(.inset)
            .accessibilityIdentifier("log-view-entry-list")
            .frame(minHeight: 180)
        }
        .padding(showsHeader ? 16 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
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
