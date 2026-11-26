import Foundation

enum PlacementFailure: String, Error, Sendable {
    case outOfBounds
    case tileOccupied
    case unknownDefinition
    case insufficientGold

    var message: String {
        switch self {
        case .outOfBounds: return "That plot is outside the island."
        case .tileOccupied: return "That plot is already taken."
        case .unknownDefinition: return "That structure is unavailable."
        case .insufficientGold: return "Not enough gold."
        }
    }
}

struct HabitatStatus: Sendable {
    let placement: PlacedBuilding
    let definition: HabitatDefinition
    let occupants: [OwnedDragon]
    let pendingGold: Int
    let secondsUntilReady: TimeInterval?

    var isReady: Bool { pendingGold >= definition.goldCap && definition.goldCap > 0 }
    var occupancyText: String { "\(occupants.count)/\(definition.capacity) dragons" }
}

/// Rules that turn timestamps and catalog values into gold, food and
/// placement decisions.  No UI and no persistence live here.
enum IslandEconomy {
    // MARK: - Habitats

    static func occupants(of habitat: PlacedBuilding, state: IslandSaveState,
                          catalog: GameCatalog) -> [OwnedDragon] {
        guard let definition = catalog.habitat(habitat.definitionID) else { return [] }
        return state.ownedDragons.filter { dragon in
            dragon.assignedHabitatID == habitat.id
                && catalog.dragon(dragon.definitionID)?.element == definition.element
        }
    }

    static func status(for habitat: PlacedBuilding, state: IslandSaveState,
                       catalog: GameCatalog, now: Date) -> HabitatStatus? {
        guard habitat.kind == .habitat,
              let definition = catalog.habitat(habitat.definitionID) else { return nil }
        let occupants = occupants(of: habitat, state: state, catalog: catalog)
        let pending = pendingGold(habitat: habitat, definition: definition,
                                  occupantCount: occupants.count, now: now)
        return HabitatStatus(
            placement: habitat,
            definition: definition,
            occupants: occupants,
            pendingGold: pending,
            secondsUntilReady: secondsUntilReady(pending: pending, definition: definition,
                                                occupantCount: occupants.count)
        )
    }

    static func pendingGold(habitat: PlacedBuilding, definition: HabitatDefinition,
                            occupantCount: Int, now: Date) -> Int {
        let rate = definition.goldPerHour * occupantCount
        guard rate > 0, definition.goldCap > 0 else { return 0 }
        let start = max(habitat.lastCollectedAt ?? habitat.placedAt, habitat.placedAt)
        let elapsed = max(0, now.timeIntervalSince(start))
        let earned = Int(elapsed * Double(rate) / 3600)
        return min(earned, definition.goldCap)
    }

    static func secondsUntilReady(pending: Int, definition: HabitatDefinition,
                                  occupantCount: Int) -> TimeInterval? {
        guard definition.goldCap > 0, pending < definition.goldCap else { return nil }
        let rate = definition.goldPerHour * occupantCount
        guard rate > 0 else { return nil }
        let remaining = definition.goldCap - pending
        return TimeInterval(remaining) / Double(rate) * 3600
    }

    /// Credits gold that accumulated while the app was away.  Habitats keep
    /// their cap, so a long absence can never overpay.
    @discardableResult
    static func collectOfflineGold(_ state: inout IslandSaveState, catalog: GameCatalog,
                                   now: Date) -> Int {
        var total = 0
        for index in state.placedBuildings.indices {
            let placement = state.placedBuildings[index]
            guard placement.kind == .habitat,
                  let definition = catalog.habitat(placement.definitionID) else { continue }
            let count = occupants(of: placement, state: state, catalog: catalog).count
            let pending = pendingGold(habitat: placement, definition: definition,
                                      occupantCount: count, now: now)
            guard pending > 0 else { continue }
            total += pending
            state.placedBuildings[index].lastCollectedAt = now
        }
        if total > 0 {
            state.resources.gold += total
            state.lastCollectionAt = now
        }
        return total
    }

    // MARK: - Placement

    static func cost(kind: PlacementKind, definitionID: String, catalog: GameCatalog) -> Int? {
        switch kind {
        case .habitat:
            return catalog.habitat(definitionID)?.buildCost
        case .farm:
            guard let building = catalog.building(definitionID), building.isFarm else { return nil }
            return building.cost
        case .building:
            return catalog.building(definitionID)?.cost
        }
    }

    static func definitionExists(kind: PlacementKind, definitionID: String,
                                 catalog: GameCatalog) -> Bool {
        switch kind {
        case .habitat:
            return catalog.habitat(definitionID) != nil
        case .farm:
            return catalog.building(definitionID)?.isFarm == true
        case .building:
            return catalog.building(definitionID) != nil
        }
    }

    static func placement(at tile: TileCoordinate, state: IslandSaveState) -> PlacedBuilding? {
        state.placedBuildings.first { $0.tile == tile }
    }

    // MARK: - Dragon assignments

    /// Enforces one element per habitat and the catalog capacity.  Unassigned
    /// dragons of a matching element fill free slots in placement order.
    static func reconcileAssignments(_ state: inout IslandSaveState, catalog: GameCatalog,
                                     now: Date) {
        var slots: [(id: UUID, element: ElementType, capacity: Int)] = []
        for placed in state.placedBuildings where placed.kind == .habitat {
            guard let definition = catalog.habitat(placed.definitionID) else { continue }
            slots.append((placed.id, definition.element, definition.capacity))
        }

        var used: [UUID: Int] = [:]
        for index in state.ownedDragons.indices {
            guard let habitatID = state.ownedDragons[index].assignedHabitatID,
                  let element = catalog.dragon(state.ownedDragons[index].definitionID)?.element,
                  let slot = slots.first(where: { $0.id == habitatID }),
                  slot.element == element,
                  used[habitatID, default: 0] < slot.capacity else {
                state.ownedDragons[index].assignedHabitatID = nil
                continue
            }
            used[habitatID, default: 0] += 1
        }

        for index in state.ownedDragons.indices where state.ownedDragons[index].assignedHabitatID == nil {
            let element = catalog.dragon(state.ownedDragons[index].definitionID)?.element
            guard let element else { continue }
            for slot in slots where slot.element == element {
                guard used[slot.id, default: 0] < slot.capacity else { continue }
                let wasEmpty = used[slot.id, default: 0] == 0
                state.ownedDragons[index].assignedHabitatID = slot.id
                used[slot.id, default: 0] += 1
                if wasEmpty, let habitatIndex = state.placedBuildings.firstIndex(where: { $0.id == slot.id }) {
                    state.placedBuildings[habitatIndex].lastCollectedAt = now
                }
                break
            }
        }
    }
}
