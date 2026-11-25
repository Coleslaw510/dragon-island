import SpriteKit
import SwiftUI

/// Full-screen landscape game area with a floating HUD and one-shot control hint.
struct IslandHostView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene: IslandScene
    @State private var showsHint = true

    init(store: GameStateStore) {
        self.store = store
        _scene = State(initialValue: IslandScene(
            store: store,
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
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.endSession()
            }
        }
        .onChange(of: store.state.placedBuildings.count) { _, _ in
            scene.refreshPlacements()
        }
    }
}
