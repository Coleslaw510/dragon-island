import SwiftUI

/// Habitat and structure menus.  Locked entries stay visible but greyed and
/// state the island level they need.
struct BuildMenuRow: View {
    @ObservedObject var store: GameStateStore
    @ObservedObject var interaction: IslandInteractionModel

    var body: some View {
        HStack(spacing: 7) {
            Menu {
                ForEach(store.catalog.habitats) { habitat in
                    habitatItem(habitat)
                }
            } label: {
                label("Build habitat")
            }

            Menu {
                ForEach(store.catalog.buildings) { building in
                    buildingItem(building)
                }
            } label: {
                label("Build structure")
            }
        }
    }

    private func habitatItem(_ habitat: HabitatDefinition) -> some View {
        let unlocked = store.state.islandLevel >= habitat.unlockLevel
        let kind: PlacementKind = .habitat
        return Button(itemTitle(habitat.displayName, cost: habitat.buildCost,
                                unlockLevel: habitat.unlockLevel, unlocked: unlocked)) {
            interaction.build(kind: kind, definitionID: habitat.id)
        }
        .disabled(!unlocked || !interaction.canBuild(kind: kind, definitionID: habitat.id))
    }

    private func buildingItem(_ building: BuildingDefinition) -> some View {
        let unlocked = store.state.islandLevel >= building.requiredLevel
        let kind: PlacementKind = building.isFarm ? .farm : .building
        return Button(itemTitle(building.displayName, cost: building.cost,
                                unlockLevel: building.requiredLevel, unlocked: unlocked)) {
            interaction.build(kind: kind, definitionID: building.id)
        }
        .disabled(!unlocked || !interaction.canBuild(kind: kind, definitionID: building.id))
    }

    private func itemTitle(_ name: String, cost: Int, unlockLevel: Int, unlocked: Bool) -> String {
        unlocked ? "\(name)  ·  \(cost) gold" : "\(name)  ·  unlocks at level \(unlockLevel)"
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.16), in: Capsule())
    }
}
