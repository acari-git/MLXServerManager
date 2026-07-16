import Foundation

nonisolated enum InferenceBackend: String, Codable, CaseIterable, Hashable, Identifiable {
    case mlxLM = "mlx-lm"
    case rapidMLX = "rapid-mlx"

    var id: String { rawValue }

    var defaultExecutableName: String {
        switch self {
        case .mlxLM:
            "mlx_lm.server"
        case .rapidMLX:
            "rapid-mlx"
        }
    }

    func localizedTitle(language: AppLanguage) -> String {
        switch self {
        case .mlxLM:
            "mlx-lm"
        case .rapidMLX:
            "Rapid-MLX"
        }
    }

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .mlxLM:
            return strings.text(
                english: "Starts mlx_lm.server directly for this model.",
                japanese: "このモデルをmlx_lm.serverで直接起動します。"
            )
        case .rapidMLX:
            return strings.text(
                english: "Starts a dedicated Rapid-MLX server process for this model.",
                japanese: "このモデル専用のRapid-MLXサーバープロセスを起動します。"
            )
        }
    }
}
