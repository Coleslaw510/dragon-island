import SwiftUI

/// The single battle screen: enemy team above, player team below, one log
/// line and only Fight / Forfeit as controls.
struct BattleArenaView: View {
    @ObservedObject var session: BattleSession
    let onClose: () -> Void

    private var rewards: BattleRewards { session.store.battleRules.rewards }

    var body: some View {
        ZStack {
            VStack(spacing: 6) {
                teamRow(session.enemyTeam, isEnemy: true)
                Spacer(minLength: 2)
                statusBanner
                Spacer(minLength: 2)
                teamRow(session.playerTeam, isEnemy: false)
                controls
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            if let outcome = session.outcome {
                resultOverlay(outcome)
            }
        }
    }

    private func teamRow(_ team: [BattleFighter], isEnemy: Bool) -> some View {
        HStack(spacing: 10) {
            ForEach(displayOrder(team, reversed: isEnemy)) { fighter in
                BattleFighterCard(
                    fighter: fighter,
                    badgeTexture: badge(for: fighter.element),
                    isActive: session.activeID == fighter.id,
                    isAttacking: session.attackingID == fighter.id,
                    isEnemy: isEnemy
                )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusBanner: some View {
        VStack(spacing: 2) {
            Text(session.isPlayerTurn ? "Your turn" : "Enemy turn")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(session.isPlayerTurn ? Color.orange : Color.white.opacity(0.55))
            Text(session.latestLog)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let hint = session.cooldownHint, session.isPlayerTurn {
                Text(hint)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Forfeit") { session.forfeit() }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(session.outcome != nil)

            Button("Fight") { session.playerAttack() }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!session.isPlayerTurn || session.isResolving || session.outcome != nil)
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .controlSize(.large)
        .padding(.top, 2)
    }

    private func resultOverlay(_ outcome: BattleOutcome) -> some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(title(for: outcome))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle(for: outcome))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                if outcome == .victory {
                    HStack(spacing: 16) {
                        BattleRewardChip(icon: "icon_gold_coin", value: rewards.gold)
                        BattleRewardChip(icon: "icon_food_berries", value: rewards.food)
                        BattleRewardChip(icon: "icon_xp_star", value: rewards.xp)
                    }
                    Text("Each fighter gained \(rewards.dragonXP) XP")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Button("Done") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.large)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .padding(.top, 4)
            }
            .padding(26)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
    }

    private func displayOrder(_ team: [BattleFighter], reversed: Bool) -> [BattleFighter] {
        reversed ? Array(team.reversed()) : team
    }

    private func badge(for element: ElementType) -> String {
        session.store.catalog.element(element)?.badgeTexture ?? "badge_\(element.rawValue)"
    }

    private func title(for outcome: BattleOutcome) -> String {
        switch outcome {
        case .victory: return "Victory"
        case .defeat: return "Defeat"
        case .forfeit: return "Forfeit"
        }
    }

    private func subtitle(for outcome: BattleOutcome) -> String {
        switch outcome {
        case .victory: return "Rewards added to your island."
        case .defeat: return "Your team needs rest."
        case .forfeit: return "You left the arena."
        }
    }
}
