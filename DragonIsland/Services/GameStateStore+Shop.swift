import Foundation

/// Shop purchases and the island placement flow that follows a purchase.
/// Costs and hatch times come from `starter_catalog.json`.
extension GameStateStore {
    // MARK: - Placement hand-off

    func beginPlacement(kind: PlacementKind, definitionID: String, displayName: String) {
        pendingPlacement = PendingPlacement(kind: kind,
                                            definitionID: definitionID,
                                            displayName: displayName)
    }

    func cancelPendingPlacement() {
        pendingPlacement = nil
    }

    /// Charges and places the pending item.  Returns the failure so the caller
    /// can show a message; the pending item stays active until it succeeds.
    func placePending(at tile: TileCoordinate) -> PlacementFailure? {
        guard let pending = pendingPlacement else { return nil }
        switch buildPlacement(kind: pending.kind, definitionID: pending.definitionID, tile: tile) {
        case .success:
            pendingPlacement = nil
            return nil
        case .failure(let failure):
            return failure
        }
    }

    // MARK: - Shop

    func requestShop() {
        shopOpenRequest += 1
    }

    func buyEgg(_ listing: ShopEggDefinition, now: Date = .now) -> Result<DragonEgg, ShopPurchaseFailure> {
        guard state.islandLevel >= listing.unlockLevel else { return .failure(.locked) }
        guard catalog.dragon(listing.dragonID) != nil else { return .failure(.unknownEgg) }
        guard state.resources.gold >= listing.cost else { return .failure(.insufficientGold) }
        guard let hatchery = hatcheryBuildings.first(where: {
            eggs(in: $0.id).count < eggCapacity(for: $0)
        }) else {
            return .failure(hatcheryBuildings.isEmpty ? .noHatchery : .noSlot)
        }

        state.resources.gold -= listing.cost
        let egg = DragonEgg(
            id: UUID(),
            hatcheryID: hatchery.id,
            blueprint: EggBlueprint(element: listing.element, dragonID: listing.dragonID),
            laidAt: now,
            readyAt: now.addingTimeInterval(TimeInterval(max(1, listing.hatchSeconds)))
        )
        state.eggs = eggs + [egg]
        if tutorialTargetMatches("egg_\(listing.element.rawValue)") {
            notifyTutorialEvent("buy_egg")
        }
        save()
        return .success(egg)
    }
}
