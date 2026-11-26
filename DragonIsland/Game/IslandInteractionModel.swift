import Combine
import Foundation

/// Bridges SpriteKit tile taps to the save store and publishes what the SwiftUI
/// build panel should show.  Kept out of `IslandScene` so the scene stays small.
final class IslandInteractionModel: ObservableObject {
    let store: GameStateStore

    @Published private(set) var selectedTile: TileCoordinate
    @Published private(set) var movingPlacementID: UUID?
    @Published private(set) var statusMessage: String?

    var onWorldChanged: (() -> Void)?

    init(store: GameStateStore) {
        self.store = store
        self.selectedTile = GameConfig.initialSelection
    }

    var selectedPlacement: PlacedBuilding? {
        IslandEconomy.placement(at: selectedTile, state: store.state)
    }

    var isMoving: Bool { movingPlacementID != nil }

    func syncSelection(_ tile: TileCoordinate) {
        selectedTile = tile
    }

    /// Called for every tile tap.  A pending move consumes the tap first, then
    /// tapping a ready habitat or farm collects its yield.
    func updateSelection(_ tile: TileCoordinate) {
        selectedTile = tile
        statusMessage = nil
        if let movingPlacementID {
            finishMove(id: movingPlacementID, to: tile)
            return
        }
        collectIfReady(at: tile)
    }

    // MARK: - Actions

    func collectSelected() {
        collectIfReady(at: selectedTile)
    }

    func plantSelectedFarm() {
        guard let placed = selectedPlacement, placed.kind == .farm else { return }
        if store.plantFarm(id: placed.id) {
            statusMessage = "Planted. Come back when the crops are ready."
            onWorldChanged?()
        } else {
            statusMessage = placed.plantedAt == nil ? "Not enough gold to plant." : "Crops are already growing."
        }
    }

    func startMoving() {
        guard let placed = selectedPlacement else { return }
        movingPlacementID = placed.id
        statusMessage = "Tap an empty plot to move \(displayName(for: placed))."
    }

    func cancelMove() {
        movingPlacementID = nil
        statusMessage = nil
    }

    @discardableResult
    func build(kind: PlacementKind, definitionID: String) -> Bool {
        switch store.buildPlacement(kind: kind, definitionID: definitionID, tile: selectedTile) {
        case .success(let placed):
            statusMessage = "Built \(displayName(for: placed))."
            onWorldChanged?()
            return true
        case .failure(let failure):
            statusMessage = failure.message
            return false
        }
    }

    func canBuild(kind: PlacementKind, definitionID: String) -> Bool {
        guard selectedPlacement == nil,
              IslandEconomy.isUnlocked(kind: kind, definitionID: definitionID,
                                      catalog: store.catalog,
                                      islandLevel: store.state.islandLevel),
              let cost = IslandEconomy.cost(kind: kind, definitionID: definitionID, catalog: store.catalog)
        else { return false }
        return store.state.resources.gold >= cost
    }

    func canHatch(_ placed: PlacedBuilding) -> Bool {
        placed.kind == .building && store.hasReadyEgg(in: placed.id)
    }

    func hatchSelected() {
        guard let placed = selectedPlacement, placed.kind == .building else { return }
        hatch(in: placed)
    }

    func canPlant(_ placed: PlacedBuilding) -> Bool {
        guard placed.kind == .farm, placed.plantedAt == nil,
              let definition = store.catalog.building(placed.definitionID),
              definition.isFarm else { return false }
        return store.state.resources.gold >= (definition.plantCost ?? 0)
    }

    func displayName(for placed: PlacedBuilding) -> String {
        switch placed.kind {
        case .habitat:
            return store.catalog.habitat(placed.definitionID)?.displayName ?? placed.definitionID
        case .building, .farm:
            return store.catalog.building(placed.definitionID)?.displayName ?? placed.definitionID
        }
    }

    // MARK: - Private

    private func collectIfReady(at tile: TileCoordinate) {
        guard let placed = IslandEconomy.placement(at: tile, state: store.state) else { return }
        switch placed.kind {
        case .habitat:
            let gold = store.collectHabitat(id: placed.id)
            guard gold > 0 else { return }
            statusMessage = "Collected \(gold) gold."
        case .farm:
            let food = store.harvestFarm(id: placed.id)
            guard food > 0 else { return }
            statusMessage = "Harvested \(food) food."
        case .building:
            hatch(in: placed)
            return
        }
        onWorldChanged?()
    }

    private func hatch(in placed: PlacedBuilding) {
        switch store.hatchFirstReadyEgg(in: placed.id) {
        case .success(let dragon):
            statusMessage = "\(dragon.nickname) hatched."
            onWorldChanged?()
        case .failure(.noEgg):
            return
        case .failure(let failure):
            statusMessage = failure.message
        }
    }

    private func finishMove(id: UUID, to tile: TileCoordinate) {
        switch store.movePlacement(id: id, to: tile) {
        case .success(let placed):
            movingPlacementID = nil
            statusMessage = "Moved \(displayName(for: placed))."
            onWorldChanged?()
        case .failure(let failure):
            statusMessage = failure.message
        }
    }
}
