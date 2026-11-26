import Combine
import Foundation

/// Drives one battle: turn queue, AI pacing, log and reward payout.  The view
/// only reads published state and calls `playerAttack` or `forfeit`.
@MainActor
final class BattleSession: ObservableObject {
    @Published private(set) var phase: BattlePhase = .idle
    @Published private(set) var playerTeam: [BattleFighter] = []
    @Published private(set) var enemyTeam: [BattleFighter] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var attackingID: UUID?
    @Published private(set) var log: [String] = []
    @Published private(set) var outcome: BattleOutcome?
    @Published private(set) var isResolving = false

    let store: GameStateStore
    private var queue: [UUID] = []
    private var queueIndex = 0

    init(store: GameStateStore) {
        self.store = store
    }

    // MARK: - Read-only helpers

    var activeFighter: BattleFighter? {
        guard let activeID else { return nil }
        return fighter(activeID)
    }
    var isPlayerTurn: Bool { activeFighter?.isPlayer == true }
    var latestLog: String { log.last ?? "" }

    var cooldownHint: String? {
        guard let fighter = activeFighter,
              let move = store.battleRules.moves.max(by: { $0.power < $1.power }) else { return nil }
        let turns = fighter.cooldowns[move.id] ?? 0
        return turns > 0 ? "\(move.displayName) in \(turns)" : "\(move.displayName) ready"
    }

    func fighter(_ id: UUID) -> BattleFighter? {
        playerTeam.first { $0.id == id } ?? enemyTeam.first { $0.id == id }
    }

    // MARK: - Lifecycle

    func start(ownedIDs: [UUID]) {
        guard phase == .idle, !store.battleRules.moves.isEmpty else { return }
        let byID = Dictionary(uniqueKeysWithValues: store.state.ownedDragons.map { ($0.id, $0) })
        let roster = ownedIDs.prefix(max(1, store.battleRules.teamSize)).compactMap { id -> BattleFighter? in
            guard let dragon = byID[id], let definition = store.catalog.dragon(dragon.definitionID) else {
                return nil
            }
            return BattleEngine.makeFighter(dragon: dragon, definition: definition,
                                            rules: store.battleRules, isPlayer: true)
        }
        guard !roster.isEmpty else { return }

        playerTeam = roster
        let battleIndex = store.nextBattleIndex
        enemyTeam = BattleEngine.makeEnemyTeam(catalog: store.catalog,
                                               rules: store.battleRules,
                                               playerTeam: roster,
                                               battleIndex: battleIndex,
                                               availableIDs: store.availableDragonIDs)
        guard !enemyTeam.isEmpty else { return }
        store.recordBattleStarted()

        phase = .fighting
        log = ["A wild team blocks the arena."]
        queue = BattleEngine.turnOrder(roster + enemyTeam)
        queueIndex = 0
        beginTurn()
    }

    func playerAttack() {
        guard phase == .fighting, !isResolving,
              let id = activeID, let actor = fighter(id), actor.isPlayer, actor.isAlive else { return }
        isResolving = true
        perform(actorID: id)
    }

    func forfeit() {
        if phase == .fighting, enemyTeam.allSatisfy({ !$0.isAlive }) {
            finish(.victory)
        } else {
            finish(.forfeit)
        }
    }

    // MARK: - Turn flow

    private func beginTurn() {
        guard outcome == nil, phase == .fighting else { return }
        if checkOutcome() { return }
        if queueIndex >= queue.count {
            queue = BattleEngine.turnOrder(playerTeam + enemyTeam)
            queueIndex = 0
        }
        while queueIndex < queue.count, let unit = fighter(queue[queueIndex]), !unit.isAlive {
            queueIndex += 1
        }
        if queueIndex >= queue.count {
            queue = BattleEngine.turnOrder(playerTeam + enemyTeam)
            queueIndex = 0
        }
        guard queueIndex < queue.count else { return }

        let id = queue[queueIndex]
        activeID = id
        update(id) { fighter in BattleEngine.tickCooldowns(&fighter) }

        if fighter(id)?.isPlayer == true {
            isResolving = false
        } else {
            isResolving = true
            scheduleAI(id)
        }
    }

    private func scheduleAI(_ id: UUID) {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.7))
            guard let self, self.outcome == nil,
                  self.activeID == id, self.isResolving else { return }
            self.perform(actorID: id)
        }
    }

    private func perform(actorID: UUID) {
        guard outcome == nil,
              let actor = fighter(actorID), actor.isAlive,
              let target = frontEnemy(of: actor),
              let move = BattleEngine.readyMove(for: actor, rules: store.battleRules)
        else {
            advanceTurn()
            return
        }

        let result = BattleEngine.damage(attacker: actor, defender: target,
                                         move: move, rules: store.battleRules)
        attackingID = actorID
        update(target.id) { unit in unit.health = max(0, unit.health - result.amount) }
        update(actorID) { unit in unit.cooldowns[move.id] = move.cooldownTurns }
        store.playSound(.battleHit)

        appendLog("\(actor.name) used \(move.displayName) on \(target.name) for \(result.amount)."
                  + effectNote(result.multiplier))
        if (fighter(target.id)?.health ?? 0) == 0 {
            appendLog("\(target.name) fainted.")
        }

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.8))
            guard let self else { return }
            self.attackingID = nil
            self.advanceTurn()
        }
    }

    private func advanceTurn() {
        guard outcome == nil else { return }
        if checkOutcome() { return }
        queueIndex += 1
        beginTurn()
    }

    @discardableResult
    private func checkOutcome() -> Bool {
        if enemyTeam.allSatisfy({ !$0.isAlive }) {
            finish(.victory)
            return true
        }
        if playerTeam.allSatisfy({ !$0.isAlive }) {
            finish(.defeat)
            return true
        }
        return false
    }

    private func finish(_ requested: BattleOutcome) {
        guard outcome == nil else { return }
        // A close tap during the post-hit pause must not erase a win that is
        // already visible on the enemy side.
        let enemiesDefeated = !enemyTeam.isEmpty && enemyTeam.allSatisfy { !$0.isAlive }
        let result = enemiesDefeated ? .victory : requested
        outcome = result
        phase = .finished
        activeID = nil
        attackingID = nil
        isResolving = false
        switch result {
        case .victory:
            store.applyBattleRewards(participantIDs: playerTeam.compactMap(\.ownedDragonID))
            store.playSound(.victory)
            appendLog("Victory! The arena is yours.")
        case .defeat:
            appendLog("Your team needs rest.")
        case .forfeit:
            appendLog("You left the arena.")
        }
    }

    // MARK: - Small helpers

    private func frontEnemy(of actor: BattleFighter) -> BattleFighter? {
        let team = actor.isPlayer ? enemyTeam : playerTeam
        return team.first { $0.isAlive }
    }

    private func update(_ id: UUID, _ change: (inout BattleFighter) -> Void) {
        if let index = playerTeam.firstIndex(where: { $0.id == id }) {
            change(&playerTeam[index])
        } else if let index = enemyTeam.firstIndex(where: { $0.id == id }) {
            change(&enemyTeam[index])
        }
    }

    private func appendLog(_ line: String) {
        log.append(line)
        if log.count > 3 { log.removeFirst(log.count - 3) }
    }

    private func effectNote(_ multiplier: Double) -> String {
        if multiplier > 1 { return " Critical hit!" }
        if multiplier < 1 { return " Weak hit." }
        return ""
    }
}
