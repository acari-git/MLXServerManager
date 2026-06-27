import AppKit
import SwiftUI

private struct VisualEffectBackdrop: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let emphasized: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
    }
}

private struct LiquidGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    let tintOpacity: Double
    let glassTintOpacity: Double
    let usesGlassEffect: Bool
    let strokeOpacity: Double
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowY: CGFloat
    let gradientOpacity: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    VisualEffectBackdrop(
                        material: material,
                        blendingMode: blendingMode,
                        emphasized: false
                    )
                    shape.fill(Color(nsColor: .controlBackgroundColor).opacity(tintOpacity))
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.11 * gradientOpacity),
                            Color(nsColor: .controlBackgroundColor).opacity(0.045 * gradientOpacity),
                            Color.black.opacity(0.010 * gradientOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .blendMode(.screen)
                }
                .clipShape(shape)
            }
            .modifier(
                OptionalLiquidGlassEffectModifier(
                    cornerRadius: cornerRadius,
                    tintOpacity: glassTintOpacity,
                    isEnabled: usesGlassEffect
                )
            )
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.12 * gradientOpacity), lineWidth: 0.6)
                    .blendMode(.screen)
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(strokeOpacity), lineWidth: 0.55)
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowY)
    }
}

private struct OptionalLiquidGlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tintOpacity: Double
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if isEnabled {
            content.glassEffect(
                .regular.tint(Color(nsColor: .controlBackgroundColor).opacity(tintOpacity)),
                in: shape
            )
        } else {
            content
        }
    }
}

struct PanelStyle: ViewModifier {
    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlassPanel(cornerRadius: cornerRadius)
    }
}

extension View {
    func panelStyle(cornerRadius: CGFloat = 12) -> some View {
        modifier(PanelStyle(cornerRadius: cornerRadius))
    }

    func liquidGlassPanel(cornerRadius: CGFloat = 12, fillOpacity: Double = 0.12) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                material: .popover,
                blendingMode: .withinWindow,
                tintOpacity: max(fillOpacity, 0.22),
                glassTintOpacity: max(0.010, fillOpacity * 0.08),
                usesGlassEffect: true,
                strokeOpacity: 0.050,
                shadowOpacity: 0.025,
                shadowRadius: 7,
                shadowY: 2,
                gradientOpacity: 0.28
            )
        )
    }

    func liquidGlassLayerOne(cornerRadius: CGFloat = 0) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                material: .contentBackground,
                blendingMode: .withinWindow,
                tintOpacity: 0.78,
                glassTintOpacity: 0.000,
                usesGlassEffect: false,
                strokeOpacity: 0.018,
                shadowOpacity: 0.00,
                shadowRadius: 0,
                shadowY: 0,
                gradientOpacity: 0.04
            )
        )
    }

    func liquidGlassLayerTwo(cornerRadius: CGFloat = 10) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                material: .popover,
                blendingMode: .withinWindow,
                tintOpacity: 0.36,
                glassTintOpacity: 0.014,
                usesGlassEffect: true,
                strokeOpacity: 0.050,
                shadowOpacity: 0.025,
                shadowRadius: 7,
                shadowY: 2,
                gradientOpacity: 0.20
            )
        )
    }

    func liquidGlassSidebar() -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: 0,
                material: .sidebar,
                blendingMode: .withinWindow,
                tintOpacity: 0.70,
                glassTintOpacity: 0.000,
                usesGlassEffect: false,
                strokeOpacity: 0.018,
                shadowOpacity: 0.00,
                shadowRadius: 0,
                shadowY: 0,
                gradientOpacity: 0.04
            )
        )
    }

    func liquidGlassWindowBackground() -> some View {
        background(Color(nsColor: .windowBackgroundColor))
    }

    func liquidGlassBar(cornerRadius: CGFloat = 0) -> some View {
        modifier(
            LiquidGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                material: .headerView,
                blendingMode: .withinWindow,
                tintOpacity: 0.34,
                glassTintOpacity: 0.010,
                usesGlassEffect: true,
                strokeOpacity: 0.04,
                shadowOpacity: 0.018,
                shadowRadius: 5,
                shadowY: 1,
                gradientOpacity: 0.18
            )
        )
    }
}

struct DetailGrid: View {
    let rows: [(String, String)]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 10) {
            ForEach(rows, id: \.0) { label, value in
                GridRow {
                    Text(label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)

                    Text(value)
                        .font(.callout)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
