import SwiftUI

/// Dragon Book: every catalog dragon, owned or unseen, plus feeding controls
/// for the dragons currently on the island.
struct DragonBookView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss

    @State private var notice: String?

    private var definitions: [DragonDefinition] { store.catalog.dragons }
    private var owned: [OwnedDragon] {
        store.state.ownedDragons.sorted { $0.level > $1.level }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    roster
                    collection
                    if let notice {
                        Text(notice)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Dragon Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            Image("icon_dragon_book")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
            Text("\(ownedDefinitions) of \(definitions.count) dragons discovered")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private var roster: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Your dragons")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            ForEach(owned) { dragon in
                rosterRow(dragon)
            }
        }
    }

    private func rosterRow(_ dragon: OwnedDragon) -> some View {
        let definition = store.catalog.dragon(dragon.definitionID)
        let element = definition?.element ?? .fire
        let config = store.rules.leveling
        let needed = BreedingEngine.experienceNeeded(for: dragon.level, config: config)
        let canFeed = dragon.level < config.maxLevel && store.state.resources.food >= config.foodPerFeed
        return HStack(spacing: 10) {
            Image(badge(for: element))
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(dragon.nickname)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(progressText(dragon, config: config, needed: needed))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            Button("Feed \(config.foodPerFeed)") { feed(dragon) }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!canFeed)
        }
        .foregroundStyle(.white)
        .padding(9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Collection")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                      alignment: .leading, spacing: 10) {
                ForEach(definitions) { definition in
                    definitionCard(definition)
                }
            }
        }
    }

    private func definitionCard(_ definition: DragonDefinition) -> some View {
        let dragons = store.state.ownedDragons.filter { $0.definitionID == definition.id }
        let bestLevel = dragons.map(\.level).max()
        return HStack(spacing: 9) {
            Image(badge(for: definition.element))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .opacity(dragons.isEmpty ? 0.35 : 1)
            VStack(alignment: .leading, spacing: 1) {
                Text(dragons.isEmpty ? "???" : definition.displayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(statusText(count: dragons.count, bestLevel: bestLevel))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(9)
        .background(.white.opacity(dragons.isEmpty ? 0.03 : 0.08),
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(dragons.isEmpty ? 0.05 : 0.12), lineWidth: 1)
        )
        .opacity(dragons.isEmpty ? 0.6 : 1)
    }

    private var ownedDefinitions: Int {
        Set(store.state.ownedDragons.map(\.definitionID)).count
    }

    private func statusText(count: Int, bestLevel: Int?) -> String {
        guard count > 0, let bestLevel else { return "Unseen" }
        let suffix = count > 1 ? " · \(count) owned" : ""
        return "Lv \(bestLevel)\(suffix)"
    }

    private func progressText(_ dragon: OwnedDragon, config: LevelingConfig, needed: Int) -> String {
        if dragon.level >= config.maxLevel {
            return "Lv \(dragon.level) · Max"
        }
        return "Lv \(dragon.level) · XP \(dragon.experience)/\(needed)"
    }

    private func badge(for element: ElementType) -> String {
        store.catalog.element(element)?.badgeTexture ?? "badge_\(element.rawValue)"
    }

    private func feed(_ dragon: OwnedDragon) {
        if let outcome = store.feedDragon(id: dragon.id) {
            notice = outcome.leveledUp
                ? "\(outcome.name) reached level \(outcome.level)."
                : "\(outcome.name) gained experience."
        } else {
            notice = "Not enough food, or this dragon is already at max level."
        }
    }
}
