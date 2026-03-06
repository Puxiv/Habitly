import SwiftUI

/// Central design-token file – dark theme with robot-cyan accent.
enum Theme {

    // MARK: - Accent

    /// Primary cyan accent matching Grogy's glowing eyes (#00E5FF).
    static let accent = Color(red: 0.0, green: 0.898, blue: 1.0)            // #00E5FF

    /// Dimmed accent for icon-circle backgrounds, badges, etc.
    static let accentDim = accent.opacity(0.15)

    // MARK: - Aliases (for callsites that reference Theme.cyan)

    static let cyan    = accent
    static let cyanDim = accentDim

    // MARK: - Semantic

    static let positive = accent
    static let negative = Color(red: 1.0, green: 0.27, blue: 0.27)         // #FF4545

    // MARK: - Surfaces

    /// Pure-black root background (matches iOS dark-mode systemBackground).
    static let background = Color.black

    /// Card / elevated surface – a touch lighter than pure black.
    static let card = Color(white: 0.11)                                     // #1C1C1C

    /// Secondary card surface for nested elements.
    static let cardElevated = Color(white: 0.15)                             // #262626

    // MARK: - Text helpers

    static let textPrimary   = Color.white
    static let textSecondary = Color(white: 0.55)
    static let textTertiary  = Color(white: 0.35)

    // MARK: - Gradients

    /// Subtle dark-cyan gradient for hero cards (AI teaser, etc.)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.04, green: 0.18, blue: 0.25),
                 Color(red: 0.02, green: 0.12, blue: 0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
