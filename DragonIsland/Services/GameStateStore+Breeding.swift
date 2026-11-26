import Foundation

/// Breeding, incubation, hatching and feeding.  Every number comes from
/// `breeding_rules.json`; this file only sequences state changes.
extension GameStateStore {
    var breedingSessions: [BreedingSession] { state.breedingSessions ?? [] }
    var eggs: [DragonEgg] { state.eggs ?? [] }

    // MARK: - Breeding buildings

    var breedingBuildings: [PlacedBuilding] {
        state.placedBuildings.filter {
            $0.kind == .building && rules.breedingBuilding($0.definitionID) != nil
        }
    }

    var hatcheryBuildings: [PlacedBuilding] {
        state.placedBuildings.filter {
            $0.kind == .building && rules.incubationBuilding($0.definitionID) != nil
        }
    }

    func breedingSessions(in buildingID: UUID) -> [BreedingSession] {
        breedingSessions.filter { $0.buildingID == buildingID }
    }

    /// Dragons locked into an unfinished pair cannot start a second one.
    var busyBreedingParentIDs: Set<UUID> {
        Set(breedingSessions.flatMap { [$0.parentAID, $0.parentBID] })
    }

    func isBreedingParentBusy(_ id: UUID) -> Bool {
        busyBreedingParentIDs.contains(id)
    }

    func availableBreedingSlots(in building: PlacedBuilding) -> Int {
        guard let rule = rules.breedingBuilding(building.definitionID) else { return 0 }
        return max(0, rule.slots - breedingSessions(in: building.id).count)
    }

    func eggs(in hatcheryID: UUID) -> [DragonEgg] {
        eggs.filter { $0.hatcheryID == hatcheryID }
    }

    func eggCapacity(for building: PlacedBuilding) -> Int {
        rules.incubationBuilding(building.definitionID)?.slots ?? 0
    }

    func hasReadyEgg(in hatcheryID: UUID, now: Date = .now) -> Bool {
        eggs(in: hatcheryID).contains { $0.isReady(now: now) }
    }

    // MARK: - Breeding

    func startBreeding(buildingID: UUID, parentA: UUID, parentB: UUID,
                       now: Date = .now) -> Result<BreedingSession, BreedingFailure> {
        guard let building = state.placedBuildings.first(where: { $0.id == buildingID }),
              let timer = rules.breedingBuilding(building.definitionID) else {
            return .failure(.noBuilding)
        }
        guard availableBreedingSlots(in: building) > 0 else { return .failure(.noSlot) }
        guard parentA != parentB else { return .failure(.sameDragon) }
        guard !isBreedingParentBusy(parentA), !isBreedingParentBusy(parentB) else {
            return .failure(.dragonBusy)
        }
        guard let dragonA = state.ownedDragons.first(where: { $0.id == parentA }),
              let dragonB = state.ownedDragons.first(where: { $0.id == parentB }),
              let definitionA = catalog.dragon(dragonA.definitionID),
              let definitionB = catalog.dragon(dragonB.definitionID) else {
            return .failure(.unknownDragon)
        }
        guard state.resources.gold >= rules.breeding.goldCost else {
            return .failure(.insufficientGold)
        }
        guard state.resources.food >= rules.breeding.foodCost else {
            return .failure(.insufficientFood)
        }

        let blueprint = rules.blueprint(parentA: definitionA.element, parentB: definitionB.element)
        guard let blueprintDragon = catalog.dragon(blueprint.dragonID),
              isDragonAvailable(blueprintDragon) else { return .failure(.ruleMissing) }

        state.resources.gold -= rules.breeding.goldCost
        state.resources.food -= rules.breeding.foodCost
        let session = BreedingSession(
            id: UUID(),
            buildingID: building.id,
            parentAID: parentA,
            parentBID: parentB,
            startedAt: now,
            readyAt: now.addingTimeInterval(TimeInterval(timer.seconds)),
            egg: blueprint
        )
        state.breedingSessions = breedingSessions + [session]
        save()
        return .success(session)
    }

