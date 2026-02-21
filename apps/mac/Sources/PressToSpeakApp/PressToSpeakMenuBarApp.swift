import SwiftUI

@main
struct PressToSpeakMenuBarApp: App {
    @StateObject private var viewModel = AppViewModel()

    init() {
        BrandFontLoader.registerIfNeeded()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: viewModel)
        } label: {
            if let logo = BrandingAssets.menuBarLogo() {
                logo
                    .renderingMode(.template)
                    .accessibilityLabel(Text("PressToSpeak"))
            } else {
                Image(systemName: viewModel.statusSymbol)
                    .accessibilityLabel(Text("PressToSpeak"))
            }
        }

        Window("PressToSpeak", id: "main-dashboard") {
            MainDashboardView(viewModel: viewModel)
                .frame(minWidth: 780, minHeight: 680)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 900, height: 760)
    }
}
