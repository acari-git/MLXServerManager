import Foundation

nonisolated struct HuggingFaceFilePreviewViewState: Equatable, Sendable {
    private(set) var identity: HuggingFaceFilePreviewIdentity?
    private(set) var preview: HuggingFaceDownloadFilePreviewState
    private(set) var selectedFileIDs: Set<String>

    static let waiting = HuggingFaceFilePreviewViewState(
        identity: nil,
        preview: .waiting,
        selectedFileIDs: []
    )

    mutating func begin(
        identity: HuggingFaceFilePreviewIdentity,
        message: String
    ) {
        self.identity = identity
        preview = HuggingFaceDownloadFilePreviewState(
            isLoading: true,
            message: message,
            files: []
        )
        selectedFileIDs = []
    }

    mutating func complete(
        files: [HuggingFaceDownloadPreviewFile],
        message: String
    ) {
        preview = HuggingFaceDownloadFilePreviewState(
            isLoading: false,
            message: message,
            files: files
        )
        selectedFileIDs = Set(files.map(\.id))
    }

    mutating func fail(message: String) {
        preview = HuggingFaceDownloadFilePreviewState(
            isLoading: false,
            message: message,
            files: []
        )
        selectedFileIDs = []
    }

    mutating func reject(message: String) {
        identity = nil
        fail(message: message)
    }

    mutating func reset() {
        self = .waiting
    }

    mutating func toggle(fileID: String) {
        if selectedFileIDs.contains(fileID) {
            selectedFileIDs.remove(fileID)
        } else {
            selectedFileIDs.insert(fileID)
        }
    }

    mutating func select(fileIDs: Set<String>) {
        selectedFileIDs = fileIDs
    }

    mutating func clearSelection() {
        selectedFileIDs = []
    }
}
