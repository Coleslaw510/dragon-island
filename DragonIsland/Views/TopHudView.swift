import SwiftUI

/// Minimal resource bar.  Breeding, hatching and the dragon book open calm
/// sheets; Battle opens the full-screen arena.
struct TopHudView: View {
    @ObservedObject var store: GameStateStore
    @State private var sheet: HudSheet?
    @State private var showsBattle = false

    var body: some View {
        HStack(spacing: 8) {
            ResourceChip(icon: "icon_gold_coin", label: "Gold", value: store.state.resources.gold)
            ResourceChip(icon: "icon_food_berries", label: "Food", value: store.state.resources.food)
            ResourceChip(icon: "icon_gem", label: "Gems", value: store.state.resources.gems)
            ResourceChip(icon: "icon_xp_star", label: "Experience", value: store.state.resources.xp)

            Spacer(minLength: 12)

            actionButton(.breed)
            actionButton(.hatch)
            actionButton(.battle)
            actionButton(.codex)

            Button {
                sheet = .settings
            } label: {
                Image("icon_settings_gear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(HudButtonStyle())
            .accessibilityLabel(Text("Settings"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .sheet(item: $sheet) { item in
            switch item {
            case .breeding:
                BreedingDenView(store: store)
            case .hatchery:
                HatcheryView(store: store)
            case .codex:
                DragonBookView(store: store)
            case .settings:
                SettingsView(store: store)
            }
        }
        .fullScreenCover(isPresented: $showsBattle) {
            BattleView(store: store)
        }
    }

    private func actionButton(_ action: HudAction) -> some View {
        let enabled = action.isEnabled(hasDragons: !store.state.ownedDragons.isEmpty)
        return Button {
            if action == .battle {
                showsBattle = true
            } else {
                sheet = action.sheet
            }
        } label: {
            Image(action.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
        .buttonStyle(HudButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel(Text(action.accessibility))
    }
}

private struct ResourceChip: View {
    let icon: String
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 19, height: 19)
            Text(value.formatted())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.30), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label): \(value)"))
    }
}

private struct HudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private enum HudSheet: String, Identifiable {
    case breeding, hatchery, codex, settings

    var id: String { rawValue }
}

private enum HudAction: String, CaseIterable, Identifiable, Equatable {
    case breed, hatch, battle, codex

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breed: return "icon_breed"
        case .hatch: return "icon_hatch"
        case .battle: return "icon_battle"
        case .codex: return "icon_dragon_book"
        }
    }

    var title: String {
        switch self {
        case .breed: return "Breed"
        case .hatch: return "Hatch"
        case .battle: return "Battle"
        case .codex: return "Dragon book"
        }
    }

    var sheet: HudSheet? {
        switch self {
        case .breed: return .breeding
        case .hatch: return .hatchery
        case .codex: return .codex
        case .battle: return nil
        }
    }

    func isEnabled(hasDragons: Bool) -> Bool {
        if case .battle = self { return hasDragons }
        return true
    }

    var accessibility: String { title }
}
