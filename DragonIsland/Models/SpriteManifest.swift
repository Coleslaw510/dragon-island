import Foundation

/// Decoded form of `sprite_manifest.json`, written by `tools/slice_assets.py`.
/// It maps dragon ids and world groups to frame names inside Assets.xcassets.
struct SpriteManifest: Codable, Sendable {
    struct FrameSize: Codable, Sendable {
        let width: Int
        let height: Int
    }

    struct Animation: Codable, Sendable {
        let frames: [String]
        let fps: Double
        let loop: Bool
    }

    struct DragonSprite: Codable, Sendable {
        let element: ElementType
        let frameSize: FrameSize
        let animations: [String: Animation]
    }

    struct TextureGroups: Codable, Sendable {
        let habitats: [String: String]
        let eggs: [String: String]
        let buildings: [String: String]
        let farmStages: [String]
        let indicators: [String]
    }

    struct UserInterface: Codable, Sendable {
        let icons: [String]
        let badges: [String]
    }

    let schemaVersion: Int
    let dragons: [String: DragonSprite]
    let world: [String: Animation]
    let textures: TextureGroups
    let ui: UserInterface
}
