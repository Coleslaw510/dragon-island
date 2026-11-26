import CoreGraphics

/// Isometric plot.  Tile (0,0) is the top corner; x grows down-right and
/// y grows down-left, so larger (x + y) is closer to the viewer.  Grid size can
/// grow through island expansions while the original 7x7 coordinates keep
/// their exact screen position.
struct IslandGrid {
    let columns: Int
    let rows: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let anchorColumns: Int
    let anchorRows: Int

    init(columns: Int = GameConfig.gridColumns,
         rows: Int = GameConfig.gridRows,
         tileWidth: CGFloat = GameConfig.tileWidth,
         tileHeight: CGFloat = GameConfig.tileHeight,
         anchorColumns: Int = GameConfig.gridColumns,
         anchorRows: Int = GameConfig.gridRows) {
        self.columns = columns
        self.rows = rows
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.anchorColumns = anchorColumns
        self.anchorRows = anchorRows
    }

    static func forSave(_ state: IslandSaveState) -> IslandGrid {
        let columns = min(max(GameConfig.gridColumns, state.unlockedGridColumns ?? GameConfig.gridColumns),
                          GameConfig.maxGridColumns)
        let rows = min(max(GameConfig.gridRows, state.unlockedGridRows ?? GameConfig.gridRows),
                       GameConfig.maxGridRows)
        return IslandGrid(columns: columns, rows: rows)
    }

    var worldSize: CGSize {
        CGSize(width: CGFloat(columns) * tileWidth, height: CGFloat(rows) * tileHeight)
    }

    var center: CGPoint {
        let extraColumns = CGFloat(columns - anchorColumns) / 2
        let extraRows = CGFloat(rows - anchorRows) / 2
        return CGPoint(x: (extraColumns - extraRows) * tileWidth / 2,
                       y: -(extraColumns + extraRows) * tileHeight / 2)
    }

    /// Center of the original anchored plot, so expansion never drags the
    /// island artwork away from the buildings that were already there.
    var baseCenter: CGPoint {
        position(for: TileCoordinate(x: (anchorColumns - 1) / 2,
                                     y: (anchorRows - 1) / 2))
    }

    var allTiles: [TileCoordinate] {
        (0..<rows).flatMap { y in (0..<columns).map { TileCoordinate(x: $0, y: y) } }
    }

    func contains(_ tile: TileCoordinate) -> Bool {
        (0..<columns).contains(tile.x) && (0..<rows).contains(tile.y)
    }

    func position(for tile: TileCoordinate) -> CGPoint {
        let i = CGFloat(tile.x) - CGFloat(anchorColumns - 1) / 2
        let j = CGFloat(tile.y) - CGFloat(anchorRows - 1) / 2
        return CGPoint(x: (i - j) * tileWidth / 2, y: -(i + j) * tileHeight / 2)
    }

    func tile(at point: CGPoint) -> TileCoordinate? {
        let halfWidth = tileWidth / 2
        let halfHeight = tileHeight / 2
        let rawX = (point.x / halfWidth - point.y / halfHeight) / 2
            + CGFloat(anchorColumns - 1) / 2
        let rawY = (-point.x / halfWidth - point.y / halfHeight) / 2
            + CGFloat(anchorRows - 1) / 2
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
