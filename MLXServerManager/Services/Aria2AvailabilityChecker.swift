import Foundation

struct Aria2Availability: Equatable {
    let executablePath: String?
    let searchedPaths: [String]

    var isAvailable: Bool { executablePath != nil }
    var displayPath: String { executablePath.map { ModelAvailabilityPathFormatter.compact(path: $0) } ?? "Not found" }
}

struct Aria2AvailabilityChecker {
    static func check(environment: [String: String] = ProcessInfo.processInfo.environment, fileManager: FileManager = .default) -> Aria2Availability {
        let candidates = candidateExecutablePaths(environment: environment)
        let executable = candidates.first { fileManager.isExecutableFile(atPath: $0) }
        return Aria2Availability(executablePath: executable, searchedPaths: candidates)
    }

    static func candidateExecutablePaths(environment: [String: String] = ProcessInfo.processInfo.environment) -> [String] {
        var candidates: [String] = ["/opt/homebrew/bin/aria2c", "/usr/local/bin/aria2c", "/usr/bin/aria2c"]
        let pathEntries = environment["PATH", default: ""].split(separator: ":").map(String.init)
        for directory in pathEntries {
            candidates.append(URL(fileURLWithPath: directory).appendingPathComponent("aria2c").path)
        }
        var unique: [String] = []
        for candidate in candidates {
            let path = URL(fileURLWithPath: candidate).standardizedFileURL.path
            if !unique.contains(path) { unique.append(path) }
        }
        return unique
    }
}
