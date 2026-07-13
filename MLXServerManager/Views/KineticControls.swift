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

enum KineticCopyFeedbackStyle {
    case replace
    case trailingOverlay
}

struct KineticCopyButton<IdleLabel: View>: View {
    let feedbackTitle: String?
    let feedbackStyle: KineticCopyFeedbackStyle
    let action: () -> Void
    private let idleLabel: IdleLabel

    @State private var isShowingFeedback = false
    @State private var feedbackGeneration = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        feedbackTitle: String? = nil,
        feedbackStyle: KineticCopyFeedbackStyle = .replace,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> IdleLabel
    ) {
        self.feedbackTitle = feedbackTitle
        self.feedbackStyle = feedbackStyle
        self.action = action
        self.idleLabel = label()
    }

    var body: some View {
        Button {
            action()
            showFeedback()
        } label: {
            ZStack(alignment: .trailing) {
                idleLabel
                    .opacity(feedbackStyle == .replace && isShowingFeedback ? 0 : 1)

                if isShowingFeedback {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                        if let feedbackTitle, feedbackStyle == .replace {
                            Text(feedbackTitle)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.green)
                    .padding(.trailing, feedbackStyle == .trailingOverlay ? 2 : 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.84)))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86), value: isShowingFeedback)
        }
        .accessibilityValue(isShowingFeedback ? (feedbackTitle ?? "Copied") : "")
    }

    private func showFeedback() {
        feedbackGeneration += 1
        let generation = feedbackGeneration
        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.86)) {
            isShowingFeedback = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            guard generation == feedbackGeneration else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                isShowingFeedback = false
            }
        }
    }
}

struct KineticDisclosureSection<Label: View, Content: View>: View {
    let contentTopPadding: CGFloat
    private let label: Label
    private let content: Content

    @State private var isExpanded: Bool

    init(
        initiallyExpanded: Bool = false,
        contentTopPadding: CGFloat = 0,
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.contentTopPadding = contentTopPadding
        self.label = label()
        self.content = content()
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, contentTopPadding)
        } label: {
            label
        }
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}

private struct KineticShakeEffect: GeometryEffect {
    var amount: CGFloat = 3
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amount * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

private struct KineticValidationFeedbackModifier: ViewModifier {
    let isInvalid: Bool
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isInvalid {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.red.opacity(0.82), lineWidth: 1.2)
                        .allowsHitTesting(false)
                }
            }
            .modifier(
                KineticShakeEffect(
                    amount: reduceMotion ? 0 : 3,
                    shakesPerUnit: 3,
                    animatableData: CGFloat(trigger)
                )
            )
    }
}

extension View {
    func kineticValidationFeedback(isInvalid: Bool, trigger: Int) -> some View {
        modifier(KineticValidationFeedbackModifier(isInvalid: isInvalid, trigger: trigger))
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
