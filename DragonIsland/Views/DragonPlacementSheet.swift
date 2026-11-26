import SwiftUI

/// Asks where a freshly hatched dragon should live.  Only habitats of the
/// dragon's element are offered, matching the existing one-element rule.
struct DragonPlacementSheet: View {
    @ObservedObject var store: GameStateStore
    let dragon: OwnedDragon
    var onOpenShop: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var notice: String?

    private var element: ElementType? { store.element(of: dragon) }

    private var elementName: String {
        guard let element else { return "matching" }
        return store.catalog.element(element)?.displayName ?? element.rawValue.capitalized
    }

    private var freeHabitats: [PlacedBuilding] {
        guard let element else { return [] }
        return store.freeHabitats(for: element)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(freeHabitats.isEmpty
                         ? "No room — buy a \(elementName) habitat."
                         : "Choose a \(elementName) habitat for \(dragon.nickname).")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if freeHabitats.isEmpty {
                        noRoom
                    } else {
                        ForEach(freeHabitats) { habitat in
                            habitatRow(habitat)
                        }
                    }
                    if let notice {
                        Text(notice)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(20)
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Place dragon")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        store.assignUnplacedDragons()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Shop") { openShop() }
                }
            }
        }
    }

    private var noRoom: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(dragon.nickname) needs a home.  Buy a \(elementName) habitat, place it, then choose it here.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            Button(action: openShop) {
                Label("Open Shop", systemImage: "storefront.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.orange.opacity(0.85), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func habitatRow(_ habitat: PlacedBuilding) -> some View {
        let name = store.catalog.habitat(habitat.definitionID)?.displayName ?? "Habitat"
        let capacity = store.catalog.habitat(habitat.definitionID)?.capacity ?? 0
        return HStack(spacing: 10) {
            Image(store.catalog.habitat(habitat.definitionID)?.texture ?? "habitat_fire")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text("\(store.occupantCount(in: habitat))/\(capacity) dragons")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            Button("Place") { assign(to: habitat) }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func assign(to habitat: PlacedBuilding) {
        if store.assignDragon(dragon.id, to: habitat.id) {
            dismiss()
        } else {
            notice = "That habitat is full."
        }
    }

    private func openShop() {
        dismiss()
        if let onOpenShop {
            onOpenShop()
        } else {
            store.requestShop()
        }
    }
}
