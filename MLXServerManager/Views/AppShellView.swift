import SwiftUI

/// Native macOS app shell for staged top-level navigation.
///
/// The shell owns only navigation selection. It does not own process control,
/// networking, persistence, import/export, or inference behavior.
/// v6.0.x intentionally exposes Dashboard as the only active section while
/// preserving room for later staged destinations.
struct AppShellView<Content: View>: View {
    @Binding var selectedSection: AppSection
    var language: AppLanguage = .english
    @ViewBuilder var content: (AppSection) -> Content

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                AppSectionSidebarRow(section: section, language: language)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("MLX Server Manager")
            .accessibilityIdentifier("app-shell-sidebar")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            content(selectedSection)
                .navigationTitle(selectedSection.localizedTitle(language: language))
                .accessibilityIdentifier("app-shell-detail-\(selectedSection.rawValue)")
        }
    }
}

private struct AppSectionSidebarRow: View {
    let section: AppSection
    let language: AppLanguage

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.localizedTitle(language: language))
                    .font(.body.weight(.medium))
                Text(section.localizedSubtitle(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: section.systemImageName)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.localizedTitle(language: language))
        .accessibilityHint(section.localizedSubtitle(language: language))
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }
}

#Preview {
    @Previewable @State var selectedSection = AppSection.dashboard

    AppShellView(selectedSection: $selectedSection) { section in
        Text(section.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
