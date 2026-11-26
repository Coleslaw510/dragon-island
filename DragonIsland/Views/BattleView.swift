import SwiftUI

/// Full-screen battle flow: pick up to three owned dragons, then fight.
struct BattleView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: BattleSession
    @State private var selectedIDs: [UUID] = []

    init(store: GameStateStore) {
        self.store = store
        _session = StateObject(wrappedValue: BattleSession(store: store))
    }

    var body: some View {
        ZStack {
            Image("battle_arena_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            Color.black.opacity(0.45).ignoresSafeArea()

            if session.phase == .idle {
                selection
            } else {
                BattleArenaView(session: session) { dismiss() }
            }
        }
        .statusBarHidden(true)
    }

    private var teamSize: Int {
        let configured = store.battleRules.teamSize
        return max(1, configured > 0 ? configured : 3)
    }

    private var selection: some View {
        VStack(spacing: 12) {
            header
            if store.state.ownedDragons.isEmpty {
                emptyRoster
            } else {
                roster
            }
            footer
        }
        .padding(20)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Battle Arena")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Choose up to \(teamSize) dragons.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
            Button("Forfeit") { dismiss() }
                .buttonStyle(.bordered)
                .tint(.white)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }

    private var roster: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 190), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(store.state.ownedDragons) { dragon in
                    BattleRosterCard(
                        dragon: dragon,
                        element: element(for: dragon),
                        badgeTexture: badge(for: element(for: dragon)),
                        selected: selectedIDs.contains(dragon.id)
                    ) {
                        toggle(dragon.id)
                    }
                }
            }
        }
    }

    private var emptyRoster: some View {
        VStack(spacing: 10) {
            Image("icon_battle")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            Text("Hatch or breed a dragon to enter the arena.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("\(selectedIDs.count)/\(teamSize) chosen")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Button("Fight") {
                session.start(ownedIDs: selectedIDs)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.large)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .disabled(selectedIDs.isEmpty)
        }
    }

    private func toggle(_ id: UUID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else if selectedIDs.count < teamSize {
            selectedIDs.append(id)
        }
    }

    private func element(for dragon: OwnedDragon) -> ElementType {
        store.catalog.dragon(dragon.definitionID)?.element ?? .fire
    }

    private func badge(for element: ElementType) -> String {
        store.catalog.element(element)?.badgeTexture ?? "badge_\(element.rawValue)"
    }
}
