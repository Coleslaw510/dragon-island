import SwiftUI

/// One selectable parent dragon in the breeding sheet.  Dragons already in a
/// breeding pair are greyed out and cannot be picked.
struct BreedingParentCard: View {
    let dragon: OwnedDragon
    let element: ElementType
    let badgeTexture: String
    let selected: Bool
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(badgeTexture)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(dragon.nickname)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(busy ? "In a breeding pair"
                              : "\(element.rawValue.capitalized) · Lv \(dragon.level)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(9)
            .background(.white.opacity(selected && !busy ? 0.20 : 0.08),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected && !busy ? Color.orange : Color.white.opacity(0.10),
                                  lineWidth: selected && !busy ? 2 : 1)
            )
            .grayscale(busy ? 1 : 0)
            .opacity(busy ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }
}

/// Active breeding pair with a countdown or a waiting-for-slot note.
struct BreedingSessionRow: View {
    let session: BreedingSession
    let parentA: String
    let parentB: String
    let now: Date

    var body: some View {
        let ready = session.isReady(now: now)
        HStack(spacing: 10) {
            Image("egg_\(session.egg.element.rawValue)")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Text("\(parentA) + \(parentB)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Spacer(minLength: 0)
            Text(ready ? "Egg waiting for a hatchery slot"
                       : TimeFormat.short(session.readyAt.timeIntervalSince(now)))
                .font(.caption)
                .foregroundStyle(ready ? Color.green : Color.white.opacity(0.6))
        }
        .padding(9)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Small icon + amount cost chip.
struct BreedingCostChip: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(icon).resizable().scaledToFit().frame(width: 16, height: 16)
            Text("\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.82))
    }
}
