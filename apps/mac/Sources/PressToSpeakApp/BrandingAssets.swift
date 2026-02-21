import AppKit
import SwiftUI

enum BrandingAssets {
    private static let brandingSubdirectory = "Branding"

    private static let lightLogo = loadImage(named: "logo-light", template: false)
    private static let darkLogo = loadImage(named: "logo-dark", template: false)
    private static let menuBarTemplateLogo = loadImage(named: "logo-dark", template: true)

    static func dashboardLogo(for colorScheme: ColorScheme) -> Image? {
        switch colorScheme {
        case .dark:
            return lightLogo
        default:
            return darkLogo
        }
    }

    static func menuBarLogo() -> Image? {
        return menuBarTemplateLogo
    }

    private static func loadImage(named name: String, template: Bool) -> Image? {
        guard
            let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: brandingSubdirectory),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.isTemplate = template
        return Image(nsImage: image)
    }
}
