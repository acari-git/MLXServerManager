import SwiftUI

struct IntegratedSidebarMenuView: View {
    @Binding var selectedDestination: IntegratedWorkspaceDestination
    let language: AppLanguage
    let downloadPhase: HuggingFaceDownloadPhase
    let downloadProgress: Double?
    @State private var hoveredDestination: IntegratedWorkspaceDestination?

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private var selection: Binding<IntegratedWorkspaceDestination?> {
        Binding(
            get: { selectedDestination },
            set: { newValue in
                if let newValue {
                    selectedDestination = newValue
                }
            }
        )
    }

    var body: some View {
        List(selection: selection) {
            ForEach(IntegratedWorkspaceDestination.allCases) { destination in
                sidebarRow(for: destination)
                    .tag(destination)
                    .listRowBackground(sidebarHoverBackground(for: destination))
                    .onHover { isHovering in
                        hoveredDestination = isHovering ? destination : (hoveredDestination == destination ? nil : hoveredDestination)
                    }
                    .accessibilityIdentifier("integrated-sidebar-\(destination.rawValue)")
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func sidebarHoverBackground(for destination: IntegratedWorkspaceDestination) -> some View {
        if hoveredDestination == destination && selectedDestination != destination {
            Color(nsColor: .selectedContentBackgroundColor)
                .opacity(0.16)
        } else {
            Color.clear
        }
    }

    private func sidebarRow(for destination: IntegratedWorkspaceDestination) -> some View {
        HStack(spacing: 8) {
            Image(systemName: destination.systemImageName)
                .frame(width: 16)
            Text(destination.title(language: language))
                .font(.callout.weight(.medium))
            Spacer(minLength: 6)
            if destination == .downloads {
                downloadIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var downloadIndicator: some View {
        switch downloadPhase {
        case .preparing, .downloading, .finalizing:
            HStack(spacing: 4) {
                ProgressView(value: downloadProgress)
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
                if let downloadProgress {
                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                }
            }
            .accessibilityIdentifier("integrated-sidebar-download-progress")
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .accessibilityLabel(strings.text(english: "Download completed", japanese: "ダウンロード完了"))
                .accessibilityIdentifier("integrated-sidebar-download-completed")
        default:
            EmptyView()
        }
    }
}
