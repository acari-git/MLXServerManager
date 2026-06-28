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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(IntegratedWorkspaceDestination.allCases) { destination in
                Button {
                    selectedDestination = destination
                } label: {
                    sidebarRow(for: destination)
                }
                .buttonStyle(.plain)
                .background(sidebarBackground(for: destination))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { isHovering in
                    hoveredDestination = isHovering ? destination : (hoveredDestination == destination ? nil : hoveredDestination)
                }
                .accessibilityIdentifier("integrated-sidebar-\(destination.rawValue)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 52)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func sidebarBackground(for destination: IntegratedWorkspaceDestination) -> some View {
        if selectedDestination == destination {
            Color(nsColor: .controlAccentColor)
                .opacity(0.92)
        } else if hoveredDestination == destination {
            Color(nsColor: .selectedContentBackgroundColor)
                .opacity(0.18)
        } else {
            Color.clear
        }
    }

    private func sidebarRow(for destination: IntegratedWorkspaceDestination) -> some View {
        HStack(spacing: 8) {
            Image(systemName: destination.systemImageName)
                .frame(width: 16)
            Text(destination.title(language: language))
                .font(.body.weight(.semibold))
            Spacer(minLength: 6)
            if destination == .downloads {
                downloadIndicator
            }
        }
        .foregroundStyle(selectedDestination == destination ? Color.white : Color.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
