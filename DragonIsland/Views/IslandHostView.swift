import SpriteKit
import SwiftUI

/// Full-screen landscape game area with a floating HUD and one-shot control hint.
struct IslandHostView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var interaction: IslandInteractionModel
    @State private var scene: IslandScene
    @State private var showsHint = true

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
            SpriteView(
                scene: scene,
                isPaused: false,
                preferredFramesPerSecond: 60,
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea()

            TopHudView(store: store)

            if showsHint {
                VStack {
                    Spacer()
                    Text("Tap a tile to select  ·  Drag to pan  ·  Pinch to zoom")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.28), in: Capsule())
                }
                .padding(.bottom, 16)
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            BuildPanelView(store: store, interaction: interaction)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .background(Color.black)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.easeOut(duration: 0.8)) {
                showsHint = false
            }
        }
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
    }
}
