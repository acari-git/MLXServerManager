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
        """
        Base URL: \(baseURL)
        Model: \(modelID)
        API Key: \(apiKeyPlaceholder)
        """
    }
}

