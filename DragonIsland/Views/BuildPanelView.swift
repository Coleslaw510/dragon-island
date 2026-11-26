import SwiftUI

/// Compact bottom-left panel for building, moving and collecting.  Menus keep
/// the island readable instead of covering it with button rows.
struct BuildPanelView: View {
    @ObservedObject var store: GameStateStore
    @ObservedObject var interaction: IslandInteractionModel

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            header
            selectionStatus
            if interaction.isMoving {
                moveBanner
            } else {
                actionRow
                buildRow
            }
            if let message = interaction.statusMessage {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 354, alignment: .leading)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.12), lineWidth: 1))
        .padding(.leading, 18)
        .padding(.bottom, 16)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Island Builder")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text("Lv \(store.state.islandLevel) · Plot \(interaction.selectedTile.x),\(interaction.selectedTile.y)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    @ViewBuilder
    private var selectionStatus: some View {
        if let placed = interaction.selectedPlacement {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 2) {
                    Text(interaction.displayName(for: placed))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(PlacementStatusText.detail(for: placed, store: store, now: context.date))
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.74))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Empty plot")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("Pick a habitat or structure below.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
    }

    private var actionRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 7) {
                if let placed = interaction.selectedPlacement {
                    if placed.kind == .farm && placed.plantedAt == nil {
                        smallButton("Plant", enabled: interaction.canPlant(placed)) {
                            interaction.plantSelectedFarm()
                        }
                    }
                    if PlacementStatusText.isHatchable(placed, store: store, now: context.date) {
                        smallButton("Hatch", enabled: true) {
                            interaction.hatchSelected()
                        }
                    } else if PlacementStatusText.canCollect(placed, store: store, now: context.date) {
                        smallButton(collectTitle(for: placed), enabled: true) {
                            interaction.collectSelected()
                        }
                    }
                    smallButton("Move", enabled: true) {
                        interaction.startMoving()
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var buildRow: some View {
        if interaction.selectedPlacement == nil {
            BuildMenuRow(store: store, interaction: interaction)
        } else {
            Text("Move this piece, or tap an empty plot to build.")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private var moveBanner: some View {
        HStack(spacing: 8) {
            Text("Tap an empty plot to move this piece.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
            Spacer(minLength: 0)
            smallButton("Cancel", enabled: true) {
                interaction.cancelMove()
            }
        }
    }

    private func collectTitle(for placed: PlacedBuilding) -> String {
        switch placed.kind {
        case .farm: return "Harvest"
        case .habitat: return "Collect gold"
        case .building: return "Collect"
        }
    }

    private func smallButton(_ title: String, enabled: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(enabled ? 0.16 : 0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
