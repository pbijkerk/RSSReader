import SwiftUI

/// Schild-badge met één woord die de factual reliability van een nieuwsbron toont.
/// Opzettelijk gescheiden van de bias-balk: bias en nauwkeurigheid zijn verschillende dimensies.
struct ReliabilityBadgeView: View {
    let level: String?  // "high", "mixed", "low" of nil

    var body: some View {
        if let level {
            HStack(spacing: 3) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(shieldColor(level))
                Text(localised(level))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .accessibilityLabel("Betrouwbaarheid: \(localised(level))")
        }
    }

    private func shieldColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "high":  return .green
        case "mixed": return Theme.accent
        case "low":   return Theme.accentSecondary
        default:      return .secondary
        }
    }

    private func localised(_ level: String) -> String {
        switch level.lowercased() {
        case "high":  return "Hoog"
        case "mixed": return "Gemiddeld"
        case "low":   return "Laag"
        default:      return level
        }
    }
}
