import SwiftUI

enum KineticActionPhase: Equatable {
    case idle
    case working
    case success
    case failure
}

struct KineticActionLabel: View {
    let title: String
    let workingTitle: String
    let successTitle: String
    let failureTitle: String
    let systemImage: String
    let phase: KineticActionPhase
    var expandsHorizontally = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayedTitle: String {
        switch phase {
        case .idle:
            title
        case .working:
            workingTitle
        case .success:
            successTitle
        case .failure:
            failureTitle
        }
    }

    private var displayedSymbol: String {
        switch phase {
        case .idle:
            systemImage
        case .working:
            systemImage
        case .success:
            "checkmark"
        case .failure:
            "exclamationmark"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Group {
                if phase == .working {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: displayedSymbol)
                        .font(.caption.weight(.semibold))
                }
            }
            .frame(width: 13, height: 13)
            .transition(.opacity.combined(with: .scale(scale: 0.88)))

            Text(displayedTitle)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: expandsHorizontally ? .infinity : nil)
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: phase)
        .accessibilityLabel(displayedTitle)
    }
}

struct KineticStatusPillLabel: View {
    let title: String
    let systemImage: String
    let isBusy: Bool
    let foregroundColor: Color
    let backgroundColor: Color
    let borderColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 5) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(foregroundColor)
                } else {
                    Image(systemName: systemImage)
                        .font(.caption2.weight(.bold))
                }
            }
            .frame(width: 11, height: 11)
            .transition(.opacity.combined(with: .scale(scale: 0.82)))

            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .foregroundStyle(foregroundColor)
        .background(
            Capsule(style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(borderColor, lineWidth: 0.75)
        )
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.84), value: title)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.84), value: isBusy)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.20), value: backgroundColor)
        .accessibilityLabel(title)
    }
}

struct KineticIndeterminateBar: View {
    @State private var movesToTrailingEdge = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let segmentWidth = max(proxy.size.width * 0.34, 28)
            let travelDistance = max(proxy.size.width - segmentWidth, 0)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(0.14))

                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.82))
                    .frame(width: segmentWidth)
                    .offset(x: movesToTrailingEdge ? travelDistance : 0)
            }
        }
        .frame(height: 3)
        .onAppear {
            guard !reduceMotion else { return }
            movesToTrailingEdge = false
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                movesToTrailingEdge = true
            }
        }
        .onDisappear {
            movesToTrailingEdge = false
        }
        .accessibilityHidden(true)
    }
}
