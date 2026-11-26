import SwiftUI

/// Quiet settings sheet behind the HUD gear: sound, achievements and a manual
/// save.  No promos or event banners live here.
struct SettingsView: View {
    @ObservedObject var store: GameStateStore
    @Environment(\.dismiss) private var dismiss

    @State private var showsAchievements = false

    private var completedCount: Int {
        store.achievementDefinitions.filter { store.isAchievementComplete($0.id) }.count
    }

    private var totalCount: Int { store.achievementDefinitions.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    soundRow
                    achievementsRow
                    plotRow
                    saveRow
                }
                .padding(20)
            }
            .background(Color(white: 0.08).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showsAchievements) {
            AchievementsView(store: store)
        }
    }

    private var soundRow: some View {
        HStack(spacing: 12) {
            Image("icon_audio_speaker")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sound effects")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Collect, hatch, battle and victory cues.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.soundEnabled },
                set: { enabled in
                    store.setSoundEnabled(enabled)
                    if enabled { store.playSound(.collect) }
                }
            ))
            .labelsHidden()
            .tint(.orange)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var achievementsRow: some View {
        Button {
            showsAchievements = true
        } label: {
            HStack(spacing: 12) {
                Image("icon_achievements_trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("\(completedCount) of \(totalCount) complete")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var plotRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("Island plot")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("\(store.state.unlockedGridColumns ?? GameConfig.gridColumns) × "
                     + "\(store.state.unlockedGridRows ?? GameConfig.gridRows) tiles")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private var saveRow: some View {
        Button {
            store.save()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image("icon_settings_gear")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text("Save now")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
