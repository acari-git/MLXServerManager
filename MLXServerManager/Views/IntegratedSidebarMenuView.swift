import SwiftUI

struct IntegratedSidebarMenuView: View {
    @Binding var selectedDestination: IntegratedWorkspaceDestination
    let language: AppLanguage
    let downloadPhase: HuggingFaceDownloadPhase
    let downloadProgress: Double?

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(IntegratedWorkspaceDestination.allCases.filter { $0 != .settings }) { destination in
                sidebarRow(for: destination)
                    .background(sidebarBackground(for: destination))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onLongPressGesture(minimumDuration: 0, maximumDistance: 40) {
                        selectedDestination = destination
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("integrated-sidebar-\(destination.rawValue)")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func sidebarBackground(for destination: IntegratedWorkspaceDestination) -> some View {
        if selectedDestination == destination {
            Color(nsColor: .controlAccentColor)
                .opacity(0.92)
        } else {
            Color.clear
        }
    }

    private func sidebarRow(for destination: IntegratedWorkspaceDestination) -> some View {
        HStack(spacing: 8) {
            Image(systemName: destination.systemImageName)
                .font(.system(size: 16, weight: .regular))
                .frame(width: 18)
            Text(destination.title(language: language))
                .font(.system(size: 16, weight: .regular))
            Spacer(minLength: 6)
            if destination == .downloads {
                downloadIndicator
            }
        }
        .foregroundStyle(selectedDestination == destination ? Color.white : Color.primary)
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
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
