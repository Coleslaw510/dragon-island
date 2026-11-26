import Combine
import Foundation

/// Bridges SpriteKit tile taps to the save store.  Tapping a placed habitat,
/// farm or building selects it for the info panel; tapping empty ground does
/// nothing unless a shop placement or move is waiting for a plot.
final class IslandInteractionModel: ObservableObject {
    let store: GameStateStore

    @Published private(set) var selectedPlacementID: UUID?
    @Published private(set) var movingPlacementID: UUID?
    @Published private(set) var statusMessage: String?
    @Published private(set) var hatchedDragon: OwnedDragon?

    var onWorldChanged: (() -> Void)?

    init(store: GameStateStore) {
        self.store = store
    }

    var selectedPlacement: PlacedBuilding? {
        guard let id = selectedPlacementID else { return nil }
        return store.state.placedBuildings.first { $0.id == id }
    }

    var isMoving: Bool { movingPlacementID != nil }
    var isPlacing: Bool { store.pendingPlacement != nil }

    func handleTap(_ tile: TileCoordinate) {
        if store.pendingPlacement != nil {
            if let failure = store.placePending(at: tile) {
                statusMessage = failure.message
            } else {
                statusMessage = "Placed."
                selectedPlacementID = nil
                onWorldChanged?()
            }
            return
        }

        if let movingPlacementID {
            finishMove(id: movingPlacementID, to: tile)
            return
        }

        if let placed = IslandEconomy.placement(at: tile, state: store.state) {
            selectedPlacementID = placed.id
            statusMessage = nil
        } else {
            dismissSelection()
        }
    }

    func dismissSelection() {
        selectedPlacementID = nil
        statusMessage = nil
    }

    // MARK: - Selection actions

    func collectSelected() {
        guard let placed = selectedPlacement else { return }
        switch placed.kind {
        case .habitat:
            let gold = store.collectHabitat(id: placed.id)
            guard gold > 0 else { statusMessage = "Nothing to collect yet."; return }
            store.playSound(.collect)
            statusMessage = "Collected \(gold) gold."
        case .farm:
            let food = store.harvestFarm(id: placed.id)
            guard food > 0 else { statusMessage = "Crops are still growing."; return }
            store.playSound(.collect)
            statusMessage = "Harvested \(food) food."
        case .building:
            hatch(in: placed)
            return
        }
        onWorldChanged?()
    }

    func plantSelected() {
        guard let placed = selectedPlacement, placed.kind == .farm else { return }
        if store.plantFarm(id: placed.id) {
            statusMessage = "Planted. Come back when the crops are ready."
            onWorldChanged?()
        } else {
            statusMessage = placed.plantedAt == nil ? "Not enough gold to plant."
                                                    : "Crops are already growing."
        }
    }

    func feedSelected() {
        guard let placed = selectedPlacement, placed.kind == .habitat,
              let dragon = firstOccupant(in: placed) else { return }
        if let outcome = store.feedDragon(id: dragon.id) {
            statusMessage = outcome.leveledUp
                ? "\(outcome.name) reached level \(outcome.level)."
                : "\(outcome.name) ate and feels stronger."
            onWorldChanged?()
        } else {
            statusMessage = "Not enough food, or max level."
        }
    }

    func hatchSelected() {
        guard let placed = selectedPlacement, placed.kind == .building else { return }
        hatch(in: placed)
    }

    func beginMoving() {
        guard let placed = selectedPlacement else { return }
        movingPlacementID = placed.id
        selectedPlacementID = nil
        statusMessage = nil
    }

    func cancelMove() {
        movingPlacementID = nil
        statusMessage = nil
    }

    func clearHatchedDragon() {
        hatchedDragon = nil
    }

    // MARK: - Eligibility for the info panel

    func canPlant(_ placed: PlacedBuilding) -> Bool {
        guard placed.kind == .farm, placed.plantedAt == nil,
              let definition = store.catalog.building(placed.definitionID),
              definition.isFarm else { return false }
        return store.state.resources.gold >= (definition.plantCost ?? 0)
    }

    func canFeed(_ placed: PlacedBuilding) -> Bool {
        guard let dragon = firstOccupant(in: placed) else { return false }
        let config = store.rules.leveling
        return dragon.level < config.maxLevel && store.state.resources.food >= config.foodPerFeed
    }

    func firstOccupant(in placed: PlacedBuilding) -> OwnedDragon? {
        IslandEconomy.occupants(of: placed, state: store.state, catalog: store.catalog).first
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

    private func hatch(in placed: PlacedBuilding) {
        switch store.hatchFirstReadyEgg(in: placed.id) {
        case .success(let dragon):
            hatchedDragon = dragon
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
