import SwiftUI

@main
struct DragonIslandApp: App {
    @StateObject private var store: GameStateStore

    init() {
        let catalog: GameCatalog
        do {
            catalog = try CatalogLoader.loadCatalog()
        } catch {
            print("[DragonIsland] catalog load failed: \(error)")
            catalog = .empty
        }
        _store = StateObject(wrappedValue: GameStateStore(catalog: catalog))
    }

    var body: some Scene {
        WindowGroup {
            IslandHostView(store: store)
                .preferredColorScheme(.dark)
        }
    }
}
