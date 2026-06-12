import Foundation

struct ConnectionConfigBuilder {
    let scheme: String
    let host: String
    let port: Int
    let apiBasePath: String
    let apiKeyPlaceholder: String

    var baseURL: String {
        "\(scheme)://\(host):\(port)\(apiBasePath)"
    }

    func configText(modelID: String) -> String {
        let config = [
            "base_url": baseURL,
            "api_key": apiKeyPlaceholder,
            "model": modelID
        ]

        return jsonString(from: config)
    }

    func modelsCurlCommand() -> String {
        "curl \(baseURL)/models"
    }

    func chatCompletionsCurlCommand(modelID: String) -> String {
        let payload: [String: Any] = [
            "model": modelID,
            "messages": [
                [
                    "role": "user",
                    "content": "こんにちは"
                ]
            ],
            "max_tokens": 128,
            "chat_template_kwargs": [
                "enable_thinking": false
            ]
        ]

        return """
        curl \(baseURL)/chat/completions \\
          -H "Content-Type: application/json" \\
          -H "Authorization: Bearer \(apiKeyPlaceholder)" \\
          -d '\(jsonString(from: payload))'
        """
    }

    private func jsonString(from object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
              ),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return text.replacingOccurrences(of: "\\/", with: "/")
    }
}
