import SwiftUI

/// Draws a soft gold ring around the control the tutorial points at.
struct TutorialGlowModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.yellow, lineWidth: 3)
                    .shadow(color: .yellow.opacity(0.85), radius: 8)
                    .allowsHitTesting(false)
            }
        }
    }
}

extension View {
    func tutorialGlow(_ active: Bool) -> some View {
        modifier(TutorialGlowModifier(active: active))
    }
}
