import SwiftUI

/// Top banner while the player picks a plot for a shop purchase or a move.
struct PlacementBanner: View {
    let text: String
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.yellow)
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)
                .tint(.white)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule())
    }
}

/// One small tutorial line with a Skip link.  No modal, no extra panels.
struct TutorialBanner: View {
    @ObservedObject var store: GameStateStore

    var body: some View {
        if let step = store.currentTutorialStep {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.yellow)
                Text(step.text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Button("Skip") { store.skipTutorial() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.black.opacity(0.42), in: Capsule())
            .overlay(Capsule().strokeBorder(.yellow.opacity(0.5), lineWidth: 1))
        }
    }
}
