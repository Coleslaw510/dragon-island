import SpriteKit

/// Glowing plot overlays used during shop placement, moving and the tutorial.
/// Kept out of `IslandScene` so the scene stays small.
enum PlacementHighlights {
    static func validTiles(state: IslandSaveState) -> [TileCoordinate] {
        let grid = IslandGrid.forSave(state)
        return grid.allTiles.filter { IslandEconomy.placement(at: $0, state: state) == nil }
    }

    static func make(grid: IslandGrid, tiles: [TileCoordinate]) -> SKNode {
        let root = SKNode()
        root.name = "placement_highlights"
        root.zPosition = 5500
        for tile in tiles {
            let shape = SKShapeNode(path: grid.diamondPath(width: grid.tileWidth * 0.86,
                                                           height: grid.tileHeight * 0.86))
            shape.position = grid.position(for: tile)
            shape.fillColor = SKColor(red: 0.40, green: 0.95, blue: 1.0, alpha: 0.18)
            shape.strokeColor = SKColor(red: 0.55, green: 0.97, blue: 1.0, alpha: 0.92)
            shape.lineWidth = 2
            shape.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 0.85),
                .fadeAlpha(to: 1.0, duration: 0.85),
            ])))
            root.addChild(shape)
        }
        return root
    }

    /// A soft gold ring around the item the tutorial asks for.
    static func makeTutorialGlow(grid: IslandGrid, placements: [PlacedBuilding]) -> SKNode {
        let root = SKNode()
        root.name = "tutorial_glow"
        root.zPosition = 5900
        for placed in placements {
            let ring = SKShapeNode(ellipseOf: CGSize(width: grid.tileWidth * 1.30,
                                                     height: grid.tileHeight * 1.70))
            ring.position = grid.position(for: placed.tile)
            ring.strokeColor = SKColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 0.95)
            ring.fillColor = .clear
            ring.lineWidth = 3
            ring.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.35, duration: 0.7), .scale(to: 0.94, duration: 0.7)]),
                .group([.fadeAlpha(to: 1.0, duration: 0.7), .scale(to: 1.04, duration: 0.7)]),
            ])))
            root.addChild(ring)
        }
        return root
    }
}
