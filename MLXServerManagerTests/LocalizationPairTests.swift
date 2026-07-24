import Foundation
import XCTest
@testable import MLXServerManager

final class LocalizationPairTests: XCTestCase {
    func testAppTextKeysHaveNonEmptyEnglishAndJapaneseValues() {
        let emptyPairs = AppTextKey.allCases.filter {
            $0.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || $0.japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        XCTAssertTrue(emptyPairs.isEmpty, "AppTextKey entries must define both English and Japanese text: \(emptyPairs)")
    }

    func testAppTextKeysDoNotAccidentallyReuseTheSameTextAcrossLanguages() {
        let allowedSameText: Set<AppTextKey> = []
        let duplicatePairs = AppTextKey.allCases.filter {
            !allowedSameText.contains($0) && $0.english == $0.japanese
        }

        XCTAssertTrue(
            duplicatePairs.isEmpty,
            "AppTextKey entries should not reuse identical English and Japanese text unless explicitly allowed: \(duplicatePairs)"
        )
    }

    func testInlineLocalizationPairsAreCompleteAndDistinct() throws {
        let root = try Self.projectRoot()
        let files = try Self.swiftFiles(in: root.appendingPathComponent("MLXServerManager"))
        let findings = try files.flatMap { try Self.scanInlinePairs($0, root: root) }
        let invalid = findings.filter { !$0.isValid }

        XCTAssertTrue(
            invalid.isEmpty,
            "Inline localization calls must include non-empty, distinct English and Japanese values.\n"
                + invalid.map(\.description).joined(separator: "\n")
        )
    }

    func testInlineJapaneseValuesContainJapaneseTextUnlessExplicitlyAllowed() throws {
        let root = try Self.projectRoot()
        let files = try Self.swiftFiles(in: root.appendingPathComponent("MLXServerManager"))
        let findings = try files.flatMap { try Self.scanInlinePairs($0, root: root) }
        let suspicious = findings.filter { finding in
            !Self.allowedTechnicalOnlyJapaneseValues.contains(finding.japanese)
                && !finding.japanese.unicodeScalars.contains(where: Self.isJapaneseScalar)
        }

        XCTAssertTrue(
            suspicious.isEmpty,
            "Japanese localization values should contain Japanese text unless the value is an explicitly allowed technical label.\n"
                + suspicious.map(\.description).joined(separator: "\n")
        )
    }

    private struct InlineFinding {
        let file: String
        let line: Int
        let english: String
        let japanese: String

        var isValid: Bool {
            let trimmedEnglish = english.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedJapanese = japanese.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedEnglish.isEmpty
                && !trimmedJapanese.isEmpty
                && (trimmedEnglish != trimmedJapanese
                    || LocalizationPairTests.allowedTechnicalOnlyJapaneseValues.contains(trimmedJapanese))
        }

        var description: String {
            "\(file):\(line): english=\"\(english)\" japanese=\"\(japanese)\""
        }
    }

    private static let allowedTechnicalOnlyJapaneseValues: Set<String> = [
        "Agent Readiness"
    ]

    private static func isJapaneseScalar(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }

    private static func projectRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("MLXServerManager.xcodeproj").path
            ) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "LocalizationPairTests", code: 1)
    }

    private static func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return enumerator.compactMap {
            ($0 as? URL).flatMap { $0.pathExtension == "swift" ? $0 : nil }
        }
    }

    private static func scanInlinePairs(_ url: URL, root: URL) throws -> [InlineFinding] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let file = url.path.replacingOccurrences(of: root.path + "/", with: "")
        let pattern = #"(?:localizedText|text)\(\s*(?:language:\s*[^,]+,\s*)?english:\s*\"((?:[^\"\\]|\\.)*)\"\s*,\s*japanese:\s*\"((?:[^\"\\]|\\.)*)\""#
        let expression = try NSRegularExpression(pattern: pattern)
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)

        return expression.matches(in: text, range: fullRange).compactMap { match in
            guard let englishRange = Range(match.range(at: 1), in: text),
                  let japaneseRange = Range(match.range(at: 2), in: text),
                  let matchRange = Range(match.range, in: text) else {
                return nil
            }
            let line = text[..<matchRange.lowerBound].reduce(into: 1) { count, character in
                if character == "\n" {
                    count += 1
                }
            }
            return InlineFinding(
                file: file,
                line: line,
                english: String(text[englishRange]),
                japanese: String(text[japaneseRange])
            )
        }
    }
}
