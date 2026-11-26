import Foundation

extension GameStateStore {
    /// Pays a won battle from `battle_rules.json` and levels each dragon that
    /// took part using the shared experience table.
    func applyBattleRewards(participantIDs: [UUID]) {
        let rewards = battleRules.rewards
        state.resources.gold += rewards.gold
        state.resources.food += rewards.food
        state.resources.xp += rewards.xp

        let participants = Set(participantIDs)
        for index in state.ownedDragons.indices
        where participants.contains(state.ownedDragons[index].id) {
            grantBattleExperience(rewards.dragonXP, to: index)
        }
        recordBattleVictory()
        syncIslandLevel()
        save()
    }

    private func grantBattleExperience(_ amount: Int, to index: Int) {
        let config = rules.leveling
        guard amount > 0, config.maxLevel > 0 else { return }

        var level = max(1, state.ownedDragons[index].level)
        guard level < config.maxLevel else { return }

        var experience = state.ownedDragons[index].experience + amount
        while level < config.maxLevel {
            let needed = BreedingEngine.experienceNeeded(for: level, config: config)
            guard experience >= needed else { break }
            experience -= needed
            level += 1
        }
        if level >= config.maxLevel { experience = 0 }
        state.ownedDragons[index].level = level
        state.ownedDragons[index].experience = experience
    }
}
