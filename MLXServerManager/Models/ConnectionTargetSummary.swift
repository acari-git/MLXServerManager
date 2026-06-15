import Foundation

struct ConnectionTargetSummary: Hashable {
    let targetType: String
    let baseURL: String
    let modelID: String
    let apiKeyPlaceholder: String
    let readinessSummary: String
    let ownershipNote: String
    let directModeNote: String
    let isActiveTarget: Bool
}
