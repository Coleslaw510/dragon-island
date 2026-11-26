import Foundation

/// Guided tutorial progress.  Step text and targets live in
/// `starter_catalog.json` under `tutorialSteps`; this file only moves the
/// pointer and saves it, so a relaunch resumes the same step.
extension GameStateStore {
    var tutorialSteps: [TutorialStep] { catalog.tutorialSteps }

    /// Nil for old saves (no `tutorialStepID`) and for finished tutorials.
    var currentTutorialStep: TutorialStep? {
        guard !state.didCompleteTutorial,
              let id = state.tutorialStepID,
              let step = tutorialSteps.first(where: { $0.id == id }) else { return nil }
        return step
    }

    var tutorialTargetID: String? { currentTutorialStep?.targetID }

    func tutorialTargetMatches(_ targetID: String) -> Bool {
        currentTutorialStep?.targetID == targetID
    }

    /// Advances only when the finished action matches the current step id.
    func notifyTutorialEvent(_ stepID: String) {
        guard currentTutorialStep?.id == stepID else { return }
        advanceTutorial()
    }

    func advanceTutorial() {
        guard let step = currentTutorialStep,
              let index = tutorialSteps.firstIndex(where: { $0.id == step.id }) else { return }
        if index + 1 < tutorialSteps.count {
            state.tutorialStepID = tutorialSteps[index + 1].id
        } else {
            state.tutorialStepID = nil
            state.didCompleteTutorial = true
        }
        save()
    }

    func skipTutorial() {
        state.tutorialStepID = nil
        state.didCompleteTutorial = true
        save()
    }

    /// Called once at launch after habitat assignments are reconciled, so a
    /// dragon that was auto-placed does not stall the "Place your dragon" step.
    func reconcileTutorialProgress() {
        guard currentTutorialStep?.id == "place_dragon",
              state.ownedDragons.contains(where: { $0.assignedHabitatID != nil }) else { return }
        advanceTutorial()
    }
}