    /// Completed pairs move into any hatchery with a free slot.  Incubation
    /// starts at the breeding end time, so offline time is counted.
    @discardableResult
    func completeReadyBreedings(now: Date = .now) -> Int {
        let sessions = breedingSessions
        guard sessions.contains(where: { $0.isReady(now: now) }) else { return 0 }

        var used: [UUID: Int] = [:]
        for egg in eggs { used[egg.hatcheryID, default: 0] += 1 }
        var remaining: [BreedingSession] = []
        var nextEggs = eggs
        var moved = 0

        for session in sessions {
            guard session.isReady(now: now) else {
                remaining.append(session)
                continue
            }
            guard let hatchery = hatcheryBuildings.first(where: { placed in
                guard let rule = rules.incubationBuilding(placed.definitionID) else { return false }
                return used[placed.id, default: 0] < rule.slots
            }), let rule = rules.incubationBuilding(hatchery.definitionID) else {
                remaining.append(session)
                continue
            }
            let laid = session.readyAt
            nextEggs.append(
                DragonEgg(
                    id: UUID(),
                    hatcheryID: hatchery.id,
                    blueprint: session.egg,
                    laidAt: laid,
                    readyAt: laid.addingTimeInterval(TimeInterval(rule.seconds))
                )
            )
            used[hatchery.id, default: 0] += 1
            moved += 1
        }

        guard moved > 0 else { return 0 }
        state.eggs = nextEggs.isEmpty ? nil : nextEggs
        state.breedingSessions = remaining.isEmpty ? nil : remaining
        recordCompletedBreedings(moved)
        save()
        return moved
    }

    // MARK: - Hatching

    func hatchEgg(id eggID: UUID, now: Date = .now) -> Result<OwnedDragon, HatchFailure> {
        guard let index = eggs.firstIndex(where: { $0.id == eggID }) else { return .failure(.noEgg) }
        let egg = eggs[index]
        guard egg.isReady(now: now) else { return .failure(.notReady) }
        guard let hatchery = state.placedBuildings.first(where: { $0.id == egg.hatcheryID }) else {
            return .failure(.noHatchery)
        }
        guard let definition = catalog.dragon(egg.blueprint.dragonID) else {
            return .failure(.unknownDragon)
        }

        var nextEggs = eggs
        nextEggs.remove(at: index)
        let tile = IslandEconomy.freeTile(near: hatchery.tile, state: state)
        let dragon = OwnedDragon(
            id: UUID(),
            definitionID: definition.id,
            nickname: definition.displayName,
            level: max(1, rules.hatching.level),
            experience: 0,
            energy: rules.hatching.energy,
            assignedHabitatID: nil,
            tileX: tile.x,
            tileY: tile.y,
            hatchedAt: now
        )
        state.eggs = nextEggs.isEmpty ? nil : nextEggs
        state.ownedDragons.append(dragon)
        recordHatchedDragon()
        playSound(.hatch)
        state.selectedDragonID = dragon.id
        notifyTutorialEvent("hatch_egg")
        syncIslandLevel()
        save()
        return .success(dragon)
    }

    func hatchFirstReadyEgg(in hatcheryID: UUID,
                            now: Date = .now) -> Result<OwnedDragon, HatchFailure> {
        guard let egg = eggs(in: hatcheryID).first(where: { $0.isReady(now: now) }) else {
            return .failure(.noEgg)
        }
        return hatchEgg(id: egg.id, now: now)
    }

    // MARK: - Feeding and growth

    @discardableResult
    func feedDragon(id: UUID) -> FeedOutcome? {
        let config = rules.leveling
        guard config.foodPerFeed > 0,
              let index = state.ownedDragons.firstIndex(where: { $0.id == id }),
              state.ownedDragons[index].level < config.maxLevel,
              state.resources.food >= config.foodPerFeed else { return nil }

        let dragon = state.ownedDragons[index]
        let previousLevel = dragon.level
        let result = BreedingEngine.feed(level: dragon.level,
                                         experience: dragon.experience,
                                         config: config)
        state.resources.food -= config.foodPerFeed
        state.ownedDragons[index].level = result.level
        state.ownedDragons[index].experience = result.experience
        notifyTutorialEvent("feed_dragon")
        syncIslandLevel()
        save()
        return FeedOutcome(
            dragonID: dragon.id,
            name: dragon.nickname,
            level: result.level,
            leveledUp: result.level > previousLevel
        )
    }

    func syncIslandLevel() {
        let best = state.ownedDragons.map(\.level).max() ?? 1
        if best > state.islandLevel {
            state.islandLevel = best
        }
    }

    /// Called by the host view once a second so finished breeding moves into
    /// hatchery slots even while the player is looking at the island.
    func tick(now: Date = .now) {
        completeReadyBreedings(now: now)
    }
}
