import SwiftUI

/// Inklapbare chip die fact-check resultaten toont voor een artikel.
/// Verschijnt alleen als het artikel minstens één gematcht claim heeft.
/// Gebruikt neutrale werkwoorden ("Beoordeeld als … door …") — nooit de app's eigen stem.
struct FactCheckChipView: View {
    let results: [FactCheckResult]
    @State private var isExpanded = false

    var body: some View {
        if let first = results.first {
            VStack(alignment: .leading, spacing: 0) {
                // Collapsed header — altijd zichtbaar
                Button {
                    withAnimation(.spring(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text("Fact-checked · \(first.rater)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

                // Expanded detail
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(results) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("„\(result.claim)"")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)

                                HStack(spacing: 4) {
                                    Text("Beoordeeld als")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                    Text(result.verdict)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(verdictColor(result.verdict))
                                    Text("door \(result.rater)")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.tertiary)
                                }

                                if let urlStr = result.resultURL, let url = URL(string: urlStr) {
                                    Link("Bekijk beoordeling →", destination: url)
                                        .font(.system(size: 11))
                                        .tint(Theme.accent)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemBackground).opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.green.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.green.opacity(0.18), lineWidth: 0.5)
            )
        }
    }

    private func verdictColor(_ verdict: String) -> Color {
        let lower = verdict.lowercased()
        if lower.contains("true") || lower.contains("correct") || lower.contains("accurate") {
            return .green
        }
        if lower.contains("false") || lower.contains("incorrect") || lower.contains("fabricat") || lower.contains("pants on fire") {
            return Theme.accentSecondary
        }
        if lower.contains("mislead") || lower.contains("mixed") || lower.contains("partly") || lower.contains("half") {
            return Theme.accent
        }
        return .secondary
    }
}
