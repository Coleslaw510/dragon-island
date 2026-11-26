import SwiftUI

@main
struct DragonIslandApp: App {
    @StateObject private var store: GameStateStore

    init() {
        let catalog: GameCatalog
        let rules: BreedingRules
        let battleRules: BattleRules
        do {
            catalog = try CatalogLoader.loadCatalog()
        } catch {
            print("[DragonIsland] catalog load failed: \(error)")
            catalog = .empty
        }
        do {
            rules = try CatalogLoader.loadBreedingRules()
        } catch {
            print("[DragonIsland] breeding rules load failed: \(error)")
            rules = .empty
        }
        do {
            battleRules = try CatalogLoader.loadBattleRules()
        } catch {
            print("[DragonIsland] battle rules load failed: \(error)")
            battleRules = .empty
        }
        _store = StateObject(wrappedValue: GameStateStore(catalog: catalog, rules: rules,
                                                          battleRules: battleRules))
    }

    var body: some Scene {
        WindowGroup {
            IslandHostView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}
