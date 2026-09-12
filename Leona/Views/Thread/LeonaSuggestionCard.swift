import SwiftUI

/// Leona's line at the bottom of the thread: one sentence, one action, one way to say "not yet".
struct LeonaSuggestionCard: View {
    let advice: LeonaAdvice
    let onPrimary: (LeonaAdvice) -> Void
    let onSecondary: (LeonaAdvice) -> Void
    let onWhy: () -> Void

    var body: some View {
        LeonaTintCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    LeonaMark()
                    Text("LEONA")
                        .font(.leona(11, .heavy))
                        .leonaTracking(0.1, size: 11)
                        .foregroundStyle(.tLeonaInk)
                    Spacer(minLength: 0)
                    Button(action: onWhy) {
                        Text(String(localized: "leona_why"))
                            .font(.leona(11, .bold))
                            .underline()
                            .foregroundStyle(.tLeonaInk)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 7)

                Text(advice.line)
                    .font(.leona(15, .medium))
                    .lineSpacing(3)
                    .foregroundStyle(.tInk)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Button {
                        HapticManager.impact(.medium)
                        onPrimary(advice)
                    } label: {
                        Text(advice.cta)
                            .font(.leona(14, .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.vermilion)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.leonaPress)

                    Button {
                        HapticManager.impact(.light)
                        onSecondary(advice)
                    } label: {
                        Text(advice.secondaryTitle)
                            .font(.leona(14, .bold))
                            .foregroundStyle(.tLeonaInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.tSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.tLeonaLine, lineWidth: 1))
                    }
                    .buttonStyle(.leonaPress)
                    .opacity(advice.secondary == .none ? 0.55 : 1)
                    .disabled(advice.secondary == .none)
                }
                .padding(.top, 12)
            }
        }
    }
}
