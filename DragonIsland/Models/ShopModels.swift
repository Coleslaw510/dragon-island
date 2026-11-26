import Foundation

/// Transient shop placement mode.  It lives outside the save file, so a
/// relaunch always cancels a half-finished placement.
struct PendingPlacement: Equatable, Identifiable {
    let id: UUID
    let kind: PlacementKind
    let definitionID: String
    let displayName: String

    init(kind: PlacementKind, definitionID: String, displayName: String) {
        self.id = UUID()
        self.kind = kind
        self.definitionID = definitionID
        self.displayName = displayName
    }
}

/// One card in the shop.  Habitats, farms and buildings start placement mode;
/// eggs are bought straight into a hatchery slot.
struct ShopItem: Identifiable, Equatable {
    enum Action: Equatable {
        case placement(PlacementKind)
        case egg(ShopEggDefinition)
    }

    let id: String
    let icon: String
    let name: String
    let detail: String
    let cost: Int
    let unlockLevel: Int
    let action: Action

    var isEgg: Bool {
        if case .egg = action { return true }
        return false
    }
}

enum ShopTab: String, CaseIterable, Identifiable {
    case habitats, farms, buildings, eggs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .habitats: return "Habitats"
        case .farms: return "Farms"
        case .buildings: return "Buildings"
        case .eggs: return "Eggs"
        }
    }
}

enum ShopPurchaseFailure: String, Error, Sendable {
    case locked
    case insufficientGold
    case noHatchery
    case noSlot
    case unknownEgg

    var message: String {
        switch self {
        case .locked: return "That item is still locked."
        case .insufficientGold: return "Not enough gold."
        case .noHatchery: return "No hatchery — place a hatchery first."
        case .noSlot: return "All hatchery slots are full."
        case .unknownEgg: return "That egg is unavailable."
        }
    }
}
