import SwiftUI

/// Minimal resource bar.  Future milestones can wire the round buttons to
/// breeding, hatching and battle screens; they are intentionally inert today.
struct TopHudView: View {
    @ObservedObject var store: GameStateStore

    var body: some View {
        HStack(spacing: 8) {
            ResourceChip(icon: "icon_gold_coin", label: "Gold", value: store.state.resources.gold)
            ResourceChip(icon: "icon_food_berries", label: "Food", value: store.state.resources.food)
            ResourceChip(icon: "icon_gem", label: "Gems", value: store.state.resources.gems)
            ResourceChip(icon: "icon_xp_star", label: "Experience", value: store.state.resources.xp)

            Spacer(minLength: 12)

            ForEach(HudAction.allCases) { action in
                Button(action: {}) {
                    Image(action.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(HudButtonStyle())
                .disabled(true)
                .accessibilityLabel(Text("\(action.title). Coming in a later milestone."))
            }

            Button(action: store.save) {
                Image("icon_settings_gear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(HudButtonStyle())
            .accessibilityLabel(Text("Save game"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
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

private enum HudAction: String, CaseIterable, Identifiable {
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
}
