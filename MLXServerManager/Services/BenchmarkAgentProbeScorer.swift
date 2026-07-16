import Foundation

nonisolated enum BenchmarkAgentProbeKind: CaseIterable, Equatable, Sendable {
    case jsonSchema
    case toolSelectionRead
    case toolSelectionEdit
    case toolSelectionNone
    case constraint

    nonisolated var expectedJSON: String {
        switch self {
        case .jsonSchema:
            #"{"status":"ready","language":"ja","steps":["check","reply"]}"#
        case .toolSelectionRead:
            #"{"tool":"read_file","needs_tool":true,"reason":"inspect"}"#
        case .toolSelectionEdit:
            #"{"tool":"edit_file","needs_tool":true,"reason":"modify"}"#
        case .toolSelectionNone:
            #"{"tool":"none","needs_tool":false,"reason":"answer"}"#
        case .constraint:
            #"{"answer":"blue","count":3}"#
        }
    }

    nonisolated var prompt: String {
        """
        Output only this exact JSON:
        \(expectedJSON)
        """
    }

    nonisolated var noThinkingRetryPrompt: String {
        """
        /no_think
        Copy exactly this JSON as the final answer. Do not explain.
        \(expectedJSON)
        """
    }

    nonisolated var expectedTool: String? {
        switch self {
        case .jsonSchema, .constraint:
            nil
        case .toolSelectionRead:
            "read_file"
        case .toolSelectionEdit:
            "edit_file"
        case .toolSelectionNone:
            "none"
        }
    }
}

nonisolated struct BenchmarkAgentProbeScore: Equatable {
    let jsonValid: Bool
    let instructionFollowed: Bool
    let toolSelectionPassed: Bool
}

nonisolated struct BenchmarkAgentProbeScorer {
    nonisolated static func score(output: String, kind: BenchmarkAgentProbeKind) -> BenchmarkAgentProbeScore {
        guard let object = BenchmarkJSONExtractor.object(from: output) else {
            return BenchmarkAgentProbeScore(jsonValid: false, instructionFollowed: false, toolSelectionPassed: false)
        }

        switch kind {
        case .jsonSchema:
            let status = object["status"] as? String
            let language = object["language"] as? String
            let steps = object["steps"] as? [Any]
            let followed = status == "ready" && language == "ja" && steps?.count == 2
            return BenchmarkAgentProbeScore(jsonValid: true, instructionFollowed: followed, toolSelectionPassed: false)
        case .constraint:
            let answer = object["answer"] as? String
            let count = object["count"] as? Int
            let followed = answer == "blue" && count == 3
            return BenchmarkAgentProbeScore(jsonValid: true, instructionFollowed: followed, toolSelectionPassed: false)
        case .toolSelectionRead, .toolSelectionEdit, .toolSelectionNone:
            let tool = object["tool"] as? String
            let needsTool = object["needs_tool"] as? Bool
            let expectedTool = kind.expectedTool
            let toolPassed = tool == expectedTool
            let expectedNeedsTool = expectedTool != "none"
            let followed = toolPassed && needsTool == expectedNeedsTool
            return BenchmarkAgentProbeScore(jsonValid: true, instructionFollowed: followed, toolSelectionPassed: toolPassed)
        }
    }
}

nonisolated struct BenchmarkJSONExtractor {
    nonisolated static func object(from text: String) -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for candidate in jsonCandidates(from: trimmed) {
            guard let data = candidate.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  let dictionary = object as? [String: Any] else {
                continue
            }
            return dictionary
        }
        return nil
    }

    nonisolated private static func jsonCandidates(from text: String) -> [String] {
        var candidates = [text]
        candidates.append(contentsOf: fencedJSONCandidates(from: text))
        candidates.append(contentsOf: balancedObjectCandidates(from: text))
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else {
                return nil
            }
            seen.insert(trimmed)
            return trimmed
        }
    }

    nonisolated private static func fencedJSONCandidates(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var candidates: [String] = []
        var isInsideFence = false
        var currentLines: [String] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("```") {
                if isInsideFence {
                    candidates.append(currentLines.joined(separator: "\n"))
                    currentLines.removeAll()
                    isInsideFence = false
                } else {
                    isInsideFence = true
                    currentLines.removeAll()
                }
                continue
            }

            if isInsideFence {
                currentLines.append(line)
            }
        }

        return candidates
    }

    nonisolated private static func balancedObjectCandidates(from text: String) -> [String] {
        let characters = Array(text)
        var candidates: [String] = []

        for startIndex in characters.indices where characters[startIndex] == "{" {
            var depth = 0
            var isInsideString = false
            var isEscaped = false

            for index in startIndex..<characters.count {
                let character = characters[index]

                if isInsideString {
                    if isEscaped {
                        isEscaped = false
                    } else if character == "\\" {
                        isEscaped = true
                    } else if character == "\"" {
                        isInsideString = false
                    }
                    continue
                }

                if character == "\"" {
                    isInsideString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        candidates.append(String(characters[startIndex...index]))
                        break
                    }
                }
            }
        }

        return candidates
    }
}
