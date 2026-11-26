import Foundation

enum FarmStage: String, CaseIterable, Sendable {
    case empty
    case plantedSprouts
    case growingCrops
    case ready

    var textureName: String {
        switch self {
        case .empty: return "building_food_farm"
        case .plantedSprouts: return "farm_planted_sprouts"
        case .growingCrops: return "farm_growing_crops"
        case .ready: return "farm_ready_to_harvest"
        }
    }
}

/// Pure timer math for food farms.  All durations come from the catalog so a
/// balance pass only touches `starter_catalog.json`.
enum FarmGrowth {
    static func stage(plantedAt: Date?, definition: BuildingDefinition?, now: Date) -> FarmStage {
        guard let definition, definition.isFarm, let growSeconds = definition.growSeconds,
              let plantedAt else { return .empty }
        let elapsed = now.timeIntervalSince(plantedAt)
        guard elapsed < TimeInterval(growSeconds) else { return .ready }
        let sproutAt = TimeInterval(growSeconds) * sproutFraction(definition)
        return elapsed < sproutAt ? .plantedSprouts : .growingCrops
    }

    static func stage(for placed: PlacedBuilding, catalog: GameCatalog, now: Date) -> FarmStage {
        stage(plantedAt: placed.plantedAt,
              definition: catalog.building(placed.definitionID),
              now: now)
    }

    static func secondsRemaining(plantedAt: Date?, definition: BuildingDefinition?, now: Date) -> TimeInterval? {
        guard let definition, definition.isFarm, let growSeconds = definition.growSeconds,
              let plantedAt else { return nil }
        return max(0, TimeInterval(growSeconds) - now.timeIntervalSince(plantedAt))
    }

    /// Stage transitions still ahead of `now`, expressed as delays from `now`.
    static func pendingTransitions(plantedAt: Date?, definition: BuildingDefinition?,
                                   now: Date) -> [(delay: TimeInterval, stage: FarmStage)] {
        guard let definition, definition.isFarm, let growSeconds = definition.growSeconds,
              let plantedAt else { return [] }
        let total = TimeInterval(growSeconds)
        let elapsed = now.timeIntervalSince(plantedAt)
        guard elapsed < total else { return [] }

        var transitions: [(delay: TimeInterval, stage: FarmStage)] = []
        let sproutAt = total * sproutFraction(definition)
        if elapsed < sproutAt {
            transitions.append((delay: sproutAt - elapsed, stage: .growingCrops))
        }
        transitions.append((delay: total - elapsed, stage: .ready))
        return transitions
    }

    private static func sproutFraction(_ definition: BuildingDefinition) -> Double {
        min(max(definition.sproutFraction ?? 0.5, 0.01), 0.99)
    }
}
