import SwiftUI

/// One shop card: icon, name, cost and the lock or gold reason when the card
/// cannot be bought.  Disabled cards stay visible but greyed.
struct ShopCardView: View {
    let item: ShopItem
    let reason: String?
    let glow: Bool
    let action: () -> Void

    private var disabled: Bool { reason != nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(item.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text(item.detail)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                    HStack(spacing: 4) {
                        Image("icon_gold_coin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                        Text("\(item.cost)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("· Lv \(item.unlockLevel)")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        if let reason {
                            Text("· \(reason)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.orange.opacity(0.9))
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(disabled ? 0.03 : 0.08),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(disabled ? 0.05 : 0.14), lineWidth: 1))
            .opacity(disabled ? 0.45 : 1)
            .tutorialGlow(glow)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
