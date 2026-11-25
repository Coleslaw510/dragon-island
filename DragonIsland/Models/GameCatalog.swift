import Foundation

/// Root of `starter_catalog.json`.  All gameplay definitions live in that file,
/// so Swift stays free of hard-coded element and dragon tables.
struct GameCatalog: Codable, Sendable {
    let schemaVersion: Int
    let elementOrder: [ElementType]
    let elements: [ElementDefinition]
    let dragons: [DragonDefinition]
    let habitats: [HabitatDefinition]
    let buildings: [BuildingDefinition]
    let starterLayout: [StarterPlacement]
    let starterDragons: [StarterDragon]

    static let empty = GameCatalog(
        schemaVersion: 1,
        elementOrder: [],
        elements: [],
        dragons: [],
        habitats: [],
        buildings: [],
        starterLayout: [],
        starterDragons: []
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
}

struct BuildingDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let texture: String
    let cost: Int
    let maxLevel: Int
    let footprint: [Int]
    let description: String
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
