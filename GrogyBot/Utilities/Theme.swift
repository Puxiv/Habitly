import SwiftUI

/// Central design-token file – dark theme with neon-green accent.
enum Theme {

    // MARK: - Accent

    /// Primary neon-green accent used for buttons, active states, highlights.
    static let accent = Color(red: 0.13, green: 0.85, blue: 0.33)          // ≈ #21D954

    /// Dimmed accent for icon-circle backgrounds, badges, etc.
    static let accentDim = accent.opacity(0.15)

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

    /// Subtle dark-green gradient for hero cards (AI teaser, etc.)
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.06, green: 0.25, blue: 0.12),
                 Color(red: 0.04, green: 0.18, blue: 0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
