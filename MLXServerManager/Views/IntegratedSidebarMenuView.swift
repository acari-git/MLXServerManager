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
        VStack(alignment: .leading, spacing: 10) {
            Text(strings.text(english: "MENU", japanese: "メニュー"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(IntegratedWorkspaceDestination.allCases.filter { $0 != .settings }) { destination in
                Button {
                    selectedDestination = destination
                } label: {
                    sidebarRow(for: destination)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(selectedDestination == destination ? Color.accentColor.opacity(0.85) : Color.clear)
                        .foregroundStyle(selectedDestination == destination ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityIdentifier("integrated-sidebar-\(destination.rawValue)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
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
