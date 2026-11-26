import Foundation

enum CatalogLoader {
    enum LoadError: LocalizedError {
        case missingResource(String)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                return "Missing resource \(name).json in the app bundle."
            }
        }
    }

    static func loadCatalog(bundle: Bundle = .main) throws -> GameCatalog {
        try decode(GameCatalog.self, named: "starter_catalog", bundle: bundle)
    }

    static func loadSpriteManifest(bundle: Bundle = .main) throws -> SpriteManifest {
        try decode(SpriteManifest.self, named: "sprite_manifest", bundle: bundle)
    }

    static func loadBreedingRules(bundle: Bundle = .main) throws -> BreedingRules {
        try decode(BreedingRules.self, named: "breeding_rules", bundle: bundle)
    }

    private static func decode<T: Decodable>(_ type: T.Type, named name: String, bundle: Bundle) throws -> T {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "GameData")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else { throw LoadError.missingResource(name) }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
