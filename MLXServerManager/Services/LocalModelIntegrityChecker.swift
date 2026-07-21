import Foundation

nonisolated enum LocalModelIntegrityIssue: Equatable, Sendable {
    case missingConfiguration
    case invalidConfiguration
    case missingTokenizer
    case missingWeights
    case invalidWeightIndex
    case invalidWeightShardSet
    case unsafeWeightReference(String)
    case missingWeightFiles([String])
    case emptyWeightFiles([String])

    func message(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .missingConfiguration:
            return strings.text(
                english: "config.json is missing.",
                japanese: "config.json がありません。"
            )
        case .invalidConfiguration:
            return strings.text(
                english: "config.json is not a valid JSON object.",
                japanese: "config.json が有効なJSONオブジェクトではありません。"
            )
        case .missingTokenizer:
            return strings.text(
                english: "No tokenizer data file such as tokenizer.json or tokenizer.model was found.",
                japanese: "tokenizer.json や tokenizer.model などのトークナイザーデータファイルがありません。"
            )
        case .missingWeights:
            return strings.text(
                english: "No model*.safetensors weight file was found.",
                japanese: "model*.safetensors の重みファイルがありません。"
            )
        case .invalidWeightIndex:
            return strings.text(
                english: "model.safetensors.index.json has an invalid weight_map.",
                japanese: "model.safetensors.index.json の weight_map が不正です。"
            )
        case .invalidWeightShardSet:
            return strings.text(
                english: "The model weight shards have inconsistent numbering.",
                japanese: "モデルの分割重みファイルの連番が不整合です。"
            )
        case let .unsafeWeightReference(reference):
            return strings.text(
                english: "The weight index contains an unsafe path: \(reference)",
                japanese: "重みインデックスに安全でないパスがあります: \(reference)"
            )
        case let .missingWeightFiles(files):
            let names = files.joined(separator: ", ")
            return strings.text(
                english: "Weight files referenced by the index are missing: \(names)",
                japanese: "重みインデックスが参照するファイルがありません: \(names)"
            )
        case let .emptyWeightFiles(files):
            let names = files.joined(separator: ", ")
            return strings.text(
                english: "Weight files are empty: \(names)",
                japanese: "空の重みファイルがあります: \(names)"
            )
        }
    }
}

nonisolated enum LocalModelIntegrityCheckResult: Equatable, Sendable {
    case ready
    case incomplete(LocalModelIntegrityIssue)
    case notInspectable(String)
}

nonisolated protocol LocalModelIntegrityChecking: Sendable {
    func check(path: String) -> LocalModelIntegrityCheckResult
}

