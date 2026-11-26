import Foundation

enum PlacementFailure: String, Error, Sendable {
    case outOfBounds
    case tileOccupied
    case unknownDefinition
    case insufficientGold
    case locked

    var message: String {
        switch self {
        case .outOfBounds: return "That plot is outside the island."
        case .tileOccupied: return "That plot is already taken."
        case .unknownDefinition: return "That structure is unavailable."
        case .insufficientGold: return "Not enough gold."
        case .locked: return "That structure is still locked."
        }
    }
}

struct HabitatStatus: Sendable {
    let placement: PlacedBuilding
    let definition: HabitatDefinition
    let occupants: [OwnedDragon]
    let pendingGold: Int
    let bubbleThreshold: Int
    let secondsUntilReady: TimeInterval?
    let secondsUntilBubble: TimeInterval?

    var canCollect: Bool { pendingGold >= 1 }
    var showsBubble: Bool { bubbleThreshold > 0 && pendingGold >= bubbleThreshold }
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
                       catalog: GameCatalog, now: Date,
                       bubbleFraction: Double) -> HabitatStatus? {
        guard habitat.kind == .habitat,
              let definition = catalog.habitat(habitat.definitionID) else { return nil }
        let occupants = occupants(of: habitat, state: state, catalog: catalog)
        let pending = pendingGold(habitat: habitat, definition: definition,
                                  occupantCount: occupants.count, now: now)
        let threshold = bubbleThreshold(definition: definition, fraction: bubbleFraction)
        return HabitatStatus(
            placement: habitat,
            definition: definition,
            occupants: occupants,
            pendingGold: pending,
            bubbleThreshold: threshold,
            secondsUntilReady: secondsUntilReady(pending: pending, definition: definition,
                                                occupantCount: occupants.count),
            secondsUntilBubble: secondsUntilBubble(pending: pending, threshold: threshold,
                                                  definition: definition,
                                                  occupantCount: occupants.count)
        )
    }

    static func bubbleThreshold(definition: HabitatDefinition, fraction: Double) -> Int {
        guard definition.goldCap > 0 else { return 0 }
        let clamped = min(max(fraction, 0), 1)
        return max(1, Int((Double(definition.goldCap) * clamped).rounded(.up)))
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

    static func secondsUntilBubble(pending: Int, threshold: Int,
                                   definition: HabitatDefinition,
                                   occupantCount: Int) -> TimeInterval? {
        guard threshold > 0, pending < threshold else { return nil }
        let rate = definition.goldPerHour * occupantCount
        guard rate > 0 else { return nil }
        return TimeInterval(threshold - pending) / Double(rate) * 3600
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

    static func unlockLevel(kind: PlacementKind, definitionID: String,
                            catalog: GameCatalog) -> Int? {
        switch kind {
        case .habitat:
            return catalog.habitat(definitionID)?.unlockLevel
        case .farm, .building:
            return catalog.building(definitionID)?.requiredLevel
        }
    }

    static func isUnlocked(kind: PlacementKind, definitionID: String,
                           catalog: GameCatalog, islandLevel: Int) -> Bool {
        guard let required = unlockLevel(kind: kind, definitionID: definitionID, catalog: catalog)
        else { return false }
        return islandLevel >= required
    }

    /// Nearest free plot for a newly hatched dragon, so it does not stand on
    /// top of a building or another dragon.
    static func freeTile(near tile: TileCoordinate, state: IslandSaveState) -> TileCoordinate {
        let grid = IslandGrid()
        var best = tile
        var bestDistance = Int.max
        for candidate in grid.allTiles {
            guard placement(at: candidate, state: state) == nil,
                  !state.ownedDragons.contains(where: { $0.tile == candidate })
            else { continue }
            let distance = abs(candidate.x - tile.x) + abs(candidate.y - tile.y)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
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
