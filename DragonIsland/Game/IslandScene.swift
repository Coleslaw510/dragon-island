import QuartzCore
import SpriteKit
import UIKit

/// Landscape island scene: animated starter island, isometric tile grid,
/// pan + pinch camera, one-tap tile selection and saved habitat/building nodes.
final class IslandScene: SKScene {
    private let store: GameStateStore
    private let interaction: IslandInteractionModel
    private let loader = SpriteSheetLoader.shared
    private let grid = IslandGrid()
    private let cameraNode = SKCameraNode()

    private var contentNode: SKNode?
    private var selectionNode: SKNode?
    private var pinchRecognizer: UIPinchGestureRecognizer?
    private var selectedTile = GameConfig.initialSelection
    private var lastPanPoint: CGPoint?
    private var touchStartedAt = CACurrentMediaTime()
    private var didPan = false
    private var userAdjustedCamera = false

    init(store: GameStateStore, interaction: IslandInteractionModel, size: CGSize) {
        self.store = store
        self.interaction = interaction
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.45, green: 0.72, blue: 0.86, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used; IslandScene is created in code.")
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        guard cameraNode.parent == nil else { return }
        view.isMultipleTouchEnabled = true
        addChild(cameraNode)
        camera = cameraNode
        cameraNode.position = grid.center
        cameraNode.setScale(fitScale())

        addChild(IslandBackdrop.makeIsland(loader: loader, grid: grid))
        addChild(IslandBackdrop.makeGridMarkers(grid: grid))
        refreshPlacements()
        selectionNode = IslandBackdrop.makeSelectionNode(loader: loader, grid: grid)
        if let selectionNode { addChild(selectionNode) }
        installGestures(in: view)

        interaction.onWorldChanged = { [weak self] in self?.refreshPlacements() }
        if let habitat = store.state.placedBuildings.first(where: { $0.kind == .habitat }) {
            selectedTile = habitat.tile
        }
        select(selectedTile, animated: false, notify: false)
        interaction.syncSelection(selectedTile)
        clampCamera()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard cameraNode.parent != nil else { return }
        if !userAdjustedCamera {
            cameraNode.setScale(fitScale())
            cameraNode.position = grid.center
        }
        clampCamera()
    }

    override func willMove(from view: SKView) {
        if let pinchRecognizer {
            view.removeGestureRecognizer(pinchRecognizer)
        }
        pinchRecognizer = nil
        super.willMove(from: view)
    }

    // MARK: - Content

    func refreshPlacements() {
        contentNode?.removeFromParent()
        let node = IslandWorldBuilder.makeNode(
            state: store.state,
            catalog: store.catalog,
            rules: store.rules,
            grid: grid,
            loader: loader
        )
        addChild(node)
        contentNode = node
    }

    private func select(_ tile: TileCoordinate, animated: Bool = true, notify: Bool = true) {
        guard grid.contains(tile) else { return }
        selectedTile = tile
        if notify { interaction.updateSelection(tile) }
        guard let selectionNode else { return }
        selectionNode.position = grid.position(for: tile)
        selectionNode.removeAllActions()
        selectionNode.alpha = 1
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.62, duration: 0.75),
            .fadeAlpha(to: 1.0, duration: 0.75),
        ])
        selectionNode.run(.repeatForever(pulse))
        if animated {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    // MARK: - Camera

    private func fitScale() -> CGFloat {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let fit = max((grid.worldSize.width + 300) / width,
                      (grid.worldSize.height + 300) / height)
        return min(max(fit, 0.9), 2.1)
    }

    private func clampCamera() {
        let scale = max(cameraNode.xScale, 0.01)
        let halfWidth = size.width * scale / 2
        let halfHeight = size.height * scale / 2
        let bounds = GameConfig.worldBounds

        let minX = bounds.minX + halfWidth
        let maxX = bounds.maxX - halfWidth
        cameraNode.position.x = minX <= maxX ? min(max(cameraNode.position.x, minX), maxX) : bounds.midX

        let minY = bounds.minY + halfHeight
        let maxY = bounds.maxY - halfHeight
        cameraNode.position.y = minY <= maxY ? min(max(cameraNode.position.y, minY), maxY) : bounds.midY
    }

    // MARK: - Gestures

    private func installGestures(in view: SKView) {
        guard pinchRecognizer == nil else { return }
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
        pinchRecognizer = pinch
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.state == .changed else { return }
        userAdjustedCamera = true
        let scale = recognizer.scale
        let newScale = cameraNode.xScale / max(scale, 0.01)
        cameraNode.setScale(min(max(newScale, GameConfig.minZoom), GameConfig.maxZoom))
        recognizer.scale = 1
        clampCamera()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastPanPoint = touch.location(in: view)
        touchStartedAt = CACurrentMediaTime()
        didPan = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1,
              pinchRecognizer?.state != .changed,
              let touch = touches.first,
              let previous = lastPanPoint,
              let view = self.view else { return }

        let point = touch.location(in: view)
        let dx = point.x - previous.x
        let dy = point.y - previous.y
        if abs(dx) + abs(dy) > 2 {
            didPan = true
            userAdjustedCamera = true
        }
        cameraNode.position.x -= dx * cameraNode.xScale
        cameraNode.position.y += dy * cameraNode.xScale
        lastPanPoint = point
        clampCamera()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanPoint = nil
        guard !didPan,
              touches.count == 1,
              CACurrentMediaTime() - touchStartedAt < 0.45,
              let touch = touches.first,
              let tile = grid.tile(at: touch.location(in: self)) else { return }
        select(tile)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastPanPoint = nil
    }
}
