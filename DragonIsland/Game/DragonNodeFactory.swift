import SpriteKit

/// Draws one owned dragon from its idle frames.  Growth stage scale and tint
/// come from `breeding_rules.json`, so Baby / Juvenile / Adult need no extra
/// sprite sheets.
enum DragonNodeFactory {
    static func makeNode(dragon: OwnedDragon, frames: [SKTexture], first: SKTexture,
                         grid: IslandGrid, rules: BreedingRules) -> SKNode {
        let width = grid.tileWidth * 0.68
        let height = width * first.size().height / max(first.size().width, 1)
        let node = SKSpriteNode(texture: first)
        node.size = CGSize(width: width, height: height)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        node.position = grid.position(for: dragon.tile)
        node.position.y += grid.tileHeight * 0.16
        node.zPosition = depth(for: dragon.tile) + 6
        node.name = dragon.id.uuidString

        applyGrowth(dragon: dragon, to: node, rules: rules)

        if frames.count > 1 {
            let animate = SKAction.animate(with: frames, timePerFrame: 0.18)
            node.run(.repeatForever(animate), withKey: "idle")
        }
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 3, duration: 1.1),
            .moveBy(x: 0, y: -3, duration: 1.1),
        ])
        node.run(.repeatForever(bob), withKey: "bob")
        return node
    }

    private static func applyGrowth(dragon: OwnedDragon, to node: SKSpriteNode,
                                    rules: BreedingRules) {
        let stage = BreedingEngine.growthStage(for: dragon.level, config: rules.growth)
        let scale = CGFloat(stage?.scale ?? 1)

        // Sheets face right; mirror every second dragon so the island reads
        // naturally without hand-editing any art.
        let mirrored = dragon.tileX % 2 == 1
        node.xScale = mirrored ? -scale : scale
        node.yScale = scale

        if let hex = stage?.tintHex, let color = SKColor(hexString: hex) {
            node.color = color
            node.colorBlendFactor = CGFloat(min(max(stage?.tintStrength ?? 0.15, 0), 1))
        }
    }

    private static func depth(for tile: TileCoordinate) -> CGFloat {
        100 + CGFloat(tile.x + tile.y) * 12
    }
}
