import SwiftUI

/// Header row for the entry and detail sheets of the Insights screens:
/// a muted leading action, a centred 16/700 title, a vermilion trailing action.
struct InsightsSheetHeader: View {
    let title: String
    var leadingTitle: String = String(localized: "cancel")
    var trailingTitle: String = String(localized: "save")
    var trailingEnabled = true
    let onLeading: () -> Void
    let onTrailing: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.leona(16, .bold))
                .leonaTracking(-0.02, size: 16)
                .foregroundStyle(.tInk)
                .lineLimit(1)
                .padding(.horizontal, 90)

            HStack {
                Button(action: onLeading) {
                    Text(leadingTitle)
                        .font(.leona(15, .semibold))
                        .foregroundStyle(.tMuted)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button {
                    guard trailingEnabled else { return }
                    onTrailing()
                } label: {
                    Text(trailingTitle)
                        .font(.leona(15, .bold))
                        .foregroundStyle(trailingEnabled ? Color.vermilion : Color.tDisabled)
                }
                .buttonStyle(.plain)
                .disabled(!trailingEnabled)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(Color.tCanvas)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.tLine).frame(height: 1) }
    }
}
