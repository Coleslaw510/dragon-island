import SwiftUI

/// Full-screen shop.  Habitats, farms and buildings start island placement;
/// eggs go straight into a free hatchery slot.  Every price and unlock level
/// comes from `starter_catalog.json`.
struct ShopView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: ShopTab = .habitats
    @State private var notice: String?

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 210), spacing: 14)]
    }

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                tabBar
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(items) { item in
                            ShopCardView(item: item,
                                         reason: reason(for: item),
                                         glow: store.tutorialTargetID == item.id) {
                                choose(item)
                            }
                        }
                    }
                    .padding(20)
                }
                if let notice {
                    Text(notice)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.bottom, 14)
                }
            }
        }
        .statusBarHidden(true)
        .onAppear {
            selectTutorialTab()
            store.notifyTutorialEvent("open_shop")
        }
    }

    private func selectTutorialTab() {
        guard let target = store.tutorialTargetID else { return }
        if target.hasPrefix("egg_") {
            tab = .eggs
        } else if store.catalog.buildings.contains(where: { $0.id == target }) {
            tab = store.catalog.building(target)?.isFarm == true ? .farms : .buildings
        } else if store.catalog.habitats.contains(where: { $0.id == target }) {
            tab = .habitats
        }
    }

    private var header: some View {
        HStack {
            Text("Shop")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Close shop"))
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(ShopTab.allCases) { item in
                Button {
                    tab = item
                    notice = nil
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(tab == item ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(tab == item ? Color.orange.opacity(0.85) : .white.opacity(0.08),
                                    in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
    }

    private var items: [ShopItem] {
        switch tab {
        case .habitats:
            return store.catalog.habitats.map(habitatItem)
        case .farms:
            return store.catalog.buildings.filter(\.isFarm).map(buildingItem)
        case .buildings:
            return store.catalog.buildings.filter { !$0.isFarm }.map(buildingItem)
        case .eggs:
            return store.catalog.shopEggs.map(eggItem)
        }
    }

    private func habitatItem(_ habitat: HabitatDefinition) -> ShopItem {
        let element = store.catalog.element(habitat.element)?.displayName
            ?? habitat.element.rawValue.capitalized
        return ShopItem(id: habitat.id, icon: habitat.texture, name: habitat.displayName,
                        detail: "\(element) · \(habitat.capacity) dragons",
                        cost: habitat.buildCost, unlockLevel: habitat.unlockLevel,
                        action: .placement(.habitat))
    }

    private func buildingItem(_ building: BuildingDefinition) -> ShopItem {
        let detail = building.isFarm
            ? "Grows \(building.harvestFood ?? 0) food"
            : building.description
        return ShopItem(id: building.id, icon: building.texture, name: building.displayName,
                        detail: detail, cost: building.cost,
                        unlockLevel: building.requiredLevel,
                        action: .placement(building.isFarm ? .farm : .building))
    }

    private func eggItem(_ listing: ShopEggDefinition) -> ShopItem {
        let element = store.catalog.element(listing.element)?.displayName
            ?? listing.element.rawValue.capitalized
        let dragon = store.catalog.dragon(listing.dragonID)?.displayName ?? "Dragon"
        return ShopItem(id: "egg_\(listing.element.rawValue)",
                        icon: "egg_\(listing.element.rawValue)",
                        name: "\(dragon) Egg",
                        detail: "\(element) · hatches in "
                            + TimeFormat.short(TimeInterval(listing.hatchSeconds)),
                        cost: listing.cost, unlockLevel: listing.unlockLevel,
                        action: .egg(listing))
    }

    private func reason(for item: ShopItem) -> String? {
        if store.state.islandLevel < item.unlockLevel {
            return "Level \(item.unlockLevel)"
        }
        if store.state.resources.gold < item.cost {
            return "Need \(item.cost) gold"
        }
        return nil
    }

    private func choose(_ item: ShopItem) {
        notice = nil
        switch item.action {
        case .placement(let kind):
            store.beginPlacement(kind: kind, definitionID: item.id, displayName: item.name)
            dismiss()
        case .egg(let listing):
            let wasTutorial = store.tutorialTargetID == "egg_\(listing.element.rawValue)"
            switch store.buyEgg(listing) {
            case .success(let egg):
                notice = "\(listing.element.rawValue.capitalized) egg added. Ready in "
                    + TimeFormat.short(max(0, egg.readyAt.timeIntervalSinceNow))
                if wasTutorial { dismiss() }
            case .failure(let failure):
                notice = failure.message
            }
        }
    }
}
