import CoreText
import SwiftUI

enum BrandFontLoader {
    private static var didRegister = false
    private static let fontFiles = [
        "Geist[wght].ttf",
        "Outfit[wght].ttf"
    ]

    static func registerIfNeeded(bundle: Bundle = .module) {
        guard !didRegister else { return }
        didRegister = true

        for fileName in fontFiles {
            guard let url = bundle.url(forResource: fileName, withExtension: nil, subdirectory: "Fonts") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

enum AppTypography {
    static func body(size: CGFloat = 14) -> Font {
        Font.custom("Geist", size: size)
    }

    static func bodyMedium(size: CGFloat = 14) -> Font {
        Font.custom("Geist", size: size).weight(.medium)
    }

    static func bodySemibold(size: CGFloat = 14) -> Font {
        Font.custom("Geist", size: size).weight(.semibold)
    }

    static func bodyBold(size: CGFloat = 14) -> Font {
        Font.custom("Geist", size: size).weight(.bold)
    }

    static func brandHeading(size: CGFloat) -> Font {
        Font.custom("Outfit", size: size).weight(.semibold)
    }

    static func brandBody(size: CGFloat = 14) -> Font {
        Font.custom("Outfit", size: size).weight(.medium)
    }
}

enum AppPalette {
    static let canvas = LinearGradient(
        colors: [Color(hex: 0xF4EFE9), Color(hex: 0xF8F3EC)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let brandTop = Color(hex: 0x2C2C31)
    static let brandBottom = Color(hex: 0x18181B)

    static let ink = Color(hex: 0x18181B)
    static let onInk = Color(hex: 0xFFFFEB)
    static let mutedText = Color(hex: 0x6D665D)

    static let card = Color(hex: 0xFFFDF7)
    static let softBlue = Color(hex: 0xECE6DD)
    static let softGray = Color(hex: 0xF6EFE5)
    static let border = Color(hex: 0xDDD3C7)
    static let borderStrong = Color(hex: 0xCEC1B4)

    static let success = Color(hex: 0x2E9C73)
    static let successSoft = Color(hex: 0xE6F4ED)
    static let warning = Color(hex: 0xC98524)
    static let warningSoft = Color(hex: 0xFBEFD9)
    static let error = Color(hex: 0xC56B70)
    static let errorSoft = Color(hex: 0xFBECEE)
}

enum AppMetrics {
    static let buttonMinHeight: CGFloat = 40
    static let buttonCornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 18
}

struct BrandPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodySemibold())
            .foregroundStyle(AppPalette.onInk.opacity(isEnabled ? 1.0 : 0.72))
            .padding(.horizontal, 14)
            .frame(minHeight: AppMetrics.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.buttonCornerRadius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.buttonCornerRadius, style: .continuous)
                    .stroke(AppPalette.ink.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return AppPalette.ink.opacity(0.5)
        }
        return isPressed ? AppPalette.brandTop : AppPalette.ink
    }
}

struct BrandSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodySemibold())
            .foregroundStyle(AppPalette.ink.opacity(isEnabled ? 1.0 : 0.58))
            .padding(.horizontal, 14)
            .frame(minHeight: AppMetrics.buttonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: AppMetrics.buttonCornerRadius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.buttonCornerRadius, style: .continuous)
                    .stroke(AppPalette.borderStrong, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if !isEnabled {
            return AppPalette.softGray.opacity(0.7)
        }
        return isPressed ? AppPalette.softBlue : AppPalette.card
    }
}

extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: BrandPrimaryButtonStyle { .init() }
}

extension ButtonStyle where Self == BrandSecondaryButtonStyle {
    static var brandSecondary: BrandSecondaryButtonStyle { .init() }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppPalette.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCornerRadius, style: .continuous))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

private extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
