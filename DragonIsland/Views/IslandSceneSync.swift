import SwiftUI

/// Keeps SpriteKit nodes in step with save changes without making the host
/// view body one huge expression.
struct IslandStateSync: ViewModifier {
    @ObservedObject var store: GameStateStore
    let scene: IslandScene
    let interaction: IslandInteractionModel

    func body(content: Content) -> some View {
        content
            .onChange(of: store.state.placedBuildings.count) { _, _ in
                scene.refreshPlacements()
            }
            .onChange(of: store.state.ownedDragons) { _, _ in
                scene.refreshPlacements()
            }
            .onChange(of: store.state.eggs) { _, _ in
                scene.refreshPlacements()
            }
            .onChange(of: store.state.breedingSessions) { _, _ in
                scene.refreshPlacements()
            }
            .onChange(of: store.state.unlockedGridColumns) { _, _ in
                scene.updateGrid(for: store.state)
            }
            .onChange(of: store.state.unlockedGridRows) { _, _ in
                scene.updateGrid(for: store.state)
            }
            .onChange(of: store.worldRevision) { _, _ in
                interaction.dismissSelection()
                interaction.cancelMove()
                scene.updateGrid(for: store.state)
                scene.refreshPlacements()
                scene.refreshInteractionVisuals()
            }
    }
}

/// Mirrors selection, placement and tutorial changes into the scene.
struct IslandInteractionSync: ViewModifier {
    @ObservedObject var store: GameStateStore
    @ObservedObject var interaction: IslandInteractionModel
    let scene: IslandScene
    @Binding var placementDragon: OwnedDragon?
    let showToast: (String) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: store.pendingPlacement) { _, _ in
                scene.refreshInteractionVisuals()
            }
            .onChange(of: store.tutorialTargetID) { _, _ in
                scene.refreshInteractionVisuals()
            }
            .onChange(of: interaction.selectedPlacementID) { _, _ in
                scene.refreshInteractionVisuals()
            }
            .onChange(of: interaction.movingPlacementID) { _, _ in
                scene.refreshInteractionVisuals()
            }
            .onChange(of: interaction.statusMessage) { _, message in
                if let message { showToast(message) }
            }
            .onChange(of: interaction.hatchedDragon) { _, dragon in
                guard let dragon else { return }
                placementDragon = dragon
                interaction.clearHatchedDragon()
            }
    }
}
