import SpriteKit
import UIKit

/// Static island art and overlay nodes that the scene places once.
enum IslandBackdrop {
    static func makeIsland(loader: SpriteSheetLoader, grid: IslandGrid) -> SKNode {
        let frames = loader.frames(forGroup: "starter_island")
        let island: SKSpriteNode
        let width = max(GameConfig.islandWidth, grid.worldSize.width + 180)
        if let first = frames.first {
            let ratio = first.size().height / max(first.size().width, 1)
            island = SKSpriteNode(texture: first)
            island.size = CGSize(width: width, height: width * ratio)
            if frames.count > 1 {
                island.run(.repeatForever(.animate(with: frames, timePerFrame: 0.3)), withKey: "island")
            }
        } else {
            island = SKSpriteNode(texture: loader.placeholderTexture(
                size: CGSize(width: 900, height: 760), color: .systemTeal))
            island.size = CGSize(width: width, height: width * 0.8)
        }
        island.position = grid.baseCenter
        island.zPosition = -100
        island.name = "starter_island"
        return island
    }

    static func makeGridMarkers(grid: IslandGrid) -> SKNode {
        let markers = SKNode()
        markers.name = "grid"
        markers.zPosition = -10
        for tile in grid.allTiles {
            let shape = SKShapeNode(path: grid.diamondPath(width: grid.tileWidth * 0.92,
                                                           height: grid.tileHeight * 0.92))
            shape.position = grid.position(for: tile)
            shape.strokeColor = SKColor(white: 1, alpha: 0.10)
            shape.fillColor = SKColor(white: 1, alpha: 0.03)
            shape.lineWidth = 1
            markers.addChild(shape)
        }
        return markers
    }

    static func makeSelectionNode(loader: SpriteSheetLoader, grid: IslandGrid) -> SKNode {
        let node: SKNode
        if let texture = loader.texture(named: "indicator_tile_selection_frame") {
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: grid.tileWidth * 1.15, height: grid.tileHeight * 1.45)
            node = sprite
        } else {
            let shape = SKShapeNode(path: grid.diamondPath())
            shape.strokeColor = SKColor(white: 1, alpha: 0.95)
            shape.fillColor = SKColor(white: 1, alpha: 0.08)
            shape.lineWidth = 3
            node = shape
        }
        node.zPosition = 6000
        node.alpha = 0
        return node
    }
}
