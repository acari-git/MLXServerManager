import Foundation

nonisolated enum HuggingFaceCacheDeletionOutcome: Equatable, Sendable {
    case deleted
    case notFound
    case failed(String)
}

nonisolated protocol HuggingFaceCacheDeleting: Sendable {
    func deleteCache(at cacheURL: URL) async -> HuggingFaceCacheDeletionOutcome
}

nonisolated struct HuggingFaceCacheDeletionService: HuggingFaceCacheDeleting {
    func deleteCache(at cacheURL: URL) async -> HuggingFaceCacheDeletionOutcome {
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: cacheURL.path) else {
                return .notFound
            }

            do {
                try fileManager.removeItem(at: cacheURL)
                return .deleted
            } catch {
                return .failed(error.localizedDescription)
            }
        }.value
    }
}
