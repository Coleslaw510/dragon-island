import Foundation

/// Sound preference.  Every effect goes through `playSound`, so muting the
/// island also mutes hatch, collect, battle hit and victory cues.
extension GameStateStore {
    var soundEnabled: Bool { state.soundEnabled ?? true }

    func setSoundEnabled(_ enabled: Bool) {
        state.soundEnabled = enabled
        save()
    }

    func playSound(_ sound: GameSound) {
        guard soundEnabled else { return }
        AudioService.shared.play(sound)
    }
}
