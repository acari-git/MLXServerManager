import Foundation

nonisolated struct MiniChatTranscriptMessage: Identifiable, Equatable, Sendable {
    nonisolated enum Sender: Equatable, Sendable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let sender: Sender
    let content: String

    init(
        id: UUID = UUID(),
        sender: Sender,
        content: String
    ) {
        self.id = id
        self.sender = sender
        self.content = content
    }
}

nonisolated struct MiniChatViewState: Equatable, Sendable {
    private(set) var prompt: String
    private(set) var messages: [MiniChatTranscriptMessage]
    private(set) var response: String
    private(set) var status: String
    private(set) var httpStatusText: String
    private(set) var durationText: String
    private(set) var isRunning: Bool

    static let ready = MiniChatViewState(
        prompt: "",
        messages: [],
        response: "",
        status: "Ready.",
        httpStatusText: "-",
        durationText: "-",
        isRunning: false
    )

    mutating func setPrompt(_ prompt: String) {
        self.prompt = prompt
    }

    mutating func setStatus(_ status: String) {
        self.status = status
    }

    mutating func beginRequest(
        prompt: String,
        status: String
    ) {
        self.prompt = ""
        messages.append(
            MiniChatTranscriptMessage(
                sender: .user,
                content: prompt
            )
        )
        response = ""
        self.status = status
        httpStatusText = "-"
        durationText = "-"
        isRunning = true
    }

    mutating func completeRequest(
        response: String,
        sender: MiniChatTranscriptMessage.Sender,
        status: String,
        httpStatusText: String,
        durationText: String
    ) {
        self.response = response
        messages.append(
            MiniChatTranscriptMessage(
                sender: sender,
                content: response
            )
        )
        self.status = status
        self.httpStatusText = httpStatusText
        self.durationText = durationText
        isRunning = false
    }

    mutating func cancelRequest(
        status: String,
        appendTranscript: Bool
    ) {
        self.status = status
        if appendTranscript {
            messages.append(
                MiniChatTranscriptMessage(
                    sender: .system,
                    content: status
                )
            )
        }
        isRunning = false
    }

    mutating func failRequest(
        message: String,
        status: String
    ) {
        response = message
        messages.append(
            MiniChatTranscriptMessage(
                sender: .system,
                content: message
            )
        )
        self.status = status
        httpStatusText = "-"
        durationText = "-"
        isRunning = false
    }

    mutating func clearConversation() {
        prompt = ""
        messages = []
        response = ""
        status = "Ready."
        httpStatusText = "-"
        durationText = "-"
    }
}
