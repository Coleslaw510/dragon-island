import Foundation

/// Habitat picking after a hatch.  A new dragon stays unassigned until the
/// player confirms a home, which also drives the "Place your dragon" step.
extension GameStateStore {
    var habitatPlacements: [PlacedBuilding] {
        state.placedBuildings.filter { $0.kind == .habitat }
    }

    func element(of dragon: OwnedDragon) -> ElementType? {
        catalog.dragon(dragon.definitionID)?.element
    }

    func matchingHabitats(for element: ElementType) -> [PlacedBuilding] {
        state.placedBuildings.filter { placed in
            placed.kind == .habitat && catalog.habitat(placed.definitionID)?.element == element
        }
    }

    func occupantCount(in habitat: PlacedBuilding) -> Int {
        state.ownedDragons.filter { $0.assignedHabitatID == habitat.id }.count
    }

    func freeHabitats(for element: ElementType) -> [PlacedBuilding] {
        matchingHabitats(for: element).filter { habitat in
            guard let definition = catalog.habitat(habitat.definitionID) else { return false }
            return occupantCount(in: habitat) < definition.capacity
        }
    }

    @discardableResult
    func assignDragon(_ dragonID: UUID, to habitatID: UUID) -> Bool {
        guard let dragonIndex = state.ownedDragons.firstIndex(where: { $0.id == dragonID }),
              let habitatIndex = state.placedBuildings.firstIndex(where: { $0.id == habitatID }),
              state.placedBuildings[habitatIndex].kind == .habitat,
              let definition = catalog.habitat(state.placedBuildings[habitatIndex].definitionID),
              let dragonElement = element(of: state.ownedDragons[dragonIndex]),
              dragonElement == definition.element else { return false }

        let others = state.ownedDragons.enumerated().filter {
            $0.offset != dragonIndex && $0.element.assignedHabitatID == habitatID
        }.count
        guard others < definition.capacity else { return false }

        state.ownedDragons[dragonIndex].assignedHabitatID = habitatID
        if others == 0 {
            state.placedBuildings[habitatIndex].lastCollectedAt = .now
        }
        moveDragon(dragonIndex, near: state.placedBuildings[habitatIndex])
        if tutorialTargetMatches(definition.id) {
            notifyTutorialEvent("place_dragon")
        }
        save()
        return true
    }

    /// Falls back to the normal auto-assignment when the player skips the
    /// habitat picker, so a hatched dragon never becomes unreachable.
    func assignUnplacedDragons(now: Date = .now) {
        let unassigned = Set(state.ownedDragons.filter { $0.assignedHabitatID == nil }.map(\.id))
        IslandEconomy.reconcileAssignments(&state, catalog: catalog, now: now)
        for index in state.ownedDragons.indices where unassigned.contains(state.ownedDragons[index].id) {
            guard let habitatID = state.ownedDragons[index].assignedHabitatID,
                  let habitat = state.placedBuildings.first(where: { $0.id == habitatID }) else { continue }
            moveDragon(index, near: habitat)
        }
        if state.ownedDragons.contains(where: { $0.assignedHabitatID != nil }) {
            notifyTutorialEvent("place_dragon")
        }
        save()
    }

    private func moveDragon(_ index: Int, near habitat: PlacedBuilding) {
        let spot = IslandEconomy.freeTile(near: habitat.tile, state: state)
        state.ownedDragons[index].tileX = spot.x
        state.ownedDragons[index].tileY = spot.y
    }
}
