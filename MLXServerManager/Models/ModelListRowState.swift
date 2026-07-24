import Foundation

nonisolated struct ModelListRowState: Identifiable, Equatable {
    let model: ModelConfig
    let sizeText: String
    let memoryText: String
    let normalStatusText: String
    let hoveredStatusText: String
    let isTransitioning: Bool
    let isLoaded: Bool
    let isDegraded: Bool
    let isPortBusy: Bool
    let canUseStatusAction: Bool
    let isRecentlyAdded: Bool
    let nameSortValue: String
    let sizeSortValue: Double
    let statusSortValue: Int
    let endpointSortValue: String
    let memorySortValue: Double
    let autoUnloadSortValue: Int
    let reasoningSortValue: Int

    var id: ModelConfig.ID {
        model.id
    }
}
