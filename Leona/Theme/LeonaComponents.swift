import SwiftUI

// MARK: - Leona mark ("L" badge)

struct LeonaMark: View {
    var size: CGFloat = 19
    var radius: CGFloat = 6
    var fontSize: CGFloat = 11

    var body: some View {
        Text("L")
            .font(.leona(fontSize, .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.vermilion)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// The small "L  LEONA" header that opens every one of Leona's cards.
struct LeonaCardHeader: View {
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        HStack(spacing: 7) {
            LeonaMark(size: 17, radius: 5, fontSize: 10)
            Text("LEONA")
                .font(.leona(10, .heavy))
                .leonaTracking(0.1, size: 10)
                .foregroundStyle(.tLeonaInk)
            Spacer(minLength: 0)
            if let trailing { trailing() }
        }
    }
}

// MARK: - Section label

struct LeonaSectionLabel: View {
    let text: String
    var size: CGFloat = 12
    var tracking: Double = 0.06
    var color: Color = .tMuted

    init(_ text: String, size: CGFloat = 12, tracking: Double = 0.06, color: Color = .tMuted) {
        self.text = text
        self.size = size
        self.tracking = tracking
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.leona(size, .heavy))
            .leonaTracking(tracking, size: size)
            .foregroundStyle(color)
    }
}

// MARK: - Containers

/// White (or dark plum) card with a hairline border, radius 20.
struct LeonaCard<Content: View>: View {
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 15, bottom: 12, trailing: 15)
    var radius: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.tLine, lineWidth: 1))
    }
}

/// Plum card with white ink — used for hero blocks (profile header, pinned record, detail header).
struct PlumCard<Content: View>: View {
    var padding: CGFloat = 17
    var radius: CGFloat = 20
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tMine)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Leona's own card: warm tint, warm border.
struct LeonaTintCard<Content: View>: View {
    var padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    var asBubble = false
    @ViewBuilder let content: Content

    var body: some View {
        let shape = asBubble ? AnyShape(UnevenRoundedRectangle.theirsBubble) : AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.tLeonaBg)
            .clipShape(shape)
            .overlay(shape.stroke(Color.tLeonaLine, lineWidth: 1))
    }
}

/// Grouped list container: rows separated by hairlines, no line after the last row.
struct LeonaGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        _VariadicView.Tree(LeonaGroupLayout()) { content }
            .background(Color.tSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.tLine, lineWidth: 1))
    }
}

struct LeonaGroupLayout: _VariadicView_UnaryViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastID = children.last?.id
        VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != lastID {
                    Rectangle().fill(Color.tLine).frame(height: 1)
                }
            }
        }
    }
}

/// A tappable row inside a LeonaGroup.
struct LeonaRow: View {
    let title: String
    var subtitle: String? = nil
    var showsChevron = false
    var destructive = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.leona(15, .bold))
                        .foregroundStyle(destructive ? Color.vermilion : Color.tInk)
                    if let subtitle {
                        Text(subtitle)
                            .font(.leona(12))
                            .foregroundStyle(.tMuted)
                    }
                }
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.tMuted)
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

/// A toggle row drawn the way the design draws it: 46×27 track, white knob.
struct LeonaToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isOn.toggle() }
            HapticManager.selection()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.leona(15, .bold))
                        .foregroundStyle(.tInk)
                    if let subtitle {
                        Text(subtitle)
                            .font(.leona(12))
                            .foregroundStyle(.tMuted)
                    }
                }
                Spacer(minLength: 0)
                LeonaSwitch(isOn: isOn)
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct LeonaSwitch: View {
    let isOn: Bool

    var body: some View {
        HStack {
            if isOn { Spacer(minLength: 0) }
            Circle().fill(.white).frame(width: 23, height: 23)
            if !isOn { Spacer(minLength: 0) }
        }
        .padding(2)
        .frame(width: 46, height: 27)
        .background(isOn ? Color.vermilion : Color.tToggleOff)
        .clipShape(Capsule())
    }
}

// MARK: - Buttons

