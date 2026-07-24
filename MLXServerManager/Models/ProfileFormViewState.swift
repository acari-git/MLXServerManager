import Foundation

nonisolated struct ProfileFormViewState: Equatable {
    private(set) var draft: ModelProfileDraft
    private(set) var isPresented: Bool
    private(set) var message: String?
    private(set) var portSuggestionMessage: String?

    static let hidden = ProfileFormViewState(
        draft: .empty,
        isPresented: false,
        message: nil,
        portSuggestionMessage: nil
    )

    mutating func present(
        draft: ModelProfileDraft,
        message: String? = nil,
        portSuggestionMessage: String? = nil
    ) {
        self.draft = draft
        isPresented = true
        self.message = message
        self.portSuggestionMessage = portSuggestionMessage
    }

    mutating func dismiss() {
        draft = .empty
        isPresented = false
        message = nil
        portSuggestionMessage = nil
    }

    mutating func setDraft(_ draft: ModelProfileDraft) {
        self.draft = draft
    }

    mutating func setMessage(_ message: String?) {
        self.message = message
    }

    mutating func setPortSuggestionMessage(_ message: String?) {
        portSuggestionMessage = message
    }

    mutating func applyPortSuggestion(
        portText: String,
        message: String?
    ) {
        draft.serverPortText = portText
        portSuggestionMessage = message
    }
}
