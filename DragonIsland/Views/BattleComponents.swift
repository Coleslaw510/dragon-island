import SwiftUI

/// Cycles the sliced sheet frames with SwiftUI so battle needs no extra scene.
struct BattleDragonSprite: View {
    let definitionID: String
    let state: DragonAnimationState
    let height: CGFloat
    var mirrored = false
    var fallback = "badge_star"
    var spritePrefix: String? = nil

    private var frames: [String] {
        SpriteSheetLoader.shared.frameNames(forDragon: definitionID,
                                            spritePrefix: spritePrefix, state: state)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.125)) { context in
            sprite(at: context.date)
        }
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .frame(width: height * 1.3, height: height)
        .accessibilityHidden(true)
    }

    private func sprite(at date: Date) -> some View {
        let names = frames
        let index = names.isEmpty
            ? 0
            : Int(date.timeIntervalSinceReferenceDate / 0.125) % names.count
        return Group {
            if names.isEmpty {
                Image(fallback).resizable().scaledToFit()
            } else {
                Image(names[index]).resizable().scaledToFit()
            }
        }
    }
}

struct BattleHealthBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16))
                Capsule().fill(healthColor)
                    .frame(width: max(0, geometry.size.width * fraction))
            }
        }
        .frame(height: 5)
    }

    private var healthColor: Color {
        if fraction > 0.5 { return .green }
        if fraction > 0.22 { return .yellow }
        return .red
    }
}

struct BattleFighterCard: View {
    let fighter: BattleFighter
    let badgeTexture: String
    let isActive: Bool
    let isAttacking: Bool
    let isEnemy: Bool

    var body: some View {
        HStack(spacing: 7) {
            BattleDragonSprite(
                definitionID: fighter.definitionID,
                state: isAttacking ? .action : .idle,
                height: 64,
                mirrored: isEnemy,
                fallback: badgeTexture,
                spritePrefix: fighter.spritePrefix
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(badgeTexture).resizable().scaledToFit().frame(width: 13, height: 13)
                    Text(fighter.name).lineLimit(1)
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("Lv \(fighter.level) · \(fighter.health)/\(fighter.maxHealth)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                BattleHealthBar(fraction: fighter.healthFraction)
            }
        }
        .foregroundStyle(.white)
        .frame(width: 140, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(isActive ? 0.5 : 0.3), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isActive ? Color.orange : Color.white.opacity(0.12),
                              lineWidth: isActive ? 2 : 1)
        )
        .opacity(fighter.isAlive ? 1 : 0.3)
        .scaleEffect(isAttacking ? 1.06 : 1)
        .animation(.easeOut(duration: 0.15), value: isAttacking)
    }
}

/// One dragon in the pre-battle team picker.
struct BattleRosterCard: View {
    let dragon: OwnedDragon
    let element: ElementType
    let badgeTexture: String
    var spritePrefix: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                BattleDragonSprite(definitionID: dragon.definitionID, state: .idle,
                                   height: 38, fallback: badgeTexture,
                                   spritePrefix: spritePrefix)
                VStack(alignment: .leading, spacing: 1) {
                    Text(dragon.nickname)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text("\(element.rawValue.capitalized) · Lv \(dragon.level)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.orange : Color.white.opacity(0.35))
            }
            .foregroundStyle(.white)
            .padding(9)
            .background(.black.opacity(selected ? 0.5 : 0.32),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.orange : Color.white.opacity(0.12),
                                  lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct BattleRewardChip: View {
    let icon: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(icon).resizable().scaledToFit().frame(width: 16, height: 16)
            Text("+\(value)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}
