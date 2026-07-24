import Foundation
import XCTest

final class LocalizationDirectStringTests: XCTestCase {
    func testNoNewDirectViewStringsWithoutAllowlist() throws {
        let root = try Self.projectRoot()
        let files = try Self.swiftFiles(in: root.appendingPathComponent("MLXServerManager/Views"))
            + [root.appendingPathComponent("MLXServerManager/ContentView.swift")]
        let findings = try files.flatMap { try Self.scan($0, root: root) }
        let unexpected = findings.filter { !Self.allowedKeys.contains($0.key) }
        XCTAssertTrue(unexpected.isEmpty, unexpected.map { $0.description }.joined(separator: "\n"))
    }

    private static let allowedKeys: Set<String> = [
        "IntegratedWorkspaceView.swift|Text|SYSTEM",
        "IntegratedWorkspaceView.swift|Text|MLX Server Manager",
        "IntegratedWorkspaceView.swift|Text|127.0.0.1",
        "IntegratedWorkspaceView.swift|Toggle|",
        "IntegratedWorkspaceView.swift|Text|Direct Mode",
        "IntegratedWorkspaceView.swift|Text|-",
        "ModelProfileEditorView.swift|TextField|127.0.0.1",
        "ModelProfileEditorView.swift|TextField|8080",
        "ModelProfileEditorView.swift|TextField|0.0 - 1.0",
        "DownloadsSurfaceView.swift|TextField|50K",
        "DownloadsSurfaceView.swift|TextField|mlx-community/Qwen...",
        "DownloadsSurfaceView.swift|Button|Safetensors",
        "ImportProfilesPreviewView.swift|Text|#\\(profile.sourceIndex) \\(profile.name)",
        "TitlebarPanelControlsInstaller.swift|Text|MLX Server Manager",
        "SettingsPanelView.swift|TextField|127.0.0.1",
        "SettingsPanelView.swift|TextField|8080",
        "SettingsPanelView.swift|TextField|not-required-local"
    ]

    private struct Finding {
        let file: String
        let line: Int
        let call: String
        let literal: String
        var key: String { "\(file)|\(call)|\(literal)" }
        var description: String { "\(file):\(line): \(call)(\"\(literal)\")" }
    }

    private static func projectRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while dir.path != "/" {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("MLXServerManager.xcodeproj").path) { return dir }
            dir.deleteLastPathComponent()
        }
        throw NSError(domain: "LocalizationDirectStringTests", code: 1)
    }

    private static func swiftFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return [] }
        return enumerator.compactMap { ($0 as? URL).flatMap { $0.pathExtension == "swift" ? $0 : nil } }
    }

    private static func scan(_ url: URL, root: URL) throws -> [Finding] {
        let text = try String(contentsOf: url, encoding: .utf8)
        let file = url.lastPathComponent
        let pattern = #"\b(Text|Button|Label|Picker|TextField|Toggle|ContentUnavailableView|accessibilityLabel)\("((?:[^"\\]|\\.)*)""#
        let regex = try NSRegularExpression(pattern: pattern)
        var results: [Finding] = []
        for (lineNumber, line) in text.components(separatedBy: .newlines).enumerated() {
            if ["l10n.text", "strings.text", "localizedText", "t("].contains(where: line.contains) { continue }
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            for match in regex.matches(in: line, range: nsRange) {
                guard let callRange = Range(match.range(at: 1), in: line), let literalRange = Range(match.range(at: 2), in: line) else { continue }
                results.append(Finding(file: file, line: lineNumber + 1, call: String(line[callRange]), literal: String(line[literalRange])))
            }
        }
        return results
    }
}
