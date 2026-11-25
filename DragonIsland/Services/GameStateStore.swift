import Combine
import Foundation

struct OfflineReport: Equatable, Sendable {
    let secondsAway: TimeInterval
    let foodEarned: Int
}

/// Owns the save file and publishes the single source of truth for the game.
/// Saves are small JSON documents in Application Support, written atomically.
final class GameStateStore: ObservableObject {
    @Published private(set) var state: IslandSaveState
    @Published private(set) var lastOfflineReport: OfflineReport?

    let catalog: GameCatalog
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(catalog: GameCatalog, fileManager: FileManager = .default) {
        self.catalog = catalog
        self.fileManager = fileManager

        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let folder = base.appendingPathComponent("DragonIsland", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent("island_save.json")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        self.state = Self.loadOrCreate(at: fileURL, catalog: catalog, decoder: decoder, fileManager: fileManager)
        beginSession()
    }

    // MARK: - Session hooks

    /// Offline progress hook: food accrues while the app is closed.  The value is
    /// published for a future summary card; Milestone 1 shows no popup.
    func beginSession(now: Date = .now) {
        let away = now.timeIntervalSince(state.lastSeenAt)
        if away > 90 {
            let capped = min(away, 8 * 3600)
            let food = min(600, Int(capped / 60) * 2)
            if food > 0 {
                state.resources.food += food
                lastOfflineReport = OfflineReport(secondsAway: capped, foodEarned: food)
            }
        }
        state.lastSeenAt = now
        save()
    }

    func endSession(now: Date = .now) {
        state.lastSeenAt = now
        save()
    }

    // MARK: - Persistence

    func save() {
        state.lastSavedAt = .now
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[GameStateStore] save failed: \(error)")
        }
    }

    private static func loadOrCreate(at url: URL, catalog: GameCatalog,
                                     decoder: JSONDecoder, fileManager: FileManager) -> IslandSaveState {
        guard let data = try? Data(contentsOf: url) else {
            return SaveStateFactory.makeStarter(catalog: catalog)
        }
        if let decoded = try? decoder.decode(IslandSaveState.self, from: data),
           decoded.schemaVersion == GameConfig.saveSchemaVersion {
            return decoded
        }

        // Keep an unreadable save for debugging instead of deleting it silently.
        let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
        try? fileManager.removeItem(at: backup)
        try? fileManager.moveItem(at: url, to: backup)
        return SaveStateFactory.makeStarter(catalog: catalog)
    }

    // MARK: - Resources

    func add(_ amount: Int, to kind: ResourceState.Kind) {
        state.resources.add(amount, to: kind)
        save()
    }

    @discardableResult
    func spend(_ amount: Int, from kind: ResourceState.Kind) -> Bool {
        guard state.resources.value(for: kind) >= amount else { return false }
        state.resources.add(-amount, to: kind)
        save()
        return true
    }

    func selectDragon(_ id: UUID?) {
        state.selectedDragonID = id
        save()
    }
}
