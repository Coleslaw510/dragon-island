import SpriteKit
import UIKit

/// Turns `sprite_manifest.json` entries into cached SpriteKit textures.
/// Every image in the catalog was exported by `tools/slice_assets.py`.
final class SpriteSheetLoader {
    static let shared = SpriteSheetLoader()

    private let manifest: SpriteManifest?
    private var cache: [String: SKTexture] = [:]

    init(bundle: Bundle = .main) {
        manifest = try? CatalogLoader.loadSpriteManifest(bundle: bundle)
    }

    // MARK: - Dragons

    func frames(forDragon id: String, state: DragonAnimationState) -> [SKTexture] {
        guard let animation = manifest?.dragons[id]?.animations[state.rawValue] else { return [] }
        return textures(named: animation.frames)
    }

    /// Row order matches the sheet: 0 idle, 1 walk, 2 fly, 3 action.
    func frames(forDragon id: String, row: Int) -> [SKTexture] {
        guard DragonAnimationState.allCases.indices.contains(row) else { return [] }
        return frames(forDragon: id, state: DragonAnimationState.allCases[row])
    }

    func action(forDragon id: String, state: DragonAnimationState) -> SKAction? {
        guard let animation = manifest?.dragons[id]?.animations[state.rawValue] else { return nil }
        let frames = textures(named: animation.frames)
        guard !frames.isEmpty else { return nil }
        let timePerFrame = max(0.03, 1.0 / max(animation.fps, 1.0))
        let animate = SKAction.animate(with: frames, timePerFrame: timePerFrame)
        return animation.loop ? .repeatForever(animate) : animate
    }

    func frameSize(forDragon id: String) -> CGSize {
        guard let size = manifest?.dragons[id]?.frameSize else { return CGSize(width: 180, height: 140) }
        return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }

    // MARK: - World and UI

    func frames(forGroup group: String) -> [SKTexture] {
        textures(named: manifest?.world[group]?.frames ?? [])
    }

    func groupAction(_ group: String) -> SKAction? {
        guard let animation = manifest?.world[group] else { return nil }
        let frames = textures(named: animation.frames)
        guard !frames.isEmpty else { return nil }
        let animate = SKAction.animate(with: frames, timePerFrame: max(0.03, 1.0 / max(animation.fps, 1.0)))
        return animation.loop ? .repeatForever(animate) : animate
    }

    func textureName(forHabitat element: ElementType) -> String? {
        manifest?.textures.habitats[element.rawValue]
    }

    func textureName(forEgg element: ElementType) -> String? {
        manifest?.textures.eggs[element.rawValue]
    }

    func textures(named names: [String]) -> [SKTexture] {
        names.compactMap(texture(named:))
    }

    func texture(named name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        let texture = SKTexture(imageNamed: name)
        guard texture.size().width > 1, texture.size().height > 1 else { return nil }
        texture.filteringMode = .linear
        cache[name] = texture
        return texture
    }

    /// Used when a development build is missing an asset, so the scene still
    /// shows a readable placeholder instead of an empty hole.
    func placeholderTexture(size: CGSize, color: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}
