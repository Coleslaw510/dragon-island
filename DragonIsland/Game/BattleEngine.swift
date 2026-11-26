import Foundation

/// Pure battle maths.  No state mutation and no persistence live here.
enum BattleEngine {
    // MARK: - Fighters

    static func makeFighter(dragon: OwnedDragon, definition: DragonDefinition,
                            rules: BattleRules, isPlayer: Bool) -> BattleFighter {
        makeFighter(ownedID: dragon.id, name: dragon.nickname, definition: definition,
                    level: dragon.level, rules: rules, isPlayer: isPlayer)
    }

    static func makeFighter(ownedID: UUID?, name: String, definition: DragonDefinition,
                            level: Int, rules: BattleRules, isPlayer: Bool) -> BattleFighter {
        let scaling = rules.levelScaling
        let maxHealth = scaling.scaled(definition.baseHealth,
                                       perLevel: scaling.healthPerLevel, level: level)
        let cooldowns = Dictionary(uniqueKeysWithValues: rules.moves.map { ($0.id, 0) })
        return BattleFighter(
            id: UUID(),
            ownedDragonID: ownedID,
            definitionID: definition.id,
            name: name,
            element: definition.element,
            level: level,
            maxHealth: maxHealth,
            health: maxHealth,
            attack: scaling.scaled(definition.baseAttack,
                                   perLevel: scaling.attackPerLevel, level: level),
            defense: scaling.scaled(definition.baseDefense,
                                    perLevel: scaling.defensePerLevel, level: level),
            speed: scaling.scaled(definition.baseSpeed,
                                  perLevel: scaling.speedPerLevel, level: level),
            cooldowns: cooldowns,
            isPlayer: isPlayer
        )
    }

    /// Deterministic opponent roster.  Dragons the player fields are skipped
    /// while the catalog has enough others, so teams rarely mirror each other.
    static func makeEnemyTeam(catalog: GameCatalog, rules: BattleRules,
                              playerTeam: [BattleFighter]) -> [BattleFighter] {
        let size = rules.opponent.matchPlayerTeamSize
            ? min(rules.teamSize, max(1, playerTeam.count))
            : rules.teamSize
        guard size > 0, !catalog.dragons.isEmpty else { return [] }

        let averageLevel = playerTeam.isEmpty
            ? rules.opponent.minLevel
            : playerTeam.map(\.level).reduce(0, +) / playerTeam.count
        let level = max(rules.opponent.minLevel, averageLevel + rules.opponent.levelOffset)

        let playerDefinitions = Set(playerTeam.map(\.definitionID))
        var pool = catalog.dragons.filter { !playerDefinitions.contains($0.id) }
        if pool.count < size { pool = catalog.dragons }

        return pool.prefix(size).map { definition in
            makeFighter(ownedID: nil, name: definition.displayName, definition: definition,
                        level: level, rules: rules, isPlayer: false)
        }
    }

    // MARK: - Turn rules

    /// Fastest fighter acts first.  Ties go to the player, then roster order.
    static func turnOrder(_ fighters: [BattleFighter]) -> [UUID] {
        fighters.enumerated()
            .filter { $0.element.isAlive }
            .sorted { left, right in
                if left.element.speed != right.element.speed {
                    return left.element.speed > right.element.speed
                }
                if left.element.isPlayer != right.element.isPlayer {
                    return left.element.isPlayer
                }
                return left.offset < right.offset
            }
            .map { $0.element.id }
    }

    static func readyMove(for fighter: BattleFighter, rules: BattleRules) -> BattleMove? {
        let ready = rules.moves.filter { (fighter.cooldowns[$0.id] ?? 0) <= 0 }
        return ready.max { $0.power < $1.power } ?? rules.moves.first
    }

    static func tickCooldowns(_ fighter: inout BattleFighter) {
        fighter.cooldowns = fighter.cooldowns.mapValues { max(0, $0 - 1) }
    }

    // MARK: - Damage

    static func damage(attacker: BattleFighter, defender: BattleFighter,
                       move: BattleMove, rules: BattleRules) -> (amount: Int, multiplier: Double) {
        let multiplier = rules.elements.multiplier(
            attacker: attacker.element,
            defender: defender.element,
            damage: rules.damage
        )
        let raw = Double(attacker.attack) * move.power
            - Double(defender.defense) * rules.damage.defenseRatio
        let amount = max(rules.damage.minimumDamage, Int((raw * multiplier).rounded()))
        return (amount, multiplier)
    }
}