nonisolated struct FileSystemLocalModelIntegrityChecker: LocalModelIntegrityChecking {
    private static let maximumReportedFiles = 3

    func check(path: String) -> LocalModelIntegrityCheckResult {
        let fileManager = FileManager.default
        let rootURL = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL

        let configURL = rootURL.appendingPathComponent("config.json", isDirectory: false)
        guard isRegularFile(configURL) else {
            return .incomplete(.missingConfiguration)
        }

        let configData: Data
        do {
            configData = try Data(contentsOf: configURL, options: [.mappedIfSafe])
        } catch {
            return .notInspectable(error.localizedDescription)
        }
        do {
            guard let config = try JSONSerialization.jsonObject(with: configData) as? [String: Any],
                  Self.hasModelTypeOrCustomModelFile(config) else {
                return .incomplete(.invalidConfiguration)
            }
        } catch {
            return .incomplete(.invalidConfiguration)
        }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return .notInspectable(error.localizedDescription)
        }

        guard contents.contains(where: isTokenizerDataFile) else {
            return .incomplete(.missingTokenizer)
        }

        let weightFiles = contents.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("model")
                && name.hasSuffix(".safetensors")
                && isRegularFile(url)
        }
        guard !weightFiles.isEmpty else {
            return .incomplete(.missingWeights)
        }

        var emptyWeights: [String] = []
        for weightURL in weightFiles {
            guard let size = fileSize(weightURL) else {
                return .notInspectable("Could not read the size of \(weightURL.lastPathComponent).")
            }
            if size == 0 {
                emptyWeights.append(weightURL.lastPathComponent)
            }
        }
        if !emptyWeights.isEmpty {
            return .incomplete(.emptyWeightFiles(Self.reported(emptyWeights)))
        }

        let indexURL = rootURL.appendingPathComponent("model.safetensors.index.json", isDirectory: false)
        guard fileManager.fileExists(atPath: indexURL.path) else {
            return validateIndexlessWeightFiles(weightFiles)
        }
        guard isRegularFile(indexURL) else {
            return .incomplete(.invalidWeightIndex)
        }

        let references: [String]
        let indexData: Data
        do {
            indexData = try Data(contentsOf: indexURL, options: [.mappedIfSafe])
        } catch {
            return .notInspectable(error.localizedDescription)
        }
        do {
            guard let object = try JSONSerialization.jsonObject(with: indexData) as? [String: Any],
                  let weightMap = object["weight_map"] as? [String: Any],
                  !weightMap.isEmpty,
                  weightMap.values.allSatisfy({ $0 is String }) else {
                return .incomplete(.invalidWeightIndex)
            }
            references = Array(Set(weightMap.values.compactMap { $0 as? String })).sorted()
            guard !references.isEmpty else {
                return .incomplete(.invalidWeightIndex)
            }
        } catch {
            return .incomplete(.invalidWeightIndex)
        }

        var missingFiles: [String] = []
        var emptyFiles: [String] = []
        for reference in references {
            guard let fileURL = safeFileURL(for: reference, under: rootURL) else {
                return .incomplete(.unsafeWeightReference(reference))
            }
            guard isRegularFile(fileURL) else {
                missingFiles.append(reference)
                continue
            }
            guard let size = fileSize(fileURL) else {
                return .notInspectable("Could not read the size of \(reference).")
            }
            if size == 0 {
                emptyFiles.append(reference)
            }
        }

        if !missingFiles.isEmpty {
            return .incomplete(.missingWeightFiles(Self.reported(missingFiles)))
        }
        if !emptyFiles.isEmpty {
            return .incomplete(.emptyWeightFiles(Self.reported(emptyFiles)))
        }
        return .ready
    }

    private func validateIndexlessWeightFiles(_ weightFiles: [URL]) -> LocalModelIntegrityCheckResult {
        if weightFiles.contains(where: { $0.lastPathComponent == "model.safetensors" }) {
            return .ready
        }

        let shards = weightFiles.compactMap { Self.shardDescriptor(for: $0.lastPathComponent) }
        guard !shards.isEmpty else {
            return .ready
        }

        let totals = Set(shards.map(\.total))
        let indexWidths = Set(shards.map(\.indexWidth))
        let totalWidths = Set(shards.map(\.totalWidth))
        guard totals.count == 1,
              indexWidths.count == 1,
              totalWidths.count == 1,
              let total = totals.first,
              let indexWidth = indexWidths.first,
              let totalWidth = totalWidths.first,
              total > 0,
              shards.allSatisfy({ (1...total).contains($0.index) }) else {
            return .incomplete(.invalidWeightShardSet)
        }

        let indices = Set(shards.map(\.index))
        guard indices.count == shards.count else {
            return .incomplete(.invalidWeightShardSet)
        }

        let missingFiles = (1...total).compactMap { index -> String? in
            guard !indices.contains(index) else {
                return nil
            }
            return String(
                format: "model-%0*d-of-%0*d.safetensors",
                indexWidth,
                index,
                totalWidth,
                total
            )
        }
        guard missingFiles.isEmpty else {
            return .incomplete(.missingWeightFiles(Self.reported(missingFiles)))
        }
        return .ready
    }

    private func isTokenizerDataFile(_ url: URL) -> Bool {
        guard isRegularFile(url) else {
            return false
        }

        let name = url.lastPathComponent.lowercased()
        if name == "tokenizer.json"
            || name == "tokenizer.model"
            || name.hasPrefix("tokenizer.model.")
            || name == "tokenizer.vocab"
            || (name.hasPrefix("tokenization_") && name.hasSuffix(".py")) {
            return true
        }

        return [
            "spiece.model",
            "sentencepiece.bpe.model",
            "tiktoken.model",
            "tekken.json",
            "vocab.json",
            "vocab.txt",
            "vocab.model",
            "merges.txt"
        ].contains(name)
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func fileSize(_ url: URL) -> Int64? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        return Int64(size)
    }

    private func safeFileURL(for reference: String, under rootURL: URL) -> URL? {
        guard !reference.isEmpty, !reference.hasPrefix("/") else {
            return nil
        }
        let components = reference.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else {
            return nil
        }

        let fileURL = rootURL.appendingPathComponent(reference, isDirectory: false).standardizedFileURL
        let rootPrefix = rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path + "/"
        guard fileURL.path.hasPrefix(rootPrefix) else {
            return nil
        }
        return fileURL
    }

    private static func reported(_ files: [String]) -> [String] {
        Array(files.sorted().prefix(maximumReportedFiles))
    }

    private static func shardDescriptor(for fileName: String) -> WeightShardDescriptor? {
        let prefix = "model-"
        let suffix = ".safetensors"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else {
            return nil
        }

        let start = fileName.index(fileName.startIndex, offsetBy: prefix.count)
        let end = fileName.index(fileName.endIndex, offsetBy: -suffix.count)
        let components = fileName[start..<end].components(separatedBy: "-of-")
        guard components.count == 2,
              let indexText = components.first,
              let totalText = components.last,
              !indexText.isEmpty,
              !totalText.isEmpty,
              indexText.allSatisfy(\.isNumber),
              totalText.allSatisfy(\.isNumber),
              let index = Int(indexText),
              let total = Int(totalText) else {
            return nil
        }
        return WeightShardDescriptor(
            index: index,
            total: total,
            indexWidth: indexText.count,
            totalWidth: totalText.count
        )
    }

    private static func hasModelTypeOrCustomModelFile(_ config: [String: Any]) -> Bool {
        ["model_type", "model_file"].contains { key in
            guard let value = config[key] as? String else {
                return false
            }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

private nonisolated struct WeightShardDescriptor {
    let index: Int
    let total: Int
    let indexWidth: Int
    let totalWidth: Int
}
