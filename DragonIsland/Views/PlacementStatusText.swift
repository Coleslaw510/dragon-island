import Foundation

/// Text and eligibility helpers for the selected building.  Kept out of the
/// panel so `BuildPanelView` stays small and easy to scan.
enum PlacementStatusText {
    static func detail(for placed: PlacedBuilding, store: GameStateStore, now: Date) -> String {
        switch placed.kind {
        case .habitat:
            return habitatDetail(placed, store: store, now: now)
        case .farm:
            return farmDetail(placed, store: store, now: now)
        case .building:
            return buildingDetail(placed, store: store, now: now)
        }
    }

    static func canCollect(_ placed: PlacedBuilding, store: GameStateStore,
                           now: Date = .now) -> Bool {
        switch placed.kind {
        case .habitat:
            return habitatStatus(placed, store: store, now: now)?.canCollect ?? false
        case .farm:
            return FarmGrowth.stage(for: placed, catalog: store.catalog, now: now) == .ready
        case .building:
            return store.hasReadyEgg(in: placed.id, now: now)
        }
    }

    static func isHatchable(_ placed: PlacedBuilding, store: GameStateStore,
                            now: Date = .now) -> Bool {
        placed.kind == .building && store.hasReadyEgg(in: placed.id, now: now)
    }

    // MARK: - Details

    private static func habitatDetail(_ placed: PlacedBuilding, store: GameStateStore,
                                      now: Date) -> String {
        guard let status = habitatStatus(placed, store: store, now: now) else { return "Habitat" }
        if status.occupants.isEmpty {
            return "\(status.occupancyText) · no gold income"
        }
        if status.pendingGold >= status.definition.goldCap {
            return "\(status.occupancyText) · gold ready: \(status.pendingGold)"
        }
        var text = "\(status.occupancyText) · gold \(status.pendingGold)/\(status.definition.goldCap)"
        if status.canCollect {
            text += " · tap to collect"
        }
        if let seconds = status.secondsUntilReady {
            text += " · full in \(TimeFormat.short(seconds))"
        }
        return text
    }

    private static func farmDetail(_ placed: PlacedBuilding, store: GameStateStore,
                                   now: Date) -> String {
        guard let definition = store.catalog.building(placed.definitionID), definition.isFarm else {
            return "Food farm"
        }
        let stage = FarmGrowth.stage(for: placed, catalog: store.catalog, now: now)
        switch stage {
        case .empty:
            return "Empty soil. Plant for \(definition.plantCost ?? 0) gold."
        case .plantedSprouts, .growingCrops:
            let remaining = FarmGrowth.secondsRemaining(plantedAt: placed.plantedAt,
                                                         definition: definition, now: now) ?? 0
            return "Growing · \(TimeFormat.short(remaining)) left · yields \(definition.harvestFood ?? 0) food"
        case .ready:
            return "Ready to harvest · \(definition.harvestFood ?? 0) food"
        }
    }

    private static func buildingDetail(_ placed: PlacedBuilding, store: GameStateStore,
                                       now: Date) -> String {
        let eggs = store.eggs(in: placed.id)
        if store.eggCapacity(for: placed) > 0 {
            let ready = eggs.filter { $0.isReady(now: now) }.count
            let slots = store.eggCapacity(for: placed)
            if ready > 0 { return "\(eggs.count)/\(slots) eggs · \(ready) ready to hatch" }
            if !eggs.isEmpty { return "\(eggs.count)/\(slots) eggs incubating" }
            return "\(slots) egg slots free"
        }

        let sessions = store.breedingSessions(in: placed.id)
        if !sessions.isEmpty {
            let ready = sessions.filter { $0.isReady(now: now) }.count
            return ready > 0 ? "Breeding complete · waiting for a hatchery slot"
                             : "Breeding in progress · \(sessions.count) pair"
        }

        return store.catalog.building(placed.definitionID)?.description ?? "Idle for now."
    }

    private static func habitatStatus(_ placed: PlacedBuilding, store: GameStateStore,
                                      now: Date) -> HabitatStatus? {
        IslandEconomy.status(
            for: placed,
            state: store.state,
            catalog: store.catalog,
            now: now,
            bubbleFraction: store.catalog.economy.habitatGoldBubbleFraction
        )
    }
}
