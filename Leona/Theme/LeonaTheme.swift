import SwiftUI
import UIKit

// MARK: - Leona Thread v2 palette
//
// Five colours carry meaning and never swap roles:
//   plum      – structure and the parent's own bubbles
//   vermilion – action and Leona herself
//   lilac     – sleep, nothing else
//   moss      – diapers, nothing else
//   canvas    – the page
// Every token below has a light and a dark value; the colour scheme picks one.

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A colour that resolves against the current colour scheme.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // Fixed brand colours
    static let vermilion = Color(hex: 0xE24E2B)
    static let vermilionDark = Color(hex: 0xC13F1C)
    static let lilac = Color(hex: 0x8A73C4)
    static let moss = Color(hex: 0x2F7A5A)
    static let highlight = Color(hex: 0xFF9A7A)
    static let noteGrey = Color(hex: 0x9A8FA6)
    static let plumFixed = Color(hex: 0x33224A)

    // Theme tokens (light / dark)
    static let tCanvas = Color(light: 0xF5F3F4, dark: 0x191223)
    static let tSurface = Color(light: 0xFFFFFF, dark: 0x231A31)
    static let tInk = Color(light: 0x1C1520, dark: 0xF2EEF5)
    static let tMuted = Color(light: 0x6F6577, dark: 0x9A8FA6)
    static let tLine = Color(light: 0xE4DFE5, dark: 0x312643)
    static let tMine = Color(light: 0x33224A, dark: 0x5B3E86)
    static let tTheirs = Color(light: 0xEDE9EC, dark: 0x271D37)
    static let tTheirsInk = Color(light: 0x1C1520, dark: 0xEBE5F1)
    static let tLeonaBg = Color(light: 0xFDEDE7, dark: 0x2C1D1A)
    static let tLeonaLine = Color(light: 0xF7D6C7, dark: 0x5B3628)
    static let tLeonaInk = Color(light: 0xB93C18, dark: 0xF0A583)
    static let tChip = Color(light: 0xEDE9EC, dark: 0x271D37)
    static let tTray = Color(light: 0xEFEDEE, dark: 0x1F1730)
    static let tPinned = Color(light: 0xEDE9EC, dark: 0x231A31)
    static let tAvatar = Color(light: 0xB3A9BC, dark: 0x5C4E70)
    static let tToast = Color(light: 0x33224A, dark: 0x5B3E86)
    static let tBandFill = Color(light: 0xE8E3EC, dark: 0x2A2140)
    static let tP50 = Color(light: 0x9C93A6, dark: 0x7A6C90)
    static let tToggleOff = Color(hex: 0xC9C2CE)
    static let tDisabled = Color(hex: 0xA99AB4)

    // Running-session bubbles in the thread
    static let sleepBubbleBg = Color(hex: 0x2B2140)
    static let sleepBubbleInk = Color(hex: 0xEDE7F6)
    static let sleepBubbleSub = Color(hex: 0xA796CE)
    static let breastBubbleBg = Color(hex: 0x4A1F14)
    static let breastBubbleInk = Color(hex: 0xFFE7DE)
    static let breastBubbleSub = Color(hex: 0xE0A288)
    static let breastDot = Color(hex: 0xFF7A55)

    // Trends chart colours
    static let chartNight = Color(hex: 0x4C3A75)
    static let chartDay = Color(hex: 0xB9A9DE)

    // Legacy alias kept for the sleep colour used by ActivityType
    static var leonaSleep: Color { .lilac }
}

/// The dark plum world of the live sleep session.
enum SleepTheme {
    static let bg = Color(hex: 0x171122)
    static let ink = Color(hex: 0xEDE7F6)
    static let muted = Color(hex: 0x8C81A4)
    static let surface = Color(hex: 0x241B36)
    static let track = Color(hex: 0x332748)
    static let marker = Color(hex: 0x5B4C7A)
    static let body = Color(hex: 0xB0A5C6)
    static let back = Color(hex: 0xB9A9DE)
    static let accent = Color.lilac
}

/// The warm rust world of the live breastfeeding session.
enum BreastTheme {
    static let bg = Color(hex: 0x22110D)
    static let ink = Color(hex: 0xFFEDE5)
    static let muted = Color(hex: 0xA88476)
    static let surface = Color(hex: 0x3A1A13)
    static let sideOff = Color(hex: 0x31150F)
    static let sideLine = Color(hex: 0x4A2419)
    static let sideInk = Color(hex: 0xC08D78)
    static let sideSub = Color(hex: 0x8A6353)
    static let accent = Color(hex: 0xF0A583)
    static let value = Color(hex: 0xE0A288)
}

// MARK: - ShapeStyle sugar so `.foregroundStyle(.tMuted)` reads like the design

extension ShapeStyle where Self == Color {
    static var vermilion: Color { .vermilion }
    static var lilac: Color { .lilac }
    static var moss: Color { .moss }
    static var highlight: Color { .highlight }
    static var tCanvas: Color { .tCanvas }
    static var tSurface: Color { .tSurface }
    static var tInk: Color { .tInk }
    static var tMuted: Color { .tMuted }
    static var tLine: Color { .tLine }
    static var tMine: Color { .tMine }
    static var tTheirs: Color { .tTheirs }
    static var tTheirsInk: Color { .tTheirsInk }
    static var tLeonaBg: Color { .tLeonaBg }
    static var tLeonaLine: Color { .tLeonaLine }
    static var tLeonaInk: Color { .tLeonaInk }
    static var tChip: Color { .tChip }
    static var tTray: Color { .tTray }
    static var tPinned: Color { .tPinned }
    static var tAvatar: Color { .tAvatar }
    static var tToast: Color { .tToast }
    static var leonaSleep: Color { .lilac }
}

// MARK: - Typography
//
// The design uses Instrument Sans. The system font is used here so nothing has to be
// bundled; sizes, weights and tracking follow the design pixel for pixel.

extension Font {
    static func leona(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

extension View {
    /// Letter-spacing expressed in em, as the design writes it.
    func leonaTracking(_ em: Double, size: CGFloat) -> some View {
        tracking(em * size)
    }
}

// MARK: - Shapes

extension Shape where Self == UnevenRoundedRectangle {
    /// A bubble sitting on the left of the thread (their entries, Leona's lines).
    static var theirsBubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 6, bottomTrailingRadius: 20, topTrailingRadius: 20, style: .continuous)
    }

    /// A bubble sitting on the right of the thread (the parent's own entries).
    static var mineBubble: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, bottomTrailingRadius: 6, topTrailingRadius: 20, style: .continuous)
    }
}

// MARK: - Press feedback

struct LeonaPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LeonaPressStyle {
    static var leonaPress: LeonaPressStyle { LeonaPressStyle() }
}
