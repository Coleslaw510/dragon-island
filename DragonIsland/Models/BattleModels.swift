import Foundation

/// Root of `battle_rules.json`.  Team size, level scaling, element modifiers,
/// move cooldowns and rewards all come from that file.
struct BattleRules: Codable, Sendable {
    let schemaVersion: Int
    let teamSize: Int
    let levelScaling: BattleLevelScaling
    let damage: BattleDamageRules
    let elements: BattleElementRules
    let moves: [BattleMove]
    let opponent: BattleOpponentRules
    let rewards: BattleRewards

    static let empty = BattleRules(
        schemaVersion: 0,
        teamSize: 0,
        levelScaling: BattleLevelScaling(
            healthPerLevel: 0,
            attackPerLevel: 0,
            defensePerLevel: 0,
            speedPerLevel: 0
        ),
        damage: BattleDamageRules(
            defenseRatio: 0,
            minimumDamage: 1,
            criticalMultiplier: 1,
            weakMultiplier: 1
        ),
        elements: BattleElementRules(strongAgainst: [:]),
        moves: [],
        opponent: BattleOpponentRules(
            matchPlayerTeamSize: true,
            levelOffset: 0,
            minLevel: 1,
            encounters: nil
        ),
        rewards: BattleRewards(gold: 0, food: 0, xp: 0, dragonXP: 0)
    )
}

struct BattleLevelScaling: Codable, Sendable {
    let healthPerLevel: Double
    let attackPerLevel: Double
    let defensePerLevel: Double
    let speedPerLevel: Double

    func scaled(_ base: Int, perLevel: Double, level: Int) -> Int {
        let steps = Double(max(0, level - 1))
        return max(1, Int((Double(base) * (1 + perLevel * steps)).rounded()))
    }
}

struct BattleDamageRules: Codable, Sendable {
    let defenseRatio: Double
    let minimumDamage: Int
    let criticalMultiplier: Double
    let weakMultiplier: Double
}

/// `strongAgainst` is keyed by attacker raw value.  A defender listed there
/// takes the critical multiplier; attacking a defender that is strong against
/// you takes the weakness multiplier.
struct BattleElementRules: Codable, Sendable {
    let strongAgainst: [String: [ElementType]]

    func multiplier(attacker: ElementType, defender: ElementType,
                    damage: BattleDamageRules) -> Double {
        if strongAgainst[attacker.rawValue]?.contains(defender) == true {
            return damage.criticalMultiplier
        }
        if strongAgainst[defender.rawValue]?.contains(attacker) == true {
            return damage.weakMultiplier
        }
        return 1
    }
}

struct BattleMove: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let displayName: String
    let cooldownTurns: Int
    let power: Double
}

struct BattleEncounter: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let dragonIDs: [String]
}

struct BattleOpponentRules: Codable, Sendable {
    let matchPlayerTeamSize: Bool
    let levelOffset: Int
    let minLevel: Int
    let encounters: [BattleEncounter]?
}

struct BattleRewards: Codable, Sendable {
    let gold: Int
    let food: Int
    let xp: Int
    let dragonXP: Int
}

/// A dragon as it exists for one battle.  It is built from the catalog
/// definition plus the owned record's level, then never written back to disk.
struct BattleFighter: Identifiable, Sendable {
    let id: UUID
    let ownedDragonID: UUID?
    let definitionID: String
    let name: String
    let element: ElementType
    let level: Int
    let maxHealth: Int
    var health: Int
    let attack: Int
    let defense: Int
    let speed: Int
    var cooldowns: [String: Int]
    let isPlayer: Bool
    let spritePrefix: String?

    var isAlive: Bool { health > 0 }
    var healthFraction: Double {
        maxHealth > 0 ? Double(max(0, health)) / Double(maxHealth) : 0
    }
}

enum BattleOutcome: String, Equatable, Sendable {
    case victory, defeat, forfeit
}

enum BattlePhase: Equatable, Sendable {
    case idle, fighting, finished
}
