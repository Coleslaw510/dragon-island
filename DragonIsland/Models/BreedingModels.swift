import Foundation

/// Egg result chosen by `breeding_rules.json`.  Swift never invents pairings.
struct EggBlueprint: Codable, Hashable, Sendable {
    let element: ElementType
    let dragonID: String
}

struct BuildingTimerRule: Codable, Hashable, Sendable {
    let slots: Int
    let seconds: Int
}

struct BreedingPairRule: Codable, Hashable, Sendable {
    let elements: [ElementType]
    let element: ElementType
    let dragonID: String

    func matches(_ a: ElementType, _ b: ElementType) -> Bool {
        guard elements.count == 2 else { return false }
        return (elements[0] == a && elements[1] == b)
            || (elements[0] == b && elements[1] == a)
    }
}

struct BreedingConfig: Codable, Sendable {
    let goldCost: Int
    let foodCost: Int
    let buildings: [String: BuildingTimerRule]
    let sameElement: [String: EggBlueprint]
    let pairs: [BreedingPairRule]
    let fallback: EggBlueprint
}

struct IncubationConfig: Codable, Sendable {
    let buildings: [String: BuildingTimerRule]
}

struct HatchingConfig: Codable, Sendable {
    let level: Int
    let energy: Int
}

struct LevelingConfig: Codable, Sendable {
    let foodPerFeed: Int
    let xpPerFeed: Int
    let maxLevel: Int
    let xpTable: [Int]
}

struct GrowthStageRule: Codable, Hashable, Sendable {
    let id: String
    let minLevel: Int
    let scale: Double
    let tintHex: String?
    let tintStrength: Double?
}

struct GrowthConfig: Codable, Sendable {
    let stages: [GrowthStageRule]
}

/// Root of `breeding_rules.json`: breeding, incubation, feeding and growth.
struct BreedingRules: Codable, Sendable {
    let schemaVersion: Int
    let breeding: BreedingConfig
    let incubation: IncubationConfig
    let hatching: HatchingConfig
    let leveling: LevelingConfig
    let growth: GrowthConfig

    static let empty = BreedingRules(
        schemaVersion: 0,
        breeding: BreedingConfig(
            goldCost: 0,
            foodCost: 0,
            buildings: [:],
            sameElement: [:],
            pairs: [],
            fallback: EggBlueprint(element: .fire, dragonID: "")
        ),
        incubation: IncubationConfig(buildings: [:]),
        hatching: HatchingConfig(level: 1, energy: 100),
        leveling: LevelingConfig(foodPerFeed: 0, xpPerFeed: 0, maxLevel: 1, xpTable: []),
        growth: GrowthConfig(stages: [])
    )

    func breedingBuilding(_ definitionID: String) -> BuildingTimerRule? {
        breeding.buildings[definitionID]
    }

    func incubationBuilding(_ definitionID: String) -> BuildingTimerRule? {
        incubation.buildings[definitionID]
    }

    func blueprint(parentA: ElementType, parentB: ElementType) -> EggBlueprint {
        if parentA == parentB, let same = breeding.sameElement[parentA.rawValue] {
            return same
        }
        if let pair = breeding.pairs.first(where: { $0.matches(parentA, parentB) }) {
            return EggBlueprint(element: pair.element, dragonID: pair.dragonID)
        }
        return breeding.fallback
    }
}

struct BreedingSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var buildingID: UUID
    var parentAID: UUID
    var parentBID: UUID
    var startedAt: Date
    var readyAt: Date
    var egg: EggBlueprint

    func isReady(now: Date) -> Bool { now >= readyAt }
}

struct DragonEgg: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var hatcheryID: UUID
    var blueprint: EggBlueprint
    var laidAt: Date
    var readyAt: Date

    func isReady(now: Date) -> Bool { now >= readyAt }
}

enum BreedingFailure: String, Error, Sendable {
    case noBuilding
    case noSlot
    case noParents
    case sameDragon
    case dragonBusy
    case unknownDragon
    case insufficientGold
    case insufficientFood
    case ruleMissing

    var message: String {
        switch self {
        case .noBuilding: return "Select a placed breeding den or corral."
        case .noSlot: return "That breeding building is already busy."
        case .noParents: return "Pick two parent dragons."
        case .sameDragon: return "Pick two different dragons."
        case .dragonBusy: return "That dragon is already in a breeding pair."
        case .unknownDragon: return "That dragon is not on the island."
        case .insufficientGold: return "Not enough gold."
        case .insufficientFood: return "Not enough food."
        case .ruleMissing: return "No breeding rule covers that pair."
        }
    }
}

enum HatchFailure: String, Error, Sendable {
    case noEgg
    case notReady
    case noHatchery
    case unknownDragon

    var message: String {
        switch self {
        case .noEgg: return "No egg is waiting."
        case .notReady: return "That egg is still incubating."
        case .noHatchery: return "Place a hatchery to hatch eggs."
        case .unknownDragon: return "That dragon is not in the catalog."
        }
    }
}

struct FeedOutcome: Sendable {
    let dragonID: UUID
    let name: String
    let level: Int
    let leveledUp: Bool
}