/// Pill used for periods, metrics and filters. Vermilion when selected, chip grey otherwise.
struct LeonaPill: View {
    let title: String
    let isOn: Bool
    var tone: Tone = .vermilion
    var fontSize: CGFloat = 12
    var vertical: CGFloat = 9
    var horizontal: CGFloat = 14
    var fill = true
    let action: () -> Void

    enum Tone { case vermilion, plum }

    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            Text(title)
                .font(.leona(fontSize, .heavy))
                .foregroundStyle(isOn ? Color.white : Color.tTheirsInk)
                .padding(.vertical, vertical)
                .padding(.horizontal, horizontal)
                .frame(maxWidth: fill ? .infinity : nil)
                .background(isOn ? (tone == .vermilion ? Color.vermilion : Color.tMine) : Color.tChip)
                .clipShape(Capsule())
        }
        .buttonStyle(.leonaPress)
    }
}

/// Square-ish segment (Trends / Growth / Health), radius 12.
struct LeonaSegment: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.selection()
            action()
        }) {
            Text(title)
                .font(.leona(13, .heavy))
                .foregroundStyle(isOn ? Color.white : Color.tTheirsInk)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isOn ? Color.vermilion : Color.tChip)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.leonaPress)
    }
}

/// 34×34 icon button used in the thread header.
struct LeonaIconButton: View {
    let systemImage: String
    var isOn = false
    var size: CGFloat = 34
    var iconSize: CGFloat = 16
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(isOn ? Color.white : Color.tMuted)
                .frame(width: size, height: size)
                .background(isOn ? Color.vermilion : Color.tChip)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.leonaPress)
    }
}

/// Full-width vermilion call to action, 58pt tall.
struct LeonaPrimaryButton: View {
    let title: String
    var enabled = true
    var height: CGFloat = 58
    var radius: CGFloat = 18
    var fontSize: CGFloat = 17
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard enabled else { return }
            HapticManager.impact(.medium)
            action()
        }) {
            Text(title)
                .font(.leona(fontSize, .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(enabled ? Color.vermilion : Color.tDisabled)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
        .buttonStyle(LeonaPressStyle(scale: 0.98))
    }
}

/// Small rounded button: "+ Add", "Open record", "Mark resolved".
struct LeonaSmallButton: View {
    let title: String
    var tone: Tone = .plum
    var fontSize: CGFloat = 12
    var vertical: CGFloat = 8
    var horizontal: CGFloat = 15
    var radius: CGFloat = 999
    let action: () -> Void

    enum Tone { case plum, vermilion, ghost, surface, outline }

    var body: some View {
        Button(action: {
            HapticManager.impact(.light)
            action()
        }) {
            Text(title)
                .font(.leona(fontSize, tone == .surface ? .bold : .heavy))
                .foregroundStyle(ink)
                .padding(.vertical, vertical)
                .padding(.horizontal, horizontal)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(borderColor, lineWidth: tone == .outline ? 1.5 : (tone == .surface ? 1 : 0))
                )
        }
        .buttonStyle(.leonaPress)
    }

    private var ink: Color {
        switch tone {
        case .plum, .vermilion, .ghost: return .white
        case .surface: return .tInk
        case .outline: return .vermilion
        }
    }

    private var background: Color {
        switch tone {
        case .plum: return .tMine
        case .vermilion: return .vermilion
        case .ghost: return Color.white.opacity(0.14)
        case .surface, .outline: return .tSurface
        }
    }

    private var borderColor: Color {
        switch tone {
        case .outline: return .vermilion
        case .surface: return .tLine
        default: return .clear
        }
    }
}

// MARK: - Text field

struct LeonaTextField: View {
    let placeholder: String
    @Binding var text: String
    var height: CGFloat = 44
    var radius: CGFloat = 22
    var fontSize: CGFloat = 15
    var weight: Font.Weight = .regular
    var borderColor: Color = .tLine
    var borderWidth: CGFloat = 1
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.leona(fontSize, weight))
            .foregroundStyle(.tInk)
            .submitLabel(submitLabel)
            .onSubmit { onSubmit?() }
            .padding(.horizontal, 16)
            .frame(height: height)
            .background(Color.tSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(borderColor, lineWidth: borderWidth))
    }
}

