import SpriteKit
import SwiftUI

/// Full-screen landscape game area: the island, the HUD, the shop button, the
/// placement banner and the tutorial line.  No builder panel is always open.
struct IslandHostView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var interaction: IslandInteractionModel
    @State private var scene: IslandScene
    @State private var showsShop = false
    @State private var toast: String?
    @State private var placementDragon: OwnedDragon?

    init(store: GameStateStore) {
        self.store = store
        let model = IslandInteractionModel(store: store)
        _interaction = StateObject(wrappedValue: model)
        _scene = State(initialValue: IslandScene(
            store: store,
            interaction: model,
            size: CGSize(width: 1194, height: 834)
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene, isPaused: false,
                       preferredFramesPerSecond: 60,
                       options: [.ignoresSiblingOrder])
                .ignoresSafeArea()

            VStack(spacing: 6) {
                TutorialBanner(store: store)
                TopHudView(store: store, onNotice: showToast)
                placementBanner
                Spacer()
            }

            SelectionInfoPanel(store: store, interaction: interaction)
            shopButton
            if let toast { toastView(toast) }
        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            while !Task.isCancelled {
                store.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.beginSession()
                scene.refreshPlacements()
            } else {
                store.endSession()
            }
        }
        .onChange(of: store.state.placedBuildings.count) { _, _ in scene.refreshPlacements() }
        .onChange(of: store.state.ownedDragons) { _, _ in scene.refreshPlacements() }
        .onChange(of: store.state.eggs) { _, _ in scene.refreshPlacements() }
        .onChange(of: store.state.breedingSessions) { _, _ in scene.refreshPlacements() }
        .onChange(of: store.state.unlockedGridColumns) { _, _ in scene.updateGrid(for: store.state) }
        .onChange(of: store.state.unlockedGridRows) { _, _ in scene.updateGrid(for: store.state) }
        .onChange(of: store.worldRevision) { _, _ in
            interaction.dismissSelection()
            interaction.cancelMove()
            scene.updateGrid(for: store.state)
            scene.refreshPlacements()
            scene.refreshInteractionVisuals()
        }
        .onChange(of: store.pendingPlacement) { _, _ in scene.refreshInteractionVisuals() }
        .onChange(of: store.tutorialTargetID) { _, _ in scene.refreshInteractionVisuals() }
        .onChange(of: interaction.selectedPlacementID) { _, _ in scene.refreshInteractionVisuals() }
        .onChange(of: interaction.movingPlacementID) { _, _ in scene.refreshInteractionVisuals() }
        .onChange(of: interaction.statusMessage) { _, message in
            if let message { showToast(message) }
        }
        .onChange(of: interaction.hatchedDragon) { _, dragon in
            guard let dragon else { return }
            placementDragon = dragon
            interaction.clearHatchedDragon()
        }
        .onChange(of: store.shopOpenRequest) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { showsShop = true }
        }
        .onChange(of: store.state.didCompleteTutorial) { _, complete in
            if complete { showToast("You're set!") }
        }
        .fullScreenCover(isPresented: $showsShop) {
            ShopView(store: store)
        }
        .sheet(item: $placementDragon) { dragon in
            DragonPlacementSheet(store: store, dragon: dragon)
        }
    }

    @ViewBuilder
    private var placementBanner: some View {
        if let pending = store.pendingPlacement {
            PlacementBanner(text: "Place \(pending.displayName) — tap a glowing plot") {
                store.cancelPendingPlacement()
            }
        } else if interaction.isMoving, let id = interaction.movingPlacementID,
                  let placed = store.state.placedBuildings.first(where: { $0.id == id }) {
            PlacementBanner(text: "Move \(interaction.displayName(for: placed)) — tap a glowing plot") {
                interaction.cancelMove()
            }
        }
    }

    private var shopButton: some View {
        Button {
            showsShop = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text("Shop")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 13)
            .background(Color.orange.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .tutorialGlow(tutorialShopGlow)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private var tutorialShopGlow: Bool {
        guard let target = store.tutorialTargetID else { return false }
        if target == "shop" || target == "egg_fire" { return true }
        return !store.state.placedBuildings.contains { $0.definitionID == target }
    }

    private func toastView(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.62), in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 92)
            .allowsHitTesting(false)
            .transition(.opacity)
    }

    private func showToast(_ text: String) {
        toast = text
        let current = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toast == current { toast = nil }
        }
    }
}
