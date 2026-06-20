import SwiftUI

/// Native macOS app shell for staged top-level navigation.
///
/// The shell owns only navigation selection. It does not own process control,
/// networking, persistence, import/export, or inference behavior.
struct AppShellView<Content: View>: View {
    @Binding var selectedSection: AppSection
    @ViewBuilder var content: (AppSection) -> Content

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                AppSectionSidebarRow(section: section)
                    .tag(section)
            }
            .navigationTitle("MLX Server Manager")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            content(selectedSection)
                .navigationTitle(selectedSection.title)
        }
    }
}

private struct AppSectionSidebarRow: View {
    let section: AppSection

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.body.weight(.medium))
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: section.systemImageName)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var selectedSection = AppSection.dashboard

    AppShellView(selectedSection: $selectedSection) { section in
        Text(section.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
