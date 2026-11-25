import Foundation

enum SaveStateFactory {
    /// Seeds a fresh island from the catalog: one habitat per element, the
    /// starter buildings and one dragon per element standing next to its home.
    static func makeStarter(catalog: GameCatalog, now: Date = .now) -> IslandSaveState {
        var placements: [PlacedBuilding] = []
        var habitatIDs: [ElementType: UUID] = [:]

        for item in catalog.starterLayout {
            let id = UUID()
            let element = item.kind == .habitat ? catalog.habitat(item.definitionID)?.element : nil
            placements.append(
                PlacedBuilding(
                    id: id,
                    definitionID: item.definitionID,
                    kind: item.kind,
                    tileX: item.tileX,
                    tileY: item.tileY,
                    level: 1,
                    element: element,
                    placedAt: now
                )
            )
            if let element {
                habitatIDs[element] = id
            }
        }

        let dragons = catalog.starterDragons.compactMap { starter -> OwnedDragon? in
            guard let definition = catalog.dragon(starter.definitionID) else { return nil }
            return OwnedDragon(
                id: UUID(),
                definitionID: definition.id,
                nickname: definition.displayName,
                level: starter.level,
                experience: 0,
                energy: 100,
                assignedHabitatID: habitatIDs[definition.element],
                tileX: starter.tileX,
                tileY: starter.tileY,
                hatchedAt: now
            )
        }

        return IslandSaveState(
            schemaVersion: GameConfig.saveSchemaVersion,
            playerName: "Keeper",
            islandLevel: 1,
            resources: .starter,
            ownedDragons: dragons,
            placedBuildings: placements,
            selectedDragonID: dragons.first?.id,
            lastSavedAt: now,
            lastSeenAt: now,
            lastCollectionAt: now,
            unlockedElements: catalog.elementOrder,
            didCompleteTutorial: false
        )
    }
}
