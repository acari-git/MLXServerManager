import SwiftUI

struct OnboardingGuidanceView: View {
    let guidance: OnboardingGuidance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Label(guidance.title, systemImage: iconName)
                    .font(.headline)
                    .foregroundStyle(accentColor)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(guidance.messages, id: \.self) { message in
                    Label(message, systemImage: "smallcircle.filled.circle")
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }

            if !guidance.actionHints.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Next")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(Array(guidance.actionHints.enumerated()), id: \.offset) { index, hint in
                        Text("\(index + 1). \(hint)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(guidance.directModeNote)
                Text(guidance.proxyBoundaryNote)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .panelStyle()
    }

    private var iconName: String {
        switch guidance.tone {
        case .setup:
            "wrench.and.screwdriver"
        case .neutral:
            "list.bullet.clipboard"
        case .ready:
            "checkmark.seal"
        case .warning:
            "exclamationmark.triangle"
        }
    }

    private var accentColor: Color {
        switch guidance.tone {
        case .setup:
            .blue
        case .neutral:
            .secondary
        case .ready:
            .green
        case .warning:
            .orange
        }
    }
}
