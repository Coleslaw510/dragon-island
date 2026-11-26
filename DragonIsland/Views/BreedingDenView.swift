import SwiftUI

/// Calm parent picker for a placed breeding den or corral.  Costs, timer and
/// the egg element all come from `breeding_rules.json`.
struct BreedingDenView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedBuildingID: UUID?
    @State private var parentIDs: [UUID] = []
    @State private var notice: String?

    private var buildings: [PlacedBuilding] { store.breedingBuildings }
    private var building: PlacedBuilding? {
        buildings.first { $0.id == selectedBuildingID } ?? buildings.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if buildings.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Breeding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { selectedBuildingID = selectedBuildingID ?? buildings.first?.id }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                buildingPicker
                costRow
                parentGrid
                startButton
                if let notice {
                    Text(notice)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.orange)
                }
                sessions
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image("icon_breed")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            Text("Build a breeding den or corral to pair two dragons.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(32)
    }

    private var buildingPicker: some View {
        HStack(spacing: 12) {
            Menu {
                ForEach(buildings) { placed in
                    Button(store.catalog.building(placed.definitionID)?.displayName ?? placed.definitionID) {
                        selectedBuildingID = placed.id
                        parentIDs = []
                        notice = nil
                    }
                }
            } label: {
                Label(buildingName, systemImage: "chevron.down")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            if let building {
                Text("\(store.availableBreedingSlots(in: building)) slot open")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
    }

    private var costRow: some View {
        HStack(spacing: 14) {
            BreedingCostChip(icon: "icon_gold_coin", value: store.rules.breeding.goldCost)
            BreedingCostChip(icon: "icon_food_berries", value: store.rules.breeding.foodCost)
            Label(timerText, systemImage: "clock")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var parentGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pick two parents")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                      alignment: .leading, spacing: 10) {
                ForEach(store.state.ownedDragons) { dragon in
                    BreedingParentCard(
                        dragon: dragon,
                        element: element(for: dragon),
                        badgeTexture: badge(for: element(for: dragon)),
                        selected: parentIDs.contains(dragon.id),
                        busy: store.isBreedingParentBusy(dragon.id)
                    ) {
                        toggle(dragon.id)
                    }
                }
            }
        }
    }

    private var startButton: some View {
        Button(action: start) {
            Text("Start breeding")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.orange.opacity(canStart ? 0.85 : 0.25),
                            in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
    }

    @ViewBuilder
    private var sessions: some View {
        if let building, !store.breedingSessions(in: building.id).isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("In the den")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    ForEach(store.breedingSessions(in: building.id)) { session in
                        BreedingSessionRow(
                            session: session,
                            parentA: parentName(session.parentAID),
                            parentB: parentName(session.parentBID),
                            now: context.date
                        )
                    }
                }
            }
        }
    }

    private var buildingName: String {
        guard let building else { return "Breeding building" }
        return store.catalog.building(building.definitionID)?.displayName ?? building.definitionID
    }

    private var timerText: String {
        guard let definitionID = building?.definitionID,
              let rule = store.rules.breedingBuilding(definitionID) else { return "—" }
        return TimeFormat.short(TimeInterval(rule.seconds))
    }

    private var canStart: Bool {
        guard let building, parentIDs.count == 2 else { return false }
        return store.availableBreedingSlots(in: building) > 0
            && parentIDs.allSatisfy { !store.isBreedingParentBusy($0) }
            && store.state.resources.gold >= store.rules.breeding.goldCost
            && store.state.resources.food >= store.rules.breeding.foodCost
    }

    private func toggle(_ id: UUID) {
        notice = nil
        guard !store.isBreedingParentBusy(id) else {
            notice = BreedingFailure.dragonBusy.message
            return
        }
        if let index = parentIDs.firstIndex(of: id) {
            parentIDs.remove(at: index)
        } else if parentIDs.count < 2 {
            parentIDs.append(id)
        }
    }

    private func start() {
        guard let building, parentIDs.count == 2 else { return }
        switch store.startBreeding(buildingID: building.id,
                                   parentA: parentIDs[0], parentB: parentIDs[1]) {
        case .success:
            parentIDs = []
            notice = "Pair settled in. The egg will move to a free hatchery slot."
        case .failure(let failure):
            notice = failure.message
        }
    }

    private func parentName(_ id: UUID) -> String {
        store.state.ownedDragons.first { $0.id == id }?.nickname ?? "Dragon"
    }

    private func element(for dragon: OwnedDragon) -> ElementType {
        store.catalog.dragon(dragon.definitionID)?.element ?? .fire
    }

    private func badge(for element: ElementType) -> String {
        store.catalog.element(element)?.badgeTexture ?? "badge_\(element.rawValue)"
    }
}
