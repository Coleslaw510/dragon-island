import CoreGraphics

/// Isometric 7x7 plot.  Tile (0,0) is the top corner; x grows down-right and
/// y grows down-left, so larger (x + y) is closer to the viewer.
struct IslandGrid {
    let columns: Int
    let rows: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    init(columns: Int = GameConfig.gridColumns,
         rows: Int = GameConfig.gridRows,
         tileWidth: CGFloat = GameConfig.tileWidth,
         tileHeight: CGFloat = GameConfig.tileHeight) {
        self.columns = columns
        self.rows = rows
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
    }

    var worldSize: CGSize {
        CGSize(width: CGFloat(columns) * tileWidth, height: CGFloat(rows) * tileHeight)
    }

    var center: CGPoint { .zero }

    var allTiles: [TileCoordinate] {
        (0..<rows).flatMap { y in (0..<columns).map { TileCoordinate(x: $0, y: y) } }
    }

    func contains(_ tile: TileCoordinate) -> Bool {
        (0..<columns).contains(tile.x) && (0..<rows).contains(tile.y)
    }

    func position(for tile: TileCoordinate) -> CGPoint {
        let i = CGFloat(tile.x) - CGFloat(columns - 1) / 2
        let j = CGFloat(tile.y) - CGFloat(rows - 1) / 2
        return CGPoint(x: (i - j) * tileWidth / 2, y: -(i + j) * tileHeight / 2)
    }

    func tile(at point: CGPoint) -> TileCoordinate? {
        let halfWidth = tileWidth / 2
        let halfHeight = tileHeight / 2
        let rawX = (point.x / halfWidth - point.y / halfHeight) / 2 + CGFloat(columns - 1) / 2
        let rawY = (-point.x / halfWidth - point.y / halfHeight) / 2 + CGFloat(rows - 1) / 2
        let tile = TileCoordinate(x: Int(rawX.rounded()), y: Int(rawY.rounded()))
        guard contains(tile) else { return nil }

        let center = position(for: tile)
        let inside = abs(point.x - center.x) / halfWidth + abs(point.y - center.y) / halfHeight <= 1.02
        return inside ? tile : nil
    }

    func diamondPath(width: CGFloat? = nil, height: CGFloat? = nil) -> CGPath {
        let width = width ?? tileWidth
        let height = height ?? tileHeight
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -height / 2))
        path.addLine(to: CGPoint(x: -width / 2, y: 0))
        path.closeSubpath()
        return path
    }
}
