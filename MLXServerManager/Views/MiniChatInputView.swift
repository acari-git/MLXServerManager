import SwiftUI
import AppKit

struct MiniChatInputView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @Binding var isFocused: Bool
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        textView.string = text
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.onSubmit = onSubmit
        guard !textView.hasMarkedText() else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @Binding var isFocused: Bool
        var onSubmit: () -> Void
        weak var textView: NSTextView?

        init(text: Binding<String>, isFocused: Binding<Bool>, onSubmit: @escaping () -> Void) {
            _text = text
            _isFocused = isFocused
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            isFocused = false
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }

            guard !textView.hasMarkedText() else {
                return false
            }

            if NSEvent.modifierFlags.contains(.shift) {
                textView.insertNewlineIgnoringFieldEditor(nil)
                text = textView.string
            } else {
                onSubmit()
            }
            return true
        }
    }
}
