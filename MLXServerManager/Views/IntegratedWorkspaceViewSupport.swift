import AppKit
import SwiftUI

struct OptionalInspectorHelp: ViewModifier {
    let helpText: String?
    @State private var isHovering = false
    @State private var isPresented = false
    @State private var hoverGeneration = 0

    @ViewBuilder
    func body(content: Content) -> some View {
        if let helpText = helpText?.trimmingCharacters(in: .whitespacesAndNewlines), !helpText.isEmpty {
            content
                .onHover { hovering in
                    hoverGeneration += 1
                    isHovering = hovering
                    if hovering {
                        let generation = hoverGeneration
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                            guard isHovering, generation == hoverGeneration else {
                                return
                            }
                            isPresented = true
                        }
                    } else {
                        isPresented = false
                    }
                }
                .popover(
                    isPresented: $isPresented,
                    attachmentAnchor: .rect(.bounds),
                    arrowEdge: .bottom
                ) {
                    InspectorHelpSystemPopoverContent(text: helpText)
                        .presentationBackground(Color(nsColor: .textBackgroundColor))
                }
                .accessibilityHint(helpText)
        } else {
            content
        }
    }
}

extension View {
    func optionalInspectorHelp(_ helpText: String?) -> some View {
        modifier(OptionalInspectorHelp(helpText: helpText))
    }
}

struct InspectorHelpSystemPopoverContent: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.primary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 280, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .allowsHitTesting(false)
    }
}

struct InspectorVisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .behindWindow
        nsView.state = .active
        nsView.isEmphasized = false
    }
}
