import Foundation

nonisolated enum NetworkExposureAssessment: Equatable {
    case localOnly
    case networkAccessible(host: String)

    var requiresExplicitStartConfirmation: Bool {
        if case .networkAccessible = self {
            return true
        }
        return false
    }

    func safetyText(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .localOnly:
            return strings.text(english: "Local only", japanese: "ローカルのみ")
        case .networkAccessible:
            return strings.text(
                english: "Warning: reachable beyond this Mac",
                japanese: "警告: このMac以外から到達可能"
            )
        }
    }

    func confirmationTitle(language: AppLanguage) -> String {
        AppLocalization(language: language).text(
            english: "Expose the server to the network?",
            japanese: "サーバーをネットワークへ公開しますか？"
        )
    }

    func confirmationDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .localOnly:
            return strings.text(
                english: "This endpoint is limited to this Mac.",
                japanese: "このエンドポイントはこのMac内に限定されています。"
            )
        case let .networkAccessible(host):
            return strings.text(
                english: "Host \(host) can accept connections from outside this Mac. mlx_lm.server does not provide production-grade authentication. Continue only on a trusted network.",
                japanese: "Host \(host) はこのMac以外から接続できる可能性があります。mlx_lm.serverには本番運用向けの認証機能がありません。信頼できるネットワークでのみ続行してください。"
            )
        }
    }
}

nonisolated enum NetworkExposureAdvisor {
    static func assess(host: String) -> NetworkExposureAssessment {
        let normalized = normalize(host)
        if isLoopback(normalized) {
            return .localOnly
        }
        return .networkAccessible(host: normalized.isEmpty ? host : normalized)
    }

    private static func normalize(_ host: String) -> String {
        var normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.hasPrefix("["), normalized.hasSuffix("]") {
            normalized.removeFirst()
            normalized.removeLast()
        }
        while normalized.hasSuffix(".") {
            normalized.removeLast()
        }
        return normalized
    }

    private static func isLoopback(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") || host == "::1" {
            return true
        }

        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4,
              octets.allSatisfy({ octet in
                  guard let value = Int(octet) else { return false }
                  return (0...255).contains(value)
              }) else {
            return false
        }
        return octets.first == "127"
    }
}
