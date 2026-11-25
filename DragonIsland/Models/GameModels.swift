import Foundation

/// The ten elemental families shipped with the starter catalog.
enum ElementType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case fire, water, earth, air, lightning, plant, ice, light, metal, star

    var id: String { rawValue }
}

/// Rows present in every dragon sheet: idle, walk, fly, action.
enum DragonAnimationState: String, Codable, CaseIterable, Hashable, Sendable {
    case idle, walk, fly, action
}

struct DragonDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let element: ElementType
    let rarity: String
    let actionName: String
    let spritePrefix: String
    let baseHealth: Int
    let baseAttack: Int
    let baseDefense: Int
    let baseSpeed: Int
}

/// A dragon the player owns.  Definition data stays in JSON; this record only
/// holds mutable progress and placement.
struct OwnedDragon: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var definitionID: String
    var nickname: String
    var level: Int
    var experience: Int
    var energy: Int
    var assignedHabitatID: UUID?
    var tileX: Int
    var tileY: Int
    var hatchedAt: Date

    var tile: TileCoordinate { TileCoordinate(x: tileX, y: tileY) }
}

enum PlacementKind: String, Codable, CaseIterable, Hashable, Sendable {
    case habitat, building, farm
}

struct PlacedBuilding: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var definitionID: String
    var kind: PlacementKind
    var tileX: Int
    var tileY: Int
    var level: Int
    var element: ElementType?
    var placedAt: Date

    var tile: TileCoordinate { TileCoordinate(x: tileX, y: tileY) }
}

struct ResourceState: Codable, Hashable, Sendable {
    var gold: Int
    var food: Int
    var gems: Int
    var xp: Int

    static let starter = ResourceState(gold: 750, food: 400, gems: 25, xp: 0)

    enum Kind: String, Codable, CaseIterable, Sendable {
        case gold, food, gems, xp
    }

    func value(for kind: Kind) -> Int {
        switch kind {
        case .gold: return gold
        case .food: return food
        case .gems: return gems
        case .xp: return xp
        }
    }

    mutating func add(_ amount: Int, to kind: Kind) {
        switch kind {
        case .gold: gold += amount
        case .food: food += amount
        case .gems: gems += amount
        case .xp: xp += amount
        }
    }
}

struct TileCoordinate: Codable, Hashable, Sendable {
    var x: Int
    var y: Int
}

/// Everything that is written to disk.  `lastSeenAt` / `lastSavedAt` drive the
/// offline-progress hooks in `GameStateStore`.
struct IslandSaveState: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var playerName: String
    var islandLevel: Int
    var resources: ResourceState
    var ownedDragons: [OwnedDragon]
    var placedBuildings: [PlacedBuilding]
    var selectedDragonID: UUID?
    var lastSavedAt: Date
    var lastSeenAt: Date
    var lastCollectionAt: Date
    var unlockedElements: [ElementType]
    var didCompleteTutorial: Bool

    func habitat(for element: ElementType) -> PlacedBuilding? {
        placedBuildings.first { $0.kind == .habitat && $0.element == element }
    }
}
