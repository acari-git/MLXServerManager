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

        XCTAssertTrue(duplicatePairs.isEmpty, "AppTextKey entries should not reuse identical English and Japanese text unless explicitly allowed: \(duplicatePairs)")
    }

    func testInlineLocalizationPairsUseBothEnglishAndJapaneseArguments() throws {
        let root = try Self.projectRoot()
        let files = try Self.swiftFiles(in: root.appendingPathComponent("MLXServerManager"))
        let findings = try files.flatMap { try Self.scanInlinePairs($0, root: root) }
        let invalid = findings.filter { !$0.isValid }

        XCTAssertTrue(
            invalid.isEmpty,
            "Inline localization calls must include non-empty English and Japanese values.\n"
                + invalid.map { $0.description }.joined(separator: "\n")
        )
    }

    private struct InlineFinding {
        let file: String
        let line: Int
        let english: String
        let japanese: String

        var isValid: Bool {
            !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !japanese.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var description: String {
            "\(file):\(line): english=\"\(english)\" japanese=\"\(japanese)\""
        }
    }

    private static func projectRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("MLXServerManager.xcodeproj").path) { return dir }
            dir.deleteLastPathComponent()
        }
        throw NSError(domain: "LocalizationPairTests", code: 1)
    }

    private static func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { ($0 as? URL).flatMap { $0.pathExtension == "swift" ? $0 : nil } }
    }

    private static func scanInlinePairs(_ url: URL, root: URL) throws -> [InlineFinding] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let file = url.path.replacingOccurrences(of: root.path + "/", with: "")
        let pattern = #"(?:localizedText|text)\(language:\s*[^,]+,\s*english:\s*\"((?:[^\"\\]|\\.)*)\",\s*japanese:\s*\"((?:[^\"\\]|\\.)*)\""#
        let regex = try NSRegularExpression(pattern: pattern)
        var findings: [InlineFinding] = []

        for (index, line) in text.components(separatedBy: .newlines).enumerated() {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            for match in regex.matches(in: line, range: nsRange) {
                guard let englishRange = Range(match.range(at: 1), in: line),
                      let japaneseRange = Range(match.range(at: 2), in: line) else { continue }
                findings.append(InlineFinding(
                    file: file,
                    line: index + 1,
                    english: String(line[englishRange]),
                    japanese: String(line[japaneseRange])
                ))
            }
        }
        return findings
    }
}
