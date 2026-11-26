import SwiftUI

@main
struct DragonIslandApp: App {
    @StateObject private var store: GameStateStore

    init() {
        let catalog: GameCatalog
        let rules: BreedingRules
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
        _store = StateObject(wrappedValue: GameStateStore(catalog: catalog, rules: rules))
    }

    var body: some Scene {
        WindowGroup {
            IslandHostView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}
