import SwiftUI

/// Hatchery slots with date-driven incubation timers.  Hatching adds a real
/// OwnedDragon and assigns it to a matching habitat when space allows.
struct HatcheryView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss

    @State private var notice: String?

    private var hatcheries: [PlacedBuilding] { store.hatcheryBuildings }

    var body: some View {
        NavigationStack {
            Group {
                if hatcheries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(hatcheries) { hatchery in
                                hatcherySection(hatchery)
                            }
                            if let notice {
                                Text(notice)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Hatchery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image("icon_hatch")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            Text("Build a hatchery to incubate eggs from the breeding den.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(32)
    }

    private func hatcherySection(_ hatchery: PlacedBuilding) -> some View {
        let eggs = store.eggs(in: hatchery.id)
        let slots = store.eggCapacity(for: hatchery)
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(store.catalog.building(hatchery.definitionID)?.displayName ?? "Hatchery")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(eggs.count)/\(slots) slots")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            if eggs.isEmpty {
                Text("No eggs yet.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)],
                              alignment: .leading, spacing: 10) {
                        ForEach(eggs) { egg in
                            eggCard(egg, now: context.date)
                        }
                    }
                }
            }
        }
    }

    private func eggCard(_ egg: DragonEgg, now: Date) -> some View {
        let ready = egg.isReady(now: now)
        let definition = store.catalog.dragon(egg.blueprint.dragonID)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image("egg_\(egg.blueprint.element.rawValue)")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(definition?.displayName ?? "Unknown egg")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(egg.blueprint.element.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                if ready {
                    Image("indicator_hatching_ready_badge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
            }
            if ready {
                Button("Hatch") { hatch(egg) }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            } else {
                Text("Ready in \(TimeFormat.short(egg.readyAt.timeIntervalSince(now)))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func hatch(_ egg: DragonEgg) {
        switch store.hatchEgg(id: egg.id) {
        case .success(let dragon):
            notice = "\(dragon.nickname) hatched and joined the island."
        case .failure(let failure):
            notice = failure.message
        }
    }
}
