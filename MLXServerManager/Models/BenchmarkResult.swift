import Foundation

enum BenchmarkPhase: String, Equatable {
    case success = "Success"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

struct BenchmarkResult: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let profileID: String
    let modelID: String
    let baseURL: String
    let phase: BenchmarkPhase
    let readinessLatencyMS: Double?
    let httpStatusCode: Int?
    let selectedProfileName: String
    let runningProfileID: String?
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        profileID: String,
        modelID: String,
        baseURL: String,
        phase: BenchmarkPhase,
        readinessLatencyMS: Double?,
        statusCode: Int? = nil,
        selectedProfileName: String = "Unknown",
        runningProfileID: String? = nil,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.profileID = profileID
        self.modelID = modelID
        self.baseURL = baseURL
        self.phase = phase
        self.readinessLatencyMS = readinessLatencyMS
        self.httpStatusCode = statusCode
        self.selectedProfileName = selectedProfileName
        self.runningProfileID = runningProfileID
        self.message = message
    }

    var latencyText: String {
        guard let readinessLatencyMS else {
            return "-"
        }
        return "\(Int(readinessLatencyMS)) ms"
    }

    var httpStatusText: String {
        httpStatusCode.map(String.init) ?? "-"
    }

    var runningProfileText: String {
        runningProfileID ?? "Not running"
    }

    var summary: String {
        "\(phase.rawValue): \(latencyText) — \(selectedProfileName) @ \(baseURL) — \(message)"
    }
}
