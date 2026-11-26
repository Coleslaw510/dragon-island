import Foundation

/// Pure rules that read `breeding_rules.json`.  No probabilities and no
/// balance numbers live in Swift.
enum BreedingEngine {
    static func growthStage(for level: Int, config: GrowthConfig) -> GrowthStageRule? {
        let ordered = config.stages.sorted { $0.minLevel < $1.minLevel }
        return ordered.last { level >= $0.minLevel } ?? ordered.first
    }

    static func experienceNeeded(for level: Int, config: LevelingConfig) -> Int {
        guard level >= 1 else { return 1 }
        guard config.xpTable.indices.contains(level - 1) else {
            return max(1, config.xpTable.last ?? 1)
        }
        return max(1, config.xpTable[level - 1])
    }

    static func feed(level: Int, experience: Int,
                     config: LevelingConfig) -> (level: Int, experience: Int) {
        guard config.foodPerFeed > 0, config.maxLevel > 0 else { return (level, experience) }
        var level = max(1, level)
        guard level < config.maxLevel else { return (level, 0) }

        var experience = experience + config.xpPerFeed
        while level < config.maxLevel {
            let needed = experienceNeeded(for: level, config: config)
            guard experience >= needed else { break }
            experience -= needed
            level += 1
        }
        if level >= config.maxLevel { experience = 0 }
        return (level, experience)
    }
}
