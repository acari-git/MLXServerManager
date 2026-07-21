import XCTest
@testable import MLXServerManager

final class LocalModelIntegrityCheckerTests: XCTestCase {
    func testValidUnshardedModelIsReady() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))

        XCTAssertEqual(checker.check(path: directory.path), .ready)
    }

    func testMissingConfigurationIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))

        XCTAssertEqual(checker.check(path: directory.path), .incomplete(.missingConfiguration))
    }

    func testInvalidConfigurationIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("[]".utf8).write(to: directory.appendingPathComponent("config.json"))
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))

        XCTAssertEqual(checker.check(path: directory.path), .incomplete(.invalidConfiguration))
    }

    func testMissingTokenizerIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"model_type":"test"}"#.utf8)
            .write(to: directory.appendingPathComponent("config.json"))
        try Data(#"{"tokenizer_class":"TestTokenizer"}"#.utf8)
            .write(to: directory.appendingPathComponent("tokenizer_config.json"))
        try Data(#"{"eos_token":"</s>"}"#.utf8)
            .write(to: directory.appendingPathComponent("special_tokens_map.json"))
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))

        XCTAssertEqual(checker.check(path: directory.path), .incomplete(.missingTokenizer))
    }

    func testTokenizerModelIsAcceptedAsTokenizerData() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data(#"{"model_type":"test"}"#.utf8)
            .write(to: directory.appendingPathComponent("config.json"))
        try Data([1]).write(to: directory.appendingPathComponent("tokenizer.model"))
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))

        XCTAssertEqual(checker.check(path: directory.path), .ready)
    }

    func testMissingWeightsIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)

        XCTAssertEqual(checker.check(path: directory.path), .incomplete(.missingWeights))
    }

    func testEmptyWeightFileIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data().write(to: directory.appendingPathComponent("model.safetensors"))

        XCTAssertEqual(
            checker.check(path: directory.path),
            .incomplete(.emptyWeightFiles(["model.safetensors"]))
        )
    }

    func testMissingIndexedShardIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model-00001-of-00002.safetensors"))
        let index = #"{"weight_map":{"a":"model-00001-of-00002.safetensors","b":"model-00002-of-00002.safetensors"}}"#
        try Data(index.utf8).write(to: directory.appendingPathComponent("model.safetensors.index.json"))

        XCTAssertEqual(
            checker.check(path: directory.path),
            .incomplete(.missingWeightFiles(["model-00002-of-00002.safetensors"]))
        )
    }

    func testCompleteIndexlessShardSetIsReady() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model-00001-of-00002.safetensors"))
        try Data([2]).write(to: directory.appendingPathComponent("model-00002-of-00002.safetensors"))

        XCTAssertEqual(checker.check(path: directory.path), .ready)
    }

    func testMissingIndexlessShardIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model-00001-of-00003.safetensors"))
        try Data([3]).write(to: directory.appendingPathComponent("model-00003-of-00003.safetensors"))

        XCTAssertEqual(
            checker.check(path: directory.path),
            .incomplete(.missingWeightFiles(["model-00002-of-00003.safetensors"]))
        )
    }

    func testIndexlessShardSetWithInconsistentTotalsIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model-00001-of-00002.safetensors"))
        try Data([2]).write(to: directory.appendingPathComponent("model-00002-of-00003.safetensors"))

        XCTAssertEqual(
            checker.check(path: directory.path),
            .incomplete(.invalidWeightShardSet)
        )
    }

    func testIndexlessShardSetWithInconsistentPaddingIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model-1-of-2.safetensors"))
        try Data([1]).write(to: directory.appendingPathComponent("model-01-of-02.safetensors"))

        XCTAssertEqual(
            checker.check(path: directory.path),
            .incomplete(.invalidWeightShardSet)
        )
    }

    func testUnsafeIndexedShardPathIsIncomplete() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))
        let index = #"{"weight_map":{"a":"../model.safetensors"}}"#
        try Data(index.utf8).write(to: directory.appendingPathComponent("model.safetensors.index.json"))

        XCTAssertEqual(
            checker.check(path: directory.path),
            .incomplete(.unsafeWeightReference("../model.safetensors"))
        )
    }

    func testNonStringWeightIndexValueIsInvalid() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeValidConfig(to: directory)
        try Data([1]).write(to: directory.appendingPathComponent("model.safetensors"))
        let index = #"{"weight_map":{"a":42}}"#
        try Data(index.utf8).write(to: directory.appendingPathComponent("model.safetensors.index.json"))

        XCTAssertEqual(checker.check(path: directory.path), .incomplete(.invalidWeightIndex))
    }

    private let checker = FileSystemLocalModelIntegrityChecker()

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeValidConfig(to directory: URL) throws {
        try Data(#"{"model_type":"test"}"#.utf8)
            .write(to: directory.appendingPathComponent("config.json"))
        try Data(#"{"version":"1.0"}"#.utf8)
            .write(to: directory.appendingPathComponent("tokenizer.json"))
    }
}
