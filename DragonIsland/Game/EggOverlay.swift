import SpriteKit

/// Egg slots on a hatchery and the finished-breeding eggs waiting at a den.
/// All textures come from the existing asset catalog.
enum EggOverlay {
    static func attach(to node: SKSpriteNode, placed: PlacedBuilding,
                       state: IslandSaveState, rules: BreedingRules,
                       grid: IslandGrid, loader: SpriteSheetLoader, now: Date) {
        if let incubation = rules.incubationBuilding(placed.definitionID) {
            let eggs = (state.eggs ?? [])
                .filter { $0.hatcheryID == placed.id }
                .sorted { $0.laidAt < $1.laidAt }
            for (index, egg) in eggs.enumerated() {
                addEgg(element: egg.blueprint.element, index: index,
                       slots: max(incubation.slots, eggs.count), to: node, grid: grid, loader: loader)
            }
            if eggs.contains(where: { $0.isReady(now: now) }) {
                addBadge(to: node, grid: grid, loader: loader)
            }
        }

        guard rules.breedingBuilding(placed.definitionID) != nil else { return }
        let ready = (state.breedingSessions ?? []).filter {
            $0.buildingID == placed.id && $0.isReady(now: now)
        }
        guard let first = ready.first else { return }
        addEgg(element: first.egg.element, index: 0, slots: 1,
               to: node, grid: grid, loader: loader)
        addBadge(to: node, grid: grid, loader: loader)
    }

    private static func addEgg(element: ElementType, index: Int, slots: Int,
                               to node: SKSpriteNode, grid: IslandGrid,
                               loader: SpriteSheetLoader) {
        guard let name = loader.textureName(forEgg: element),
              let texture = loader.texture(named: name) else { return }
        let width = grid.tileWidth * 0.30
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: width,
                             height: width * texture.size().height / max(texture.size().width, 1))
        let spread = grid.tileWidth * 0.20
        let centred = CGFloat(index) - CGFloat(max(slots - 1, 0)) / 2
        let lift: CGFloat = index.isMultiple(of: 2) ? 0 : grid.tileHeight * 0.10
        sprite.position = CGPoint(x: centred * spread, y: node.size.height * 0.16 + lift)
        sprite.zPosition = 7
        sprite.name = "egg_\(element.rawValue)_\(index)"
        node.addChild(sprite)
    }

    private static func addBadge(to node: SKSpriteNode, grid: IslandGrid,
                                 loader: SpriteSheetLoader) {
        guard node.childNode(withName: "indicator_hatching_ready_badge") == nil,
              let texture = loader.texture(named: "indicator_hatching_ready_badge") else { return }
        let width = grid.tileWidth * 0.30
        let badge = SKSpriteNode(texture: texture)
        badge.size = CGSize(width: width,
                            height: width * texture.size().height / max(texture.size().width, 1))
        badge.position = CGPoint(x: 0, y: node.size.height * 0.82)
        badge.zPosition = 8
        badge.name = "indicator_hatching_ready_badge"
        badge.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 4, duration: 0.9),
            .moveBy(x: 0, y: -4, duration: 0.9),
        ])), withKey: "bob")
        node.addChild(badge)
    }
}
