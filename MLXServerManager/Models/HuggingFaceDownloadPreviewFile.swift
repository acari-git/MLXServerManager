import Foundation

struct HuggingFaceDownloadPreviewFile: Identifiable, Equatable {
    let path: String
    let size: Int64?

    var id: String { path }

    var fileName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var compactSize: String {
        guard let size else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct HuggingFaceDownloadFilePreviewState: Equatable {
    var isLoading: Bool
    var message: String
    var files: [HuggingFaceDownloadPreviewFile]

    static let waiting = HuggingFaceDownloadFilePreviewState(isLoading: false, message: "Preview files before downloading to choose exactly what to fetch.", files: [])

    var totalSize: Int64? {
        var total: Int64 = 0
        for file in files {
            guard let size = file.size else { return nil }
            total += size
        }
        return total
    }

    var summary: String {
        if files.isEmpty { return message }
        let sizeText = totalSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "unknown size"
        return "\(files.count) files • \(sizeText)"
    }
}
