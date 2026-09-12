import SwiftUI

/// One row of the conversation: a day divider, the unread marker, an entry bubble,
/// or a running session bubble.
struct ThreadRowView: View {
    let row: ThreadRow
    let babyName: String
    let onOpen: (ThreadRow) -> Void
    let onOpenSleep: () -> Void
    let onOpenBreast: () -> Void

    var body: some View {
        switch row.kind {
        case .divider(let text):
            ThreadDivider(text: text, color: .tMuted, lineColor: .tLine, lineHeight: 1)
                .padding(.vertical, 6)
        case .unread(let text):
            ThreadDivider(text: text, color: .vermilion, lineColor: .vermilion.opacity(0.4), lineHeight: 1.5)
                .padding(.top, 8)
                .padding(.bottom, 4)
        case .entry(let activity):
            EntryBubble(activity: activity) { onOpen(row) }
        case .runningSleep(let activity):
            RunningSleepBubble(activity: activity, action: onOpenSleep)
        case .runningBreast(let activity):
            RunningBreastBubble(activity: activity, action: onOpenBreast)
        case .leona(let remark):
            LeonaRemarkBubble(remark: remark, babyName: babyName)
        }
    }
}

// MARK: - Leona's remark (a suggestion that was answered, kept in the flow)

private struct LeonaRemarkBubble: View {
    let remark: LeonaRemark
    let babyName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                LeonaTintCard(padding: EdgeInsets(top: 12, leading: 15, bottom: 12, trailing: 15), asBubble: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        LeonaCardHeader(name: babyName)
                        if let prompt = remark.prompt {
                            // What was asked, quoted above the decision.
                            Text(prompt)
                                .font(.leona(13))
                                .lineSpacing(2)
                                .foregroundStyle(.tMuted)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(remark.line)
                            .font(.leona(15, .medium))
                            .lineSpacing(3)
                            .foregroundStyle(.tInk)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text([remark.metaText, ThreadFormat.clock(remark.date)].compactMap { $0 }.joined(separator: " · "))
                    .font(.leona(11, .semibold))
                    .foregroundStyle(.tMuted)
                    .padding(.horizontal, 8)
            }
            .frame(maxWidth: 320, alignment: .leading)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Divider

private struct ThreadDivider: View {
    let text: String
    let color: Color
    let lineColor: Color
    let lineHeight: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(lineColor).frame(height: lineHeight)
            Text(text.uppercased())
                .font(.leona(11, .heavy))
                .leonaTracking(0.09, size: 11)
                .foregroundStyle(color)
                .lineLimit(1)
                .layoutPriority(1)
            Rectangle().fill(lineColor).frame(height: lineHeight)
        }
    }
}

// MARK: - Entry bubble (mine on the right, theirs on the left)

private struct EntryBubble: View {
    let activity: Activity
    let action: () -> Void

    private var mine: Bool { activity.isMine }

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 0) }
            Button(action: action) {
                VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                    HStack(spacing: 11) {
                        ColorTick(color: ThreadFormat.color(for: activity))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ThreadFormat.title(for: activity))
                                .font(.leona(15, .semibold))
                                .foregroundStyle(mine ? Color.white : Color.tTheirsInk)
                                .multilineTextAlignment(.leading)
                            if let sub = ThreadFormat.subtitle(for: activity) {
                                Text(sub)
                                    .font(.leona(13))
                                    .foregroundStyle(mine ? Color.white.opacity(0.72) : Color.tMuted)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 11)
                    .padding(.horizontal, 15)
                    .background(mine ? Color.tMine : Color.tTheirs)
                    .clipShape(mine ? AnyShape(UnevenRoundedRectangle.mineBubble) : AnyShape(UnevenRoundedRectangle.theirsBubble))

                    Text(ThreadFormat.meta(for: activity))
                        .font(.leona(11, .semibold))
                        .foregroundStyle(.tMuted)
                        .padding(.horizontal, 8)
                }
            }
            .buttonStyle(.leonaPress)
            .frame(maxWidth: 320, alignment: mine ? .trailing : .leading)
            if !mine { Spacer(minLength: 0) }
        }
    }
}

// MARK: - Running sleep

private struct RunningSleepBubble: View {
    let activity: Activity
    let action: () -> Void

    var body: some View {
        RunningBubble(
            background: .sleepBubbleBg,
            ink: .sleepBubbleInk,
            sub: .sleepBubbleSub,
            dot: .lilac,
            dotPeriod: 1.8,
            title: { _ in String(localized: "thread_asleep_since \(ThreadFormat.clock(activity.startTime))") },
            subtitle: { now in String(localized: "thread_running_sub \(ThreadFormat.dur(now.timeIntervalSince(activity.startTime)))") },
            meta: "\(activity.authorDisplayName) · \(String(localized: "thread_meta_now"))",
            action: action
        )
    }
}

// MARK: - Running breastfeed

private struct RunningBreastBubble: View {
    let activity: Activity
    let action: () -> Void

    private var currentSide: BreastSide {
        activity.breastfeedingLaps.last?.side ?? activity.breastSide ?? .left
    }

    private var isPaused: Bool {
        activity.breastfeedingLaps.last?.endTime != nil
    }

    var body: some View {
        RunningBubble(
            background: .breastBubbleBg,
            ink: .breastBubbleInk,
            sub: .breastBubbleSub,
            dot: .breastDot,
            dotPeriod: 1.4,
            title: { _ in String(localized: "thread_feeding_side \(ThreadFormat.sideLabel(currentSide))") },
            subtitle: { _ in
                let time = ThreadFormat.mmss(activity.breastfeedingSeconds)
                return isPaused
                    ? String(localized: "thread_bf_paused \(time)")
                    : String(localized: "thread_bf_running \(time)")
            },
            meta: "\(activity.authorDisplayName) · \(String(localized: "thread_started_at \(ThreadFormat.clock(activity.startTime))"))",
            action: action
        )
    }
}

private struct RunningBubble: View {
    let background: Color
    let ink: Color
    let sub: Color
    let dot: Color
    let dotPeriod: Double
    let title: (Date) -> String
    let subtitle: (Date) -> String
    let meta: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: action) {
                VStack(alignment: .trailing, spacing: 4) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 11) {
                            PulseDot(color: dot, size: 8, period: dotPeriod)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(title(context.date))
                                    .font(.leona(15, .bold))
                                    .foregroundStyle(ink)
                                Text(subtitle(context.date))
                                    .font(.leona(13))
                                    .foregroundStyle(sub)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(background)
                    .clipShape(UnevenRoundedRectangle.mineBubble)

                    Text(meta)
                        .font(.leona(11, .semibold))
                        .foregroundStyle(.tMuted)
                        .padding(.trailing, 8)
                }
            }
            .buttonStyle(.leonaPress)
            .frame(maxWidth: 320, alignment: .trailing)
        }
    }
}
