import Foundation

struct BenchmarkChatMessage: Codable, Equatable {
    let role: String
    let content: String
}

struct BenchmarkChatTemplateKwargs: Codable, Equatable {
    let enableThinking: Bool

    enum CodingKeys: String, CodingKey {
        case enableThinking = "enable_thinking"
    }
}

struct BenchmarkResponseFormat: Codable, Equatable {
    let type: String
}

struct BenchmarkStreamOptions: Codable, Equatable {
    let includeUsage: Bool

    enum CodingKeys: String, CodingKey {
        case includeUsage = "include_usage"
    }
}

struct BenchmarkChatCompletionRequest: Encodable, Equatable {
    let model: String
    let messages: [BenchmarkChatMessage]
    let stream: Bool
    let maxTokens: Int
    let temperature: Double
    let chatTemplateKwargs: BenchmarkChatTemplateKwargs?
    let responseFormat: BenchmarkResponseFormat?
    let streamOptions: BenchmarkStreamOptions?

    init(
        model: String,
        messages: [BenchmarkChatMessage],
        stream: Bool,
        maxTokens: Int,
        temperature: Double,
        chatTemplateKwargs: BenchmarkChatTemplateKwargs?,
        responseFormat: BenchmarkResponseFormat? = nil,
        streamOptions: BenchmarkStreamOptions? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.chatTemplateKwargs = chatTemplateKwargs
        self.responseFormat = responseFormat
        self.streamOptions = streamOptions
    }

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case chatTemplateKwargs = "chat_template_kwargs"
        case responseFormat = "response_format"
        case streamOptions = "stream_options"
    }
}

struct OpenAICompatibleChatUsage: Decodable, Equatable {
    let completionTokens: Int?

    enum CodingKeys: String, CodingKey {
        case completionTokens = "completion_tokens"
    }
}

struct OpenAICompatibleChatResponse: Decodable, Equatable {
    struct Choice: Decodable, Equatable {
        struct Message: Decodable, Equatable {
            let content: String?
            let reasoning: String?
            let reasoningContent: String?

            enum CodingKeys: String, CodingKey {
                case content
                case reasoning
                case reasoningContent = "reasoning_content"
            }
        }

        let message: Message?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct ErrorPayload: Decodable, Equatable {
        let message: String?
    }

    let choices: [Choice]?
    let usage: OpenAICompatibleChatUsage?
    let error: ErrorPayload?
    let systemFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case choices
        case usage
        case error
        case systemFingerprint = "system_fingerprint"
    }
}

struct BenchmarkStreamingChatChunk: Decodable, Equatable {
    struct Choice: Decodable, Equatable {
        struct Delta: Decodable, Equatable {
            let content: String?
            let reasoning: String?
            let reasoningContent: String?

            enum CodingKeys: String, CodingKey {
                case content
                case reasoning
                case reasoningContent = "reasoning_content"
            }
        }

        let delta: Delta?
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct ErrorPayload: Decodable, Equatable {
        let message: String?
    }

    let choices: [Choice]?
    let usage: OpenAICompatibleChatUsage?
    let error: ErrorPayload?
    let systemFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case choices
        case usage
        case error
        case systemFingerprint = "system_fingerprint"
    }
}

enum BenchmarkTokenCountResolver {
    nonisolated static func outputTokenCount(reported: Int?, output: String) -> Int {
        if let reported, reported >= 0 {
            return reported
        }
        return BenchmarkTokenEstimator.estimatedTokenCount(output)
    }
}

enum OpenAICompatibleChatSupport {
    nonisolated static func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmed)/chat/completions")
    }

    nonisolated static func shouldRetryWithoutThinkingControl(statusCode: Int?, message: String?) -> Bool {
        guard statusCode == 400 || statusCode == 422 else {
            return false
        }
        let normalized = message?.lowercased() ?? ""
        return normalized.contains("chat_template_kwargs")
            || normalized.contains("chat template kwargs")
            || normalized.contains("enable_thinking")
            || normalized.contains("extra_forbidden")
    }

    nonisolated static func shouldRetryWithoutResponseFormat(statusCode: Int?, message: String?) -> Bool {
        guard statusCode == 400 || statusCode == 422 else {
            return false
        }
        let normalized = message?.lowercased() ?? ""
        return normalized.contains("response_format")
            || normalized.contains("response format")
    }

    nonisolated static func shouldRetryWithoutStreamOptions(statusCode: Int?, message: String?) -> Bool {
        guard statusCode == 400 || statusCode == 422 else {
            return false
        }
        let normalized = message?.lowercased() ?? ""
        return normalized.contains("stream_options")
            || normalized.contains("stream options")
            || normalized.contains("include_usage")
    }

    nonisolated static func httpErrorMessage(statusCode: Int?, data: Data? = nil) -> String {
        let body = data.flatMap { String(data: $0, encoding: .utf8) }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let body, !body.isEmpty {
            return "HTTP \(statusCode.map(String.init) ?? "-") from /chat/completions: \(body)"
        }
        return "HTTP \(statusCode.map(String.init) ?? "-") from /chat/completions"
    }
}
