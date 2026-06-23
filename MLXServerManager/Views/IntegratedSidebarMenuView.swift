import SwiftUI

struct IntegratedSidebarMenuView: View {
    @Binding var selectedDestination: IntegratedWorkspaceDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MENU")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)

            ForEach(IntegratedWorkspaceDestination.allCases) { destination in
                Button {
                    selectedDestination = destination
                } label: {
                    Label(destination.title, systemImage: destination.systemImageName)
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
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
}
