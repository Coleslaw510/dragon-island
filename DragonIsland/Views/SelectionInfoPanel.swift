import SwiftUI

/// Small panel for one placed habitat, farm or building.  It carries the
/// actions that used to live in the island builder: collect, feed, plant,
/// hatch, move and breed.
struct SelectionInfoPanel: View {
    @ObservedObject var store: GameStateStore
    @ObservedObject var interaction: IslandInteractionModel
    @State private var showsBreeding = false

    var body: some View {
        if store.pendingPlacement == nil, let placed = interaction.selectedPlacement {
            content(placed)
                .padding(12)
                .frame(width: 336, alignment: .leading)
                .background(.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .padding(.leading, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .sheet(isPresented: $showsBreeding) {
                    BreedingDenView(store: store)
                }
        }
    }

    private func content(_ placed: PlacedBuilding) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            header(placed)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    Text(PlacementStatusText.detail(for: placed, store: store, now: context.date))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                    actions(placed, now: context.date)
                }
            }
        }
    }

    private func header(_ placed: PlacedBuilding) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(interaction.displayName(for: placed))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Lv \(placed.level)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            Button {
                interaction.dismissSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close"))
        }
    }

    @ViewBuilder
    private func actions(_ placed: PlacedBuilding, now: Date) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                switch placed.kind {
                case .habitat:
                    chip("Collect", highlighted: false,
                         enabled: PlacementStatusText.canCollect(placed, store: store, now: now)) {
                        interaction.collectSelected()
                    }
                    chip("Feed", highlighted: store.tutorialTargetID == "feed",
                         enabled: interaction.canFeed(placed)) {
                        interaction.feedSelected()
                    }
                    moveChip(placed)
                case .farm:
                    if placed.plantedAt == nil {
                        chip("Plant", highlighted: false, enabled: interaction.canPlant(placed)) {
                            interaction.plantSelected()
                        }
                    }
                    chip("Collect", highlighted: false,
                         enabled: PlacementStatusText.canCollect(placed, store: store, now: now)) {
                        interaction.collectSelected()
                    }
                    moveChip(placed)
                case .building:
                    if PlacementStatusText.isHatchable(placed, store: store, now: now) {
                        chip("Hatch", highlighted: false, enabled: true) {
                            interaction.hatchSelected()
                        }
                    }
                    if store.rules.breedingBuilding(placed.definitionID) != nil {
                        chip("Breed", highlighted: false, enabled: true) {
                            showsBreeding = true
                        }
                    }
                    moveChip(placed)
                }
            }
        }
    }

    private func moveChip(_ placed: PlacedBuilding) -> some View {
        chip("Move", highlighted: false, enabled: true) {
            interaction.beginMoving()
        }
    }

    private func chip(_ title: String, highlighted: Bool, enabled: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(enabled ? 0.16 : 0.06), in: Capsule())
                .tutorialGlow(highlighted)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
