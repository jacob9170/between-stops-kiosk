import SwiftUI

/// Colours lifted straight from the Between Stops phone app so both feel like one product.
enum K {
    static let ink = Color(hex: 0x182033)
    static let ink2 = Color(hex: 0x222B40)
    static let yellow = Color(hex: 0xFFC72C)
    static let yellowDeep = Color(hex: 0xE0A800)
    static let blue = Color(hex: 0x2D5BA8)
    static let grey = Color(hex: 0xE9ECF1)
    static let bg = Color(hex: 0xF4F6F9)
    static let muted = Color(hex: 0x5E6779)
    static let line = Color(hex: 0xD7DCE4)
    static let green = Color(hex: 0x2E7D5B)
    static let greenSoft = Color(hex: 0xDFF0E7)
    static let red = Color(hex: 0xC2402A)
    static let cream = Color(hex: 0xFFF7DD)
    static let held = Color(hex: 0xFFF1C7)
    static let t1 = Color(hex: 0xF28C1E)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension Font {
    /// Sans text that respects the kiosk's "Larger text" setting.
    @MainActor static func k(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * KioskStore.shared.textScale, weight: weight)
    }
    /// Serif for book titles, standing in for Newsreader on the phone.
    @MainActor static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size * KioskStore.shared.textScale, weight: weight, design: .serif)
    }
}

/// Big, squishy kiosk button. Every press also resets the idle timer.
struct KioskButtonStyle: ButtonStyle {
    enum Kind { case yellow, ink, ghost, ghostDark, white, danger }
    var kind: Kind = .yellow
    var height: CGFloat = 72

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.k(22, .bold))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .foregroundStyle(fg)
            .background(bg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                if kind == .ghost || kind == .ghostDark {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(kind == .ghost ? K.line : .white.opacity(0.25), lineWidth: 2)
                }
            }
            .shadow(color: kind == .yellow ? K.yellowDeep.opacity(configuration.isPressed ? 0.15 : 0.35) : .clear,
                    radius: configuration.isPressed ? 4 : 14, y: configuration.isPressed ? 2 : 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, _ in KioskStore.shared.touch() }
    }

    private var fg: Color {
        switch kind {
        case .yellow, .ghost, .white: K.ink
        case .ink, .danger, .ghostDark: .white
        }
    }
    private var bg: Color {
        switch kind {
        case .yellow: K.yellow
        case .ink: K.ink
        case .ghost, .ghostDark: .clear
        case .white: .white
        case .danger: K.red
        }
    }
}

/// Plain press feedback for tiles and cards.
struct PressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, _ in KioskStore.shared.touch() }
    }
}

/// Shake animation for wrong codes / rejected passes.
struct Shake: GeometryEffect {
    var travel: CGFloat = 14
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * 6), y: 0))
    }
}

struct Pill: View {
    let text: String
    var fg: Color = K.ink
    var bg: Color = .white
    var body: some View {
        Text(text)
            .font(.k(15, .bold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}

struct LinePill: View {
    var size: CGFloat = 44
    var body: some View {
        Text("T1")
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(K.ink)
            .frame(width: size, height: size)
            .background(K.t1, in: RoundedRectangle(cornerRadius: size * 0.27, style: .continuous))
    }
}

/// The three-bar Between Stops logo mark.
struct LogoMark: View {
    var size: CGFloat = 56
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
            .fill(K.ink)
            .overlay(RoundedRectangle(cornerRadius: size * 0.29, style: .continuous).stroke(.white.opacity(0.14), lineWidth: 1))
            .frame(width: size, height: size)
            .overlay {
                HStack(alignment: .bottom, spacing: size * 0.036) {
                    RoundedRectangle(cornerRadius: size * 0.03).fill(K.yellow).frame(width: size * 0.11, height: size * 0.36)
                    RoundedRectangle(cornerRadius: size * 0.03).fill(.white).frame(width: size * 0.11, height: size * 0.30)
                    RoundedRectangle(cornerRadius: size * 0.03).fill(K.blue).frame(width: size * 0.11, height: size * 0.38)
                }
                .offset(y: size * 0.02)
            }
    }
}
