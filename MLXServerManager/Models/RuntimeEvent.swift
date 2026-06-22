import Foundation

struct RuntimeEvent: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let category: String
    let message: String

    init(id: UUID = UUID(), timestamp: Date = Date(), category: String, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }

    var summary: String {
        "\(category): \(message)"
    }
}
