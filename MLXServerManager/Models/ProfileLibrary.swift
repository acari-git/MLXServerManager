import Foundation

nonisolated enum ProfileLibrarySortOrder: String, CaseIterable, Identifiable {
    case favorites
    case name
    case backend
    case port

    var id: String { rawValue }
}

nonisolated enum ProfileUsageCategory: String, Codable, CaseIterable, Identifiable {
    case general
    case coding
    case agent
    case chat
    case benchmark

    var id: String { rawValue }
}

nonisolated struct ProfileLibraryMetadata: Codable, Equatable {
    var isFavorite: Bool = false
    var category: ProfileUsageCategory = .general
    var tags: [String] = []

    mutating func normalize() {
        tags = Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

nonisolated struct ProfileLibraryItem: Identifiable, Equatable {
    let model: ModelConfig
    let metadata: ProfileLibraryMetadata

    var id: String { model.id }
    var searchText: String {
        [
            model.displayName,
            model.modelID,
            model.family,
            model.quantization,
            model.localName,
            model.host,
            String(model.serverPort),
            model.notes,
            model.resolvedBackend.rawValue,
            metadata.category.rawValue,
            metadata.tags.joined(separator: "\n")
        ].joined(separator: "\n")
    }
}

nonisolated enum ProfileLibraryMetadataStore {
    static let defaultsKey = "profile-library-metadata-v1"

    static func load(defaults: UserDefaults = .standard) -> [String: ProfileLibraryMetadata] {
        guard let data = defaults.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: ProfileLibraryMetadata].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func save(_ metadata: [String: ProfileLibraryMetadata], defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    @discardableResult
    static func reconcile(
        validModelIDs: Set<String>,
        renamedModelID: (old: String, new: String)? = nil,
        defaults: UserDefaults = .standard
    ) -> [String: ProfileLibraryMetadata] {
        var metadata = load(defaults: defaults)
        if let renamedModelID,
           renamedModelID.old != renamedModelID.new,
           let migrated = metadata.removeValue(forKey: renamedModelID.old) {
            metadata[renamedModelID.new] = migrated
        }
        metadata = metadata.filter { validModelIDs.contains($0.key) }
        save(metadata, defaults: defaults)
        return metadata
    }
}

nonisolated enum ProfileLibraryRecentStore {
    static let defaultsKey = "profile-library-recent-v1"
    static let maximumCount = 8

    static func load(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: defaultsKey) ?? []
    }

    @discardableResult
    static func record(_ modelID: String, defaults: UserDefaults = .standard) -> [String] {
        var values = load(defaults: defaults).filter { $0 != modelID }
        values.insert(modelID, at: 0)
        values = Array(values.prefix(maximumCount))
        defaults.set(values, forKey: defaultsKey)
        return values
    }

    @discardableResult
    static func reconcile(
        validModelIDs: Set<String>,
        renamedModelID: (old: String, new: String)? = nil,
        defaults: UserDefaults = .standard
    ) -> [String] {
        var values = load(defaults: defaults)
        if let renamedModelID, renamedModelID.old != renamedModelID.new {
            values = values.map { $0 == renamedModelID.old ? renamedModelID.new : $0 }
        }
        var seen: Set<String> = []
        values = values.filter { validModelIDs.contains($0) && seen.insert($0).inserted }
        values = Array(values.prefix(maximumCount))
        defaults.set(values, forKey: defaultsKey)
        return values
    }
}

nonisolated enum ProfileLibraryPreset: Hashable, Identifiable {
    case all
    case favorites
    case recent
    case category(ProfileUsageCategory)
    case tag(String)

    var id: String {
        switch self {
        case .all: "all"
        case .favorites: "favorites"
        case .recent: "recent"
        case let .category(category): "category:\(category.rawValue)"
        case let .tag(tag): "tag:\(tag.lowercased())"
        }
    }
}

nonisolated struct ProfileComparisonRow: Identifiable, Equatable {
    let key: String
    let values: [String]

    var id: String { key }
    var hasDifference: Bool { Set(values).count > 1 }
}

nonisolated struct ProfileLibraryReconciledState: Equatable {
    let metadataByModelID: [String: ProfileLibraryMetadata]
    let recentModelIDs: [String]
    let comparisonModelIDs: Set<String>
}

nonisolated struct ProfileCompositionSelection: Equatable {
    var identityModelID: String
    var runtimeModelID: String
    var tuningModelID: String
    var notesModelID: String

    static func initial(models: [ModelConfig]) -> ProfileCompositionSelection? {
        guard let first = models.first else { return nil }
        return ProfileCompositionSelection(
            identityModelID: first.id,
            runtimeModelID: first.id,
            tuningModelID: first.id,
            notesModelID: first.id
        )
    }
}

nonisolated enum ProfileLibrary {
    static func reconciledState(
        models: [ModelConfig],
        metadataByModelID: [String: ProfileLibraryMetadata],
        recentModelIDs: [String],
        comparisonModelIDs: Set<String>
    ) -> ProfileLibraryReconciledState {
        let validIDs = Set(models.map(\.id))
        return ProfileLibraryReconciledState(
            metadataByModelID: metadataByModelID.filter { validIDs.contains($0.key) },
            recentModelIDs: recentModelIDs.filter { validIDs.contains($0) },
            comparisonModelIDs: comparisonModelIDs.intersection(validIDs)
        )
    }

    static func items(
        from models: [ModelConfig],
        metadataByModelID: [String: ProfileLibraryMetadata] = [:],
        searchText: String,
        backend: InferenceBackend?,
        category: ProfileUsageCategory? = nil,
        favoritesOnly: Bool = false,
        recentModelIDs: [String] = [],
        recentOnly: Bool = false,
        tag: String? = nil,
        thinkingOnly: Bool,
        sortOrder: ProfileLibrarySortOrder
    ) -> [ProfileLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = models.map { model in
            ProfileLibraryItem(model: model, metadata: metadataByModelID[model.id] ?? ProfileLibraryMetadata())
        }.filter { item in
            if let backend, item.model.resolvedBackend != backend { return false }
            if let category, item.metadata.category != category { return false }
            if favoritesOnly && !item.metadata.isFavorite { return false }
            if recentOnly && !recentModelIDs.contains(item.model.id) { return false }
            if let tag, !item.metadata.tags.contains(where: { $0.localizedCaseInsensitiveCompare(tag) == .orderedSame }) { return false }
            if thinkingOnly && !item.model.enableThinking { return false }
            return query.isEmpty || item.searchText.localizedCaseInsensitiveContains(query)
        }

        return filtered.sorted { lhs, rhs in
            if recentOnly {
                let leftIndex = recentModelIDs.firstIndex(of: lhs.model.id) ?? .max
                let rightIndex = recentModelIDs.firstIndex(of: rhs.model.id) ?? .max
                if leftIndex != rightIndex { return leftIndex < rightIndex }
            }
            switch sortOrder {
            case .favorites:
                if lhs.metadata.isFavorite != rhs.metadata.isFavorite {
                    return lhs.metadata.isFavorite && !rhs.metadata.isFavorite
                }
            case .backend:
                let leftBackend = lhs.model.resolvedBackend.rawValue
                let rightBackend = rhs.model.resolvedBackend.rawValue
                if leftBackend != rightBackend {
                    return leftBackend.localizedCaseInsensitiveCompare(rightBackend) == .orderedAscending
                }
            case .port:
                if lhs.model.serverPort != rhs.model.serverPort {
                    return lhs.model.serverPort < rhs.model.serverPort
                }
            case .name:
                break
            }
            return lhs.model.displayName.localizedCaseInsensitiveCompare(rhs.model.displayName) == .orderedAscending
        }
    }

    static func availableTags(in metadataByModelID: [String: ProfileLibraryMetadata]) -> [String] {
        Array(Set(metadataByModelID.values.flatMap(\.tags)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func comparisonRows(for models: [ModelConfig]) -> [ProfileComparisonRow] {
        guard models.count >= 2 else { return [] }
        let rows: [(String, (ModelConfig) -> String)] = [
            ("Model ID", { $0.modelID }),
            ("Backend", { $0.resolvedBackend.rawValue }),
            ("Host", { $0.host }),
            ("Port", { String($0.serverPort) }),
            ("Family", { $0.family }),
            ("Quantization", { $0.quantization }),
            ("Thinking", { $0.enableThinking ? "Enabled" : "Disabled" }),
            ("Local name", { $0.localName }),
            ("Notes", { $0.notes }),
            ("Extra arguments", { $0.advancedLaunchOptions?.rawExtraArgs ?? "" }),
            ("Temperature", { $0.advancedLaunchOptions?.defaultTemperature ?? "" }),
            ("Top P", { $0.advancedLaunchOptions?.defaultTopP ?? "" }),
            ("Max tokens", { $0.advancedLaunchOptions?.defaultMaxTokens ?? "" })
        ]
        return rows.map { key, value in
            ProfileComparisonRow(key: key, values: models.map(value))
        }
    }

    static func composedDraft(
        models: [ModelConfig],
        selection: ProfileCompositionSelection,
        suggestedPort: Int
    ) -> ModelProfileDraft? {
        guard let identity = models.first(where: { $0.id == selection.identityModelID }),
              let runtime = models.first(where: { $0.id == selection.runtimeModelID }),
              let tuning = models.first(where: { $0.id == selection.tuningModelID }),
              let notes = models.first(where: { $0.id == selection.notesModelID }) else {
            return nil
        }

        var draft = ModelProfileDraft(model: identity)
        draft.originalModelID = ""
        draft.displayName = identity.displayName + " Composite"
        draft.modelID = identity.modelID + "-composite"
        draft.host = runtime.host
        draft.serverPortText = String(suggestedPort)
        draft.backend = runtime.resolvedBackend
        draft.enableThinking = runtime.enableThinking
        draft.advancedLaunchOptions = tuning.advancedLaunchOptions ?? .empty
        draft.notes = notes.notes
        return draft
    }

    static func duplicateDraft(from model: ModelConfig, suggestedPort: Int) -> ModelProfileDraft {
        var draft = ModelProfileDraft(model: model)
        draft.originalModelID = ""
        draft.displayName = model.displayName + " Copy"
        draft.modelID = model.modelID + "-copy"
        draft.serverPortText = String(suggestedPort)
        return draft
    }
}
