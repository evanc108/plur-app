import SwiftUI

// MARK: - Color Tokens

extension Color {
    // Core
    static let plurVoid = Color(hex: "080808")
    static let plurSurface = Color(hex: "111111")
    static let plurSurface2 = Color(hex: "1A1A1A")
    static let plurLift = Color(hex: "222222")

    // Text
    static let plurGhost = Color(hex: "F0F0F0")
    static let plurMuted = Color(hex: "8A8A8A")
    static let plurFaint = Color(hex: "555555")

    // Accents
    static let plurRose = Color(hex: "C0607A")
    static let plurViolet = Color(hex: "7B5EA7")
    static let plurTeal = Color(hex: "3D8A7A")
    static let plurAmber = Color(hex: "C47B3A")

    // Glass
    static let plurGlass = Color.white.opacity(0.06)
    static let plurGlassHeavy = Color.white.opacity(0.10)
    static let plurBorder = Color.white.opacity(0.08)
    static let plurBorderGlass = Color.white.opacity(0.12)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

// MARK: - Font Tokens

extension Font {
    static func plurDisplay(_ size: CGFloat = 42) -> Font {
        .custom("Syne-ExtraBold", size: size)
    }
    static func plurHeading(_ size: CGFloat = 28) -> Font {
        .custom("Syne-ExtraBold", size: size)
    }
    static func plurH2(_ size: CGFloat = 20) -> Font {
        .custom("Syne-Bold", size: size)
    }
    static func plurH3(_ size: CGFloat = 16) -> Font {
        .custom("Syne-Bold", size: size)
    }
    static func plurBody(_ size: CGFloat = 15) -> Font {
        .custom("DMSans-Regular", size: size)
    }
    static func plurBodyBold(_ size: CGFloat = 15) -> Font {
        .custom("DMSans-SemiBold", size: size)
    }
    static func plurCaption(_ size: CGFloat = 12) -> Font {
        .custom("DMSans-Regular", size: size)
    }
    static func plurMicro(_ size: CGFloat = 10) -> Font {
        .custom("DMSans-SemiBold", size: size)
    }
    static func plurTiny(_ size: CGFloat = 9) -> Font {
        .custom("DMSans-Medium", size: size)
    }
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Corner Radii

enum Radius {
    static let pill: CGFloat = 100
    static let card: CGFloat = 20
    static let innerCard: CGFloat = 16
    static let tab: CGFloat = 14
    static let activeTab: CGFloat = 11
    static let thumbnail: CGFloat = 12
}

// MARK: - Gradients

extension LinearGradient {
    static let plurRankGradient = LinearGradient(
        colors: [.plurViolet, .plurRose],
        startPoint: .leading, endPoint: .trailing
    )
    static let plurAvatarRing = LinearGradient(
        colors: [.plurViolet, .plurRose, .plurTeal],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let plurHeroFade = LinearGradient(
        colors: [.clear, .plurVoid],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Glass Card

struct GlassCard<Content: View>: View {
    var tint: Color?
    var padding: CGFloat = Spacing.md
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Radius.card)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card)
                            .fill(tint?.opacity(0.08) ?? Color.plurGlass)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .stroke(
                        tint?.opacity(0.15) ?? Color.plurBorder,
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - PLUR Button Style

struct PLURButtonStyle: ButtonStyle {
    var color: Color = .plurViolet

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.plurBodyBold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(color, in: RoundedRectangle(cornerRadius: Radius.pill))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Dark Scroll Background

extension View {
    func plurBackground() -> some View {
        self
            .background(Color.plurVoid)
            .preferredColorScheme(.dark)
    }

    func glassField() -> some View {
        self
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(Color.plurSurface2, in: RoundedRectangle(cornerRadius: Radius.thumbnail))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.thumbnail)
                    .stroke(Color.plurBorder, lineWidth: 1)
            )
    }
}
