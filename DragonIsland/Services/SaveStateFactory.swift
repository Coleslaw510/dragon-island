import Foundation

enum SaveStateFactory {
    /// Seeds a brand new island: one hatchery on the centre plot, no dragons
    /// and the tutorial ready to start.  Existing saves never pass through here.
    static func makeStarter(catalog: GameCatalog, now: Date = .now) -> IslandSaveState {
        let placements = catalog.starterLayout.map { item in
            PlacedBuilding(
                id: UUID(),
                definitionID: item.definitionID,
                kind: item.kind,
                tileX: item.tileX,
                tileY: item.tileY,
                level: 1,
                element: item.kind == .habitat ? catalog.habitat(item.definitionID)?.element : nil,
                placedAt: now
            )
        }

        var habitatIDs: [ElementType: UUID] = [:]
        for placed in placements {
            if let element = placed.element { habitatIDs[element] = placed.id }
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
            resources: catalog.startingResources.resourceState,
            ownedDragons: dragons,
            placedBuildings: placements,
            selectedDragonID: nil,
            lastSavedAt: now,
            lastSeenAt: now,
            lastCollectionAt: now,
            unlockedElements: catalog.elementOrder,
            didCompleteTutorial: false,
            tutorialStepID: catalog.tutorialSteps.first?.id
        )
    }
}
