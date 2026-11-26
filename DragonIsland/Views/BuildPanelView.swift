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
            Text("Plot \(interaction.selectedTile.x),\(interaction.selectedTile.y)")
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
                    Text(detail(for: placed, now: context.date))
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
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            HStack(spacing: 7) {
                if let placed = interaction.selectedPlacement {
                    if placed.kind == .farm && placed.plantedAt == nil {
                        smallButton("Plant", enabled: interaction.canPlant(placed)) {
                            interaction.plantSelectedFarm()
                        }
                    }
                    if isReady(placed) {
                        smallButton(placed.kind == .farm ? "Harvest" : "Collect gold", enabled: true) {
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
            HStack(spacing: 7) {
                Menu {
                    ForEach(store.catalog.habitats) { habitat in
                        Button("\(habitat.displayName)  ·  \(habitat.buildCost) gold") {
                            interaction.build(kind: .habitat, definitionID: habitat.id)
                        }
                        .disabled(!interaction.canBuild(kind: .habitat, definitionID: habitat.id))
                    }
                } label: {
                    menuLabel("Build habitat")
                }

                Menu {
                    ForEach(store.catalog.buildings) { building in
                        Button("\(building.displayName)  ·  \(building.cost) gold") {
                            interaction.build(kind: building.isFarm ? .farm : .building,
                                              definitionID: building.id)
                        }
                        .disabled(!interaction.canBuild(kind: building.isFarm ? .farm : .building,
                                                        definitionID: building.id))
                    }
                } label: {
                    menuLabel("Build structure")
                }
            }
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

    // MARK: - Status text

    private func detail(for placed: PlacedBuilding, now: Date) -> String {
        switch placed.kind {
        case .habitat:
            return habitatDetail(placed, now: now)
        case .farm:
            return farmDetail(placed, now: now)
        case .building:
            return store.catalog.building(placed.definitionID)?.description ?? "Idle for now."
        }
    }

    private func habitatDetail(_ placed: PlacedBuilding, now: Date) -> String {
        guard let status = IslandEconomy.status(for: placed, state: store.state,
                                                catalog: store.catalog, now: now) else {
            return "Habitat"
        }
        if status.occupants.isEmpty {
            return "\(status.occupancyText) · no gold income"
        }
        if status.isReady {
            return "\(status.occupancyText) · gold ready: \(status.pendingGold)"
        }
        var text = "\(status.occupancyText) · gold \(status.pendingGold)/\(status.definition.goldCap)"
        if let seconds = status.secondsUntilReady {
            text += " · ready in \(timeText(seconds))"
        }
        return text
    }

    private func farmDetail(_ placed: PlacedBuilding, now: Date) -> String {
        guard let definition = store.catalog.building(placed.definitionID), definition.isFarm else {
            return "Food farm"
        }
        let stage = FarmGrowth.stage(for: placed, catalog: store.catalog, now: now)
        switch stage {
        case .empty:
            return "Empty soil. Plant for \(definition.plantCost ?? 0) gold."
        case .plantedSprouts, .growingCrops:
            let remaining = FarmGrowth.secondsRemaining(plantedAt: placed.plantedAt,
                                                         definition: definition, now: now) ?? 0
            return "Growing · \(timeText(remaining)) left · yields \(definition.harvestFood ?? 0) food"
        case .ready:
            return "Ready to harvest · \(definition.harvestFood ?? 0) food"
        }
    }

    private func isReady(_ placed: PlacedBuilding) -> Bool {
        switch placed.kind {
        case .habitat:
            return IslandEconomy.status(for: placed, state: store.state,
                                        catalog: store.catalog, now: .now)?.isReady == true
        case .farm:
            return FarmGrowth.stage(for: placed, catalog: store.catalog, now: .now) == .ready
        case .building:
            return false
        }
    }

    private func timeText(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(seconds)s" }
        return "\(seconds)s"
    }

    // MARK: - Small views

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

    private func menuLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.16), in: Capsule())
    }
}
