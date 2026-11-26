import Foundation

/// Stat a goal watches.  New goal types need a new case here and a matching
/// value in `GameStateStore.metricValue`.
enum AchievementMetric: String, Codable, CaseIterable, Hashable, Sendable {
    case hatchedDragons
    case uniqueDragons
    case breedingsCompleted
    case battleWins
}

struct AchievementRewards: Codable, Hashable, Sendable {
    let gold: Int?
    let food: Int?
    let gems: Int?
    let xp: Int?
    let dragonID: String?
    let expansionID: String?
}

struct AchievementDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let metric: AchievementMetric
    let goal: Int
    let rewards: AchievementRewards?
}

struct IslandExpansion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let columns: Int
    let rows: Int
}

/// Root of `achievements.json`.  Goals, rewards and island unlocks all live
/// there so Swift never owns an achievement list.
struct AchievementCatalog: Codable, Sendable {
    let schemaVersion: Int
    let achievements: [AchievementDefinition]
    let expansions: [IslandExpansion]

    static let empty = AchievementCatalog(schemaVersion: 0, achievements: [], expansions: [])

    func achievement(_ id: String) -> AchievementDefinition? {
        achievements.first { $0.id == id }
    }

    func expansion(_ id: String) -> IslandExpansion? {
        expansions.first { $0.id == id }
    }
}

struct AchievementProgress: Sendable {
    let current: Int
    let goal: Int

    var isComplete: Bool { current >= goal }
    var fraction: Double {
        guard goal > 0 else { return 1 }
        return min(1, Double(max(0, current)) / Double(goal))
    }
}