// MARK: - Avatar

struct BabyAvatar: View {
    let baby: Baby
    var size: CGFloat = 38
    var radius: CGFloat = 13
    var background: Color = .tTheirs
    var silhouette: Color = .tAvatar

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            if let image = baby.profileImage {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(silhouette)
                    .frame(width: size * 0.7, height: size * 0.7)
                    .offset(y: size * 0.06)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Round initial badge for people in the thread.
struct PersonBadge: View {
    let name: String
    var color: Color = .tMine
    var size: CGFloat = 31

    var body: some View {
        Text(String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.leona(size * 0.39, .heavy))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
    }
}

// MARK: - Sub-screen header ("‹ Thread · Title · meta")

struct SubScreenHeader: View {
    let title: String
    var meta: String = ""
    var backTitle: String = String(localized: "thread_back")
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .heavy))
                    Text(backTitle)
                        .font(.leona(15, .bold))
                }
                .foregroundStyle(.vermilion)
                .frame(width: 96, alignment: .leading)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.leona(16, .bold))
                .leonaTracking(-0.02, size: 16)
                .foregroundStyle(.tInk)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Text(meta)
                .font(.leona(12, .bold))
                .foregroundStyle(.tMuted)
                .lineLimit(1)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.tLine).frame(height: 1) }
    }
}

// MARK: - Simple bar chart (milk per day, sleep night vs naps)

struct LeonaBarItem: Identifiable {
    let id = UUID()
    let label: String
    /// Stacked segments, bottom first.
    let segments: [(value: Double, color: Color)]
    var total: Double { segments.reduce(0) { $0 + $1.value } }
}

struct LeonaBarChart: View {
    let items: [LeonaBarItem]
    var barHeight: CGFloat = 94
    var maxValue: Double? = nil

    var body: some View {
        let peak = max(maxValue ?? items.map(\.total).max() ?? 1, 0.0001)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(items) { item in
                VStack(spacing: 6) {
                    VStack(spacing: 0) {
                        ForEach(Array(item.segments.enumerated().reversed()), id: \.offset) { index, segment in
                            let h = CGFloat(segment.value / peak) * barHeight
                            let isTop = index == item.segments.count - 1
                            let isBottom = index == 0
                            UnevenRoundedRectangle(
                                topLeadingRadius: isTop ? 6 : 0,
                                bottomLeadingRadius: isBottom ? 2 : 0,
                                bottomTrailingRadius: isBottom ? 2 : 0,
                                topTrailingRadius: isTop ? 6 : 0,
                                style: .continuous
                            )
                            .fill(segment.color)
                            .frame(height: max(h, segment.value > 0 ? 2 : 0))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    Text(item.label)
                        .font(.leona(10, .bold))
                        .foregroundStyle(.tMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(height: barHeight + 22, alignment: .bottom)
    }
}

// MARK: - Toast

struct LeonaToastModifier: ViewModifier {
    @Binding var message: String?
    var bottomPadding: CGFloat = 132

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.leona(14, .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.tToast)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 15, y: 12)
                    .padding(.horizontal, 22)
                    .padding(.bottom, bottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .id(message)
            }
        }
        .animation(.easeOut(duration: 0.18), value: message)
    }
}

extension View {
    func leonaToast(_ message: Binding<String?>, bottomPadding: CGFloat = 132) -> some View {
        modifier(LeonaToastModifier(message: message, bottomPadding: bottomPadding))
    }
}

// MARK: - Screen chrome

extension View {
    /// Canvas background and hidden system navigation bar shared by every screen.
    func leonaScreen() -> some View {
        self
            .background(Color.tCanvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
    }
}

/// Coloured tick used on the left of a log bubble or list row.
struct ColorTick: View {
    let color: Color
    var height: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 4, height: height)
    }
}

/// Pulsing dot for running sessions.
struct PulseDot: View {
    let color: Color
    var size: CGFloat = 8
    var period: Double = 1.8
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(on ? 1 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
