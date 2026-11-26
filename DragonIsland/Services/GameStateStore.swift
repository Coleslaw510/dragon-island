import Combine
import Foundation

/// Owns the save file and publishes the single source of truth for the game.
/// Saves are small JSON documents in Application Support, written atomically.
final class GameStateStore: ObservableObject {
    @Published internal(set) var state: IslandSaveState

    let catalog: GameCatalog
    let rules: BreedingRules
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(catalog: GameCatalog, rules: BreedingRules = .empty, fileManager: FileManager = .default) {
        self.catalog = catalog
        self.rules = rules
        self.fileManager = fileManager

        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = base.appendingPathComponent("DragonIsland", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("island_save.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        var loaded = Self.loadOrCreate(at: fileURL, catalog: catalog, decoder: decoder, fileManager: fileManager)
        Self.normalizePlacements(&loaded, catalog: catalog)
        self.state = loaded
        IslandEconomy.reconcileAssignments(&state, catalog: catalog, now: .now)
        syncIslandLevel()
        beginSession()
    }

    // MARK: - Session hooks

    /// Pending gold is never collected automatically.  It keeps accruing from
    /// timestamps until the player taps the habitat.
    func beginSession(now: Date = .now) {
        completeReadyBreedings(now: now)
        state.lastSeenAt = now
        save()
    }

    func endSession(now: Date = .now) {
        state.lastSeenAt = now
        save()
    }

    // MARK: - Persistence

    func save() {
        state.lastSavedAt = .now
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[GameStateStore] save failed: \(error)")
        }
    }

    private static func loadOrCreate(at url: URL, catalog: GameCatalog,
                                     decoder: JSONDecoder, fileManager: FileManager) -> IslandSaveState {
        guard let data = try? Data(contentsOf: url) else {
            return SaveStateFactory.makeStarter(catalog: catalog)
        }
        if let decoded = try? decoder.decode(IslandSaveState.self, from: data),
           decoded.schemaVersion == GameConfig.saveSchemaVersion {
            return decoded
        }

        // Keep an unreadable save for debugging instead of deleting it silently.
        let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
        try? fileManager.removeItem(at: backup)
        try? fileManager.moveItem(at: url, to: backup)
        return SaveStateFactory.makeStarter(catalog: catalog)
    }

    /// Older saves stored the starter farm as a plain building.  The kind now
    /// drives farm timers, so promote anything whose definition is a farm.
    private static func normalizePlacements(_ state: inout IslandSaveState, catalog: GameCatalog) {
        for index in state.placedBuildings.indices
        where state.placedBuildings[index].kind == .building
            && catalog.building(state.placedBuildings[index].definitionID)?.isFarm == true {
            state.placedBuildings[index].kind = .farm
        }
    }

    // MARK: - Placement and economy

    @discardableResult
    func buildPlacement(kind: PlacementKind, definitionID: String, tile: TileCoordinate,
                        now: Date = .now) -> Result<PlacedBuilding, PlacementFailure> {
        guard IslandGrid().contains(tile) else { return .failure(.outOfBounds) }
        guard IslandEconomy.placement(at: tile, state: state) == nil else { return .failure(.tileOccupied) }
        guard IslandEconomy.definitionExists(kind: kind, definitionID: definitionID, catalog: catalog),
              let cost = IslandEconomy.cost(kind: kind, definitionID: definitionID, catalog: catalog)
        else { return .failure(.unknownDefinition) }
        guard IslandEconomy.isUnlocked(kind: kind, definitionID: definitionID,
                                      catalog: catalog, islandLevel: state.islandLevel)
        else { return .failure(.locked) }
        guard state.resources.gold >= cost else { return .failure(.insufficientGold) }

        state.resources.gold -= cost
        let placed = PlacedBuilding(
            id: UUID(),
            definitionID: definitionID,
            kind: kind,
            tileX: tile.x,
            tileY: tile.y,
            level: 1,
            element: kind == .habitat ? catalog.habitat(definitionID)?.element : nil,
            placedAt: now
        )
        state.placedBuildings.append(placed)
        if kind == .habitat {
            IslandEconomy.reconcileAssignments(&state, catalog: catalog, now: now)
        }
        save()
        return .success(placed)
    }

    @discardableResult
    func movePlacement(id: UUID, to tile: TileCoordinate) -> Result<PlacedBuilding, PlacementFailure> {
        guard IslandGrid().contains(tile) else { return .failure(.outOfBounds) }
        guard let index = state.placedBuildings.firstIndex(where: { $0.id == id }) else {
            return .failure(.unknownDefinition)
        }
        guard state.placedBuildings[index].tile != tile else { return .success(state.placedBuildings[index]) }
        guard IslandEconomy.placement(at: tile, state: state) == nil else { return .failure(.tileOccupied) }

        state.placedBuildings[index].tileX = tile.x
        state.placedBuildings[index].tileY = tile.y
        save()
        return .success(state.placedBuildings[index])
    }

    @discardableResult
    func collectHabitat(id: UUID, now: Date = .now) -> Int {
        guard let index = state.placedBuildings.firstIndex(where: { $0.id == id }),
              let status = IslandEconomy.status(
                  for: state.placedBuildings[index],
                  state: state,
                  catalog: catalog,
                  now: now,
                  bubbleFraction: catalog.economy.habitatGoldBubbleFraction
              ),
              status.canCollect else { return 0 }
        state.resources.gold += status.pendingGold
        state.placedBuildings[index].lastCollectedAt = now
        state.lastCollectionAt = now
        save()
        return status.pendingGold
    }

    @discardableResult
    func plantFarm(id: UUID, now: Date = .now) -> Bool {
        guard let index = state.placedBuildings.firstIndex(where: { $0.id == id }),
              state.placedBuildings[index].kind == .farm,
              state.placedBuildings[index].plantedAt == nil,
              let definition = catalog.building(state.placedBuildings[index].definitionID),
              definition.isFarm else { return false }
        let cost = definition.plantCost ?? 0
        guard state.resources.gold >= cost else { return false }

        state.resources.gold -= cost
        state.placedBuildings[index].plantedAt = now
        save()
        return true
    }

    @discardableResult
    func harvestFarm(id: UUID, now: Date = .now) -> Int {
        guard let index = state.placedBuildings.firstIndex(where: { $0.id == id }),
              let definition = catalog.building(state.placedBuildings[index].definitionID),
              let harvest = definition.harvestFood,
              FarmGrowth.stage(for: state.placedBuildings[index], catalog: catalog, now: now) == .ready
        else { return 0 }

        state.resources.food += harvest
        state.placedBuildings[index].plantedAt = nil
        save()
        return harvest
    }

    // MARK: - Resources

    func add(_ amount: Int, to kind: ResourceState.Kind) {
        state.resources.add(amount, to: kind)
        save()
    }

    @discardableResult
    func spend(_ amount: Int, from kind: ResourceState.Kind) -> Bool {
        guard state.resources.value(for: kind) >= amount else { return false }
        state.resources.add(-amount, to: kind)
        save()
        return true
    }

    func selectDragon(_ id: UUID?) {
        state.selectedDragonID = id
        save()
    }
}
