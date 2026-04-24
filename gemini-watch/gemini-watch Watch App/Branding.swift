import SwiftUI

/// Gemini's signature gradient, used for the sparkle icon, streaming dots,
/// and other accent moments. Kept in one place so every surface stays
/// visually consistent.
enum GeminiBrand {
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.27, green: 0.52, blue: 0.97), // blue
            Color(red: 0.60, green: 0.40, blue: 0.95), // purple
            Color(red: 0.95, green: 0.42, blue: 0.68), // pink
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// The 4-point Gemini-style spark with the brand gradient. Use wherever the
/// old `sparkles` symbol appeared.
struct GeminiSpark: View {
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(GeminiBrand.gradient)
    }
}
