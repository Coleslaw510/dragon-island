import SwiftUI

/// Calm checklist of JSON-defined achievements.  Rows show progress, reward
/// and whether the reward was already granted.
struct AchievementsView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss

    private var definitions: [AchievementDefinition] { store.achievementDefinitions }

    private var completedCount: Int {
        definitions.filter { store.isAchievementComplete($0.id) }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summary
                    if definitions.isEmpty {
                        Text("No achievements are configured yet.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        ForEach(definitions) { definition in
                            row(definition)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            Image("icon_achievements_trophy")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
            Text("\(completedCount) of \(definitions.count) complete")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func row(_ definition: AchievementDefinition) -> some View {
        let progress = store.achievementProgress(definition)
        let complete = store.isAchievementComplete(definition.id)
        let current = complete ? progress.goal : min(progress.current, progress.goal)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: complete ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(complete ? Color.orange : Color.white.opacity(0.3))
                Text(definition.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(complete ? "Complete" : "\(current)/\(progress.goal)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(complete ? Color.orange : Color.white.opacity(0.55))
                    .monospacedDigit()
            }
            Text(definition.detail)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: progress.fraction)
                .tint(complete ? .orange : .white.opacity(0.55))
            rewardLine(definition, complete: complete)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.white.opacity(complete ? 0.09 : 0.05),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(complete ? 0.16 : 0.08), lineWidth: 1)
        )
    }

    private func rewardLine(_ definition: AchievementDefinition,
                            complete: Bool) -> some View {
        HStack(spacing: 5) {
            Image("icon_achievements_trophy")
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
                .opacity(0.7)
            Text(store.rewardSummary(definition.rewards))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            if complete {
                Text("· granted")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
    }
}
