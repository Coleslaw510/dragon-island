import Foundation

/// Achievement progress, JSON reward payout and unlockables.  Every goal and
/// reward comes from `achievements.json`; this file only applies it once.
extension GameStateStore {
    var achievementDefinitions: [AchievementDefinition] { achievements.achievements }
    var completedAchievementIDs: Set<String> { Set(state.completedAchievementIDs ?? []) }

    var dragonsHatched: Int { state.dragonsHatched ?? 0 }
    var breedingsCompleted: Int { state.breedingsCompleted ?? 0 }
    var battleWins: Int { state.battleWins ?? 0 }

    // MARK: - Queries

    func metricValue(_ metric: AchievementMetric) -> Int {
        switch metric {
        case .hatchedDragons: return dragonsHatched
        case .uniqueDragons: return Set(state.ownedDragons.map(\.definitionID)).count
        case .breedingsCompleted: return breedingsCompleted
        case .battleWins: return battleWins
        }
    }

    func achievementProgress(_ definition: AchievementDefinition) -> AchievementProgress {
        AchievementProgress(current: metricValue(definition.metric), goal: max(1, definition.goal))
    }

    func isAchievementComplete(_ id: String) -> Bool {
        completedAchievementIDs.contains(id)
    }

    func isDragonLocked(_ definition: DragonDefinition) -> Bool {
        guard let unlockID = definition.unlockAchievementID else { return false }
        return !isAchievementComplete(unlockID)
    }

    func isDragonAvailable(_ definition: DragonDefinition) -> Bool {
        !isDragonLocked(definition)
    }

    var availableDragonIDs: Set<String> {
        Set(catalog.dragons.filter { isDragonAvailable($0) }.map(\.id))
    }

    func achievementTitle(forDragon definition: DragonDefinition) -> String? {
        guard let unlockID = definition.unlockAchievementID else { return nil }
        return achievements.achievement(unlockID)?.title
    }

    func rewardSummary(_ rewards: AchievementRewards?) -> String {
        guard let rewards else { return "No extra reward" }
        var parts: [String] = []
        if let gold = rewards.gold, gold > 0 { parts.append("\(gold) gold") }
        if let food = rewards.food, food > 0 { parts.append("\(food) food") }
        if let gems = rewards.gems, gems > 0 { parts.append("\(gems) gems") }
        if let xp = rewards.xp, xp > 0 { parts.append("\(xp) XP") }
        if let dragonID = rewards.dragonID,
           let definition = catalog.dragon(dragonID) {
            parts.append(definition.displayName)
        }
        if let expansionID = rewards.expansionID,
           let expansion = achievements.expansion(expansionID) {
            parts.append(expansion.displayName)
        }
        return parts.isEmpty ? "No extra reward" : parts.joined(separator: " · ")
    }

    // MARK: - Counters

    func recordHatchedDragon() {
        state.dragonsHatched = dragonsHatched + 1
        evaluateAchievements()
    }

    func recordCompletedBreedings(_ count: Int) {
        guard count > 0 else { return }
        state.breedingsCompleted = breedingsCompleted + count
        evaluateAchievements()
    }

    func recordBattleVictory() {
        state.battleWins = battleWins + 1
        evaluateAchievements()
    }

    /// Advances the JSON encounter table so rematches see a new opposing team.
    func recordBattleStarted() -> Int {
        let index = state.battlesFought ?? 0
        state.battlesFought = index + 1
        save()
        return index
    }

    // MARK: - Evaluation

    @discardableResult
    func evaluateAchievements() -> [AchievementDefinition] {
        guard !achievements.achievements.isEmpty else { return [] }
        var completed = completedAchievementIDs
        var granted: [AchievementDefinition] = []
        var changed = true
        var passes = 0

        while changed && passes <= achievements.achievements.count {
            changed = false
            passes += 1
            for definition in achievements.achievements where !completed.contains(definition.id) {
                guard metricValue(definition.metric) >= definition.goal else { continue }
                completed.insert(definition.id)
                state.completedAchievementIDs = completed.sorted()
                apply(rewards: definition.rewards)
                granted.append(definition)
                changed = true
            }
        }
        if !granted.isEmpty { save() }
        return granted
    }

    // MARK: - Rewards

    private func apply(rewards: AchievementRewards?) {
        guard let rewards else { return }
        if let gold = rewards.gold { state.resources.gold += gold }
        if let food = rewards.food { state.resources.food += food }
        if let gems = rewards.gems { state.resources.gems += gems }
        if let xp = rewards.xp { state.resources.xp += xp }
        if let dragonID = rewards.dragonID { grantRewardDragon(dragonID) }
        if let expansionID = rewards.expansionID { grantExpansion(expansionID) }
    }

    private func grantRewardDragon(_ dragonID: String) {
        var granted = Set(state.grantedRewardDragonIDs ?? [])
        guard !granted.contains(dragonID), let definition = catalog.dragon(dragonID) else { return }
        granted.insert(dragonID)
        state.grantedRewardDragonIDs = granted.sorted()

        guard !state.ownedDragons.contains(where: { $0.definitionID == dragonID }) else { return }
        let anchor = state.placedBuildings.first { $0.kind == .habitat }?.tile
            ?? GameConfig.initialSelection
        let tile = IslandEconomy.freeTile(near: anchor, state: state)
        state.ownedDragons.append(
            OwnedDragon(
                id: UUID(),
                definitionID: definition.id,
                nickname: definition.displayName,
                level: max(1, rules.hatching.level),
                experience: 0,
                energy: rules.hatching.energy,
                assignedHabitatID: nil,
                tileX: tile.x,
                tileY: tile.y,
                hatchedAt: .now
            )
        )
        IslandEconomy.reconcileAssignments(&state, catalog: catalog, now: .now)
        syncIslandLevel()
    }

    private func grantExpansion(_ expansionID: String) {
        guard let expansion = achievements.expansion(expansionID) else { return }
        let columns = min(max(GameConfig.gridColumns, expansion.columns), GameConfig.maxGridColumns)
        let rows = min(max(GameConfig.gridRows, expansion.rows), GameConfig.maxGridRows)
        state.unlockedGridColumns = max(state.unlockedGridColumns ?? GameConfig.gridColumns, columns)
        state.unlockedGridRows = max(state.unlockedGridRows ?? GameConfig.gridRows, rows)
    }
}
