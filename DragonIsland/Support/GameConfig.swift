import CoreGraphics

enum GameConfig {
    static let saveSchemaVersion = 1

    static let gridColumns = 7
    static let gridRows = 7
    static let tileWidth: CGFloat = 148
    static let tileHeight: CGFloat = 102

    static let islandWidth: CGFloat = 1420
    static let worldBounds = CGRect(x: -920, y: -760, width: 1840, height: 1520)

    static let minZoom: CGFloat = 0.45
    static let maxZoom: CGFloat = 2.6
    static let initialSelection = TileCoordinate(x: 3, y: 3)
}
