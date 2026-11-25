import SpriteKit

/// Builds the visible island contents from the save state.  The scene owns the
/// camera and input; this builder is purely about turning records into nodes.
enum IslandWorldBuilder {
    static func makeNode(state: IslandSaveState, catalog: GameCatalog,
                         grid: IslandGrid, loader: SpriteSheetLoader) -> SKNode {
        let root = SKNode()
        root.name = "placements"

        for placed in state.placedBuildings.sorted(by: drawOrder) {
            guard let name = textureName(for: placed, catalog: catalog),
                  let texture = loader.texture(named: name) else { continue }
            let node = makeBuildingNode(placed: placed, texture: texture, grid: grid)
            root.addChild(node)
        }

        for dragon in state.ownedDragons.sorted(by: { $0.tileX + $0.tileY < $1.tileX + $1.tileY }) {
            guard let definition = catalog.dragon(dragon.definitionID) else { continue }
            let frames = loader.frames(forDragon: definition.id, state: .idle)
            guard let first = frames.first else { continue }
            root.addChild(makeDragonNode(dragon: dragon, frames: frames, first: first, grid: grid))
        }
        return root
    }

    static func textureName(for placed: PlacedBuilding, catalog: GameCatalog) -> String? {
        switch placed.kind {
        case .habitat:
            return catalog.habitat(placed.definitionID)?.texture
        case .building:
            return catalog.building(placed.definitionID)?.texture
        case .farm:
            return "farm_ready_to_harvest"
        }
    }

    // MARK: - Nodes

    private static func makeBuildingNode(placed: PlacedBuilding, texture: SKTexture,
                                         grid: IslandGrid) -> SKNode {
        let width = grid.tileWidth * widthFactor(for: placed.kind)
        let height = width * texture.size().height / max(texture.size().width, 1)
        let node = SKSpriteNode(texture: texture)
        node.size = CGSize(width: width, height: height)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.10)
        node.position = grid.position(for: placed.tile)
        node.zPosition = depth(for: placed.tile)
        node.name = placed.id.uuidString
        node.addChild(shadow(width: width * 0.62, height: grid.tileHeight * 0.18,
                             y: -height * 0.08))
        return node
    }

    private static func makeDragonNode(dragon: OwnedDragon, frames: [SKTexture], first: SKTexture,
                                       grid: IslandGrid) -> SKNode {
        let width = grid.tileWidth * 0.68
        let height = width * first.size().height / max(first.size().width, 1)
        let node = SKSpriteNode(texture: first)
        node.size = CGSize(width: width, height: height)
        node.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        node.position = grid.position(for: dragon.tile)
        node.position.y += grid.tileHeight * 0.16
        node.zPosition = depth(for: dragon.tile) + 6
        node.name = dragon.id.uuidString

        // Sheets face right; mirror every second dragon so the island reads
        // naturally without hand-editing any art.
        if dragon.tileX % 2 == 1 {
            node.xScale = -1
        }
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

    private static func shadow(width: CGFloat, height: CGFloat, y: CGFloat) -> SKShapeNode {
        let shape = SKShapeNode(ellipseOf: CGSize(width: width, height: height))
        shape.fillColor = SKColor(white: 0, alpha: 0.16)
        shape.strokeColor = .clear
        shape.position = CGPoint(x: 0, y: y)
        shape.zPosition = -1
        return shape
    }

    private static func widthFactor(for kind: PlacementKind) -> CGFloat {
        switch kind {
        case .habitat: return 1.62
        case .building: return 1.18
        case .farm: return 1.02
        }
    }

    private static func depth(for tile: TileCoordinate) -> CGFloat {
        100 + CGFloat(tile.x + tile.y) * 12
    }

    private static func drawOrder(_ lhs: PlacedBuilding, _ rhs: PlacedBuilding) -> Bool {
        let left = lhs.tileX + lhs.tileY
        let right = rhs.tileX + rhs.tileY
        return left == right ? lhs.tileX < rhs.tileX : left < right
    }
}
