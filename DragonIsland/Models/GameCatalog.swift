import Foundation

/// Tuning values that belong to the economy rather than a single definition.
struct EconomySettings: Codable, Hashable, Sendable {
    let habitatGoldBubbleFraction: Double

    static let empty = EconomySettings(habitatGoldBubbleFraction: 0.1)
}

/// Resources a brand new save starts with.  Kept in JSON so balance passes do
/// not need a Swift change.
struct StartingResources: Codable, Hashable, Sendable {
    let gold: Int
    let food: Int
    let gems: Int

    var resourceState: ResourceState { ResourceState(gold: gold, food: food, gems: gems, xp: 0) }
}

/// Base element egg sold in the shop.  `hatchSeconds` is the incubation time.
struct ShopEggDefinition: Codable, Identifiable, Hashable, Sendable {
    let element: ElementType
    let dragonID: String
    let cost: Int
    let unlockLevel: Int
    let hatchSeconds: Int

    var id: String { dragonID }
}

/// One guided tutorial step.  `targetID` names the control to glow.
struct TutorialStep: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let targetID: String
}

/// Root of `starter_catalog.json`.  All gameplay definitions live in that file,
/// so Swift stays free of hard-coded element and dragon tables.
struct GameCatalog: Codable, Sendable {
    let schemaVersion: Int
    let economy: EconomySettings
    let startingResources: StartingResources
    let elementOrder: [ElementType]
    let elements: [ElementDefinition]
    let dragons: [DragonDefinition]
    let habitats: [HabitatDefinition]
    let buildings: [BuildingDefinition]
    let shopEggs: [ShopEggDefinition]
    let starterLayout: [StarterPlacement]
    let starterDragons: [StarterDragon]
    let tutorialSteps: [TutorialStep]

    static let empty = GameCatalog(
        schemaVersion: 1,
        economy: .empty,
        startingResources: StartingResources(gold: 0, food: 0, gems: 0),
        elementOrder: [],
        elements: [],
        dragons: [],
        habitats: [],
        buildings: [],
        shopEggs: [],
        starterLayout: [],
        starterDragons: [],
        tutorialSteps: []
    )

    private var dragonIndex: [String: DragonDefinition] {
        Dictionary(uniqueKeysWithValues: dragons.map { ($0.id, $0) })
    }

    func dragon(_ id: String) -> DragonDefinition? {
        dragonIndex[id]
    }

    func element(_ type: ElementType) -> ElementDefinition? {
        elements.first { $0.id == type }
    }

    func habitat(_ id: String) -> HabitatDefinition? {
        habitats.first { $0.id == id }
    }

    func building(_ id: String) -> BuildingDefinition? {
        buildings.first { $0.id == id }
    }
}

struct ElementDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: ElementType
    let displayName: String
    let colorHex: String
    let badgeTexture: String
    let habitatTexture: String
    let habitatName: String
    let habitatCapacity: Int
    let habitatCost: Int
}

struct HabitatDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let element: ElementType
    let displayName: String
    let texture: String
    let capacity: Int
    let buildCost: Int
    let unlockLevel: Int
    let goldPerHour: Int
    let goldCap: Int
}

struct BuildingDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let texture: String
    let cost: Int
    let maxLevel: Int
    let footprint: [Int]
    let description: String
    let growSeconds: Int?
    let harvestFood: Int?
    let plantCost: Int?
    let sproutFraction: Double?
    let unlockLevel: Int?

    var isFarm: Bool { growSeconds != nil && harvestFood != nil }
    var requiredLevel: Int { unlockLevel ?? 1 }
}

struct StarterPlacement: Codable, Hashable, Sendable {
    let kind: PlacementKind
    let definitionID: String
    let tileX: Int
    let tileY: Int
}

struct StarterDragon: Codable, Hashable, Sendable {
    let definitionID: String
    let level: Int
    let tileX: Int
    let tileY: Int
}
