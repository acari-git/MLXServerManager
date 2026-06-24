import AppKit
import SwiftUI

struct TitlebarPanelControlsInstaller: NSViewRepresentable {
    @Binding var isLeftPanelVisible: Bool
    @Binding var isBottomPanelVisible: Bool
    @Binding var isRightPanelVisible: Bool
    let onLeftToggle: () -> Void
    let onBottomToggle: () -> Void
    let onRightToggle: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isLeftPanelVisible: $isLeftPanelVisible,
            isBottomPanelVisible: $isBottomPanelVisible,
            isRightPanelVisible: $isRightPanelVisible,
            onLeftToggle: onLeftToggle,
            onBottomToggle: onBottomToggle,
            onRightToggle: onRightToggle
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.install(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isLeftPanelVisible = $isLeftPanelVisible
        context.coordinator.isBottomPanelVisible = $isBottomPanelVisible
        context.coordinator.isRightPanelVisible = $isRightPanelVisible
        context.coordinator.onLeftToggle = onLeftToggle
        context.coordinator.onBottomToggle = onBottomToggle
        context.coordinator.onRightToggle = onRightToggle
        DispatchQueue.main.async {
            context.coordinator.install(from: nsView)
            context.coordinator.refresh()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator {
        var isLeftPanelVisible: Binding<Bool>
        var isBottomPanelVisible: Binding<Bool>
        var isRightPanelVisible: Binding<Bool>
        var onLeftToggle: () -> Void
        var onBottomToggle: () -> Void
        var onRightToggle: () -> Void

        private weak var installedWindow: NSWindow?
        private weak var titlebarContainer: NSView?
        private var leftView: NSHostingView<AnyView>?
        private var centerTitleView: NSHostingView<AnyView>?
        private var rightView: NSHostingView<AnyView>?
        private var windowDidResizeObserver: NSObjectProtocol?

        init(
            isLeftPanelVisible: Binding<Bool>,
            isBottomPanelVisible: Binding<Bool>,
            isRightPanelVisible: Binding<Bool>,
            onLeftToggle: @escaping () -> Void,
            onBottomToggle: @escaping () -> Void,
            onRightToggle: @escaping () -> Void
        ) {
            self.isLeftPanelVisible = isLeftPanelVisible
            self.isBottomPanelVisible = isBottomPanelVisible
            self.isRightPanelVisible = isRightPanelVisible
            self.onLeftToggle = onLeftToggle
            self.onBottomToggle = onBottomToggle
            self.onRightToggle = onRightToggle
        }

        func install(from view: NSView) {
            guard let window = view.window,
                  let closeButton = window.standardWindowButton(.closeButton),
                  let titlebarContainer = closeButton.superview else {
                return
            }

            if installedWindow !== window || self.titlebarContainer !== titlebarContainer {
                uninstall()
                installedWindow = window
                self.titlebarContainer = titlebarContainer

                window.titleVisibility = .hidden

                let left = NSHostingView(rootView: AnyView(leftControls))
                left.translatesAutoresizingMaskIntoConstraints = false
                titlebarContainer.addSubview(left)
                leftView = left

                let centerTitle = NSHostingView(rootView: AnyView(centerTitle))
                centerTitle.translatesAutoresizingMaskIntoConstraints = false
                titlebarContainer.addSubview(centerTitle)
                centerTitleView = centerTitle

                let right = NSHostingView(rootView: AnyView(rightControls))
                right.translatesAutoresizingMaskIntoConstraints = false
                titlebarContainer.addSubview(right)
                rightView = right

                NSLayoutConstraint.activate([
                    left.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 54),
                    left.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
                    left.widthAnchor.constraint(equalToConstant: 24),
                    left.heightAnchor.constraint(equalToConstant: 22),

                    centerTitle.centerXAnchor.constraint(equalTo: titlebarContainer.centerXAnchor),
                    centerTitle.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
                    centerTitle.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
                    centerTitle.heightAnchor.constraint(equalToConstant: 22),

                    right.trailingAnchor.constraint(equalTo: titlebarContainer.trailingAnchor, constant: -12),
                    right.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
                    right.widthAnchor.constraint(equalToConstant: 56),
                    right.heightAnchor.constraint(equalToConstant: 22)
                ])

                windowDidResizeObserver = NotificationCenter.default.addObserver(
                    forName: NSWindow.didResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.refresh()
                }
            }

            refresh()
        }

        func uninstall() {
            if let windowDidResizeObserver {
                NotificationCenter.default.removeObserver(windowDidResizeObserver)
                self.windowDidResizeObserver = nil
            }
            leftView?.removeFromSuperview()
            centerTitleView?.removeFromSuperview()
            rightView?.removeFromSuperview()
            leftView = nil
            centerTitleView = nil
            rightView = nil
            installedWindow = nil
            titlebarContainer = nil
        }

        func refresh() {
            leftView?.rootView = AnyView(leftControls)
            centerTitleView?.rootView = AnyView(centerTitle)
            rightView?.rootView = AnyView(rightControls)
        }

        private var leftControls: some View {
            titlebarIcon(
                systemImage: "sidebar.left",
                isActive: isLeftPanelVisible.wrappedValue,
                help: isLeftPanelVisible.wrappedValue ? "左サイドパネルを隠す" : "左サイドパネルを表示",
                action: onLeftToggle
            )
        }

        private var centerTitle: some View {
            Text("MLX Server Manager")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .background(Color.clear)
        }

        private var rightControls: some View {
            HStack(spacing: 8) {
                titlebarIcon(
                    systemImage: "rectangle.bottomthird.inset.filled",
                    isActive: isBottomPanelVisible.wrappedValue,
                    help: isBottomPanelVisible.wrappedValue ? "下段ログパネルを隠す" : "下段ログパネルを表示",
                    action: onBottomToggle
                )
                titlebarIcon(
                    systemImage: "sidebar.right",
                    isActive: isRightPanelVisible.wrappedValue,
                    help: isRightPanelVisible.wrappedValue ? "右サイドパネルを隠す" : "右サイドパネルを表示",
                    action: onRightToggle
                )
            }
        }

        private func titlebarIcon(systemImage: String, isActive: Bool, help: String, action: @escaping () -> Void) -> some View {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        action()
                    }
                }
                .help(help)
        }
    }
}
