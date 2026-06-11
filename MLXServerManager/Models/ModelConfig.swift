import Foundation

struct ModelConfig: Identifiable, Hashable {
    let id: String
    let displayName: String
    let family: String
    let quantization: String
    let contextWindow: String
    let localName: String
    let status: ModelStatus
    let notes: String
}

