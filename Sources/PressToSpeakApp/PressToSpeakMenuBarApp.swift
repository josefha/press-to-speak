import SwiftUI

@main
struct PressToSpeakMenuBarApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("PressToSpeak", systemImage: viewModel.statusSymbol) {
            MenuBarContentView(viewModel: viewModel)
        }

        Window("PressToSpeak", id: "main-dashboard") {
            MainDashboardView(viewModel: viewModel)
                .frame(minWidth: 780, minHeight: 680)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 900, height: 760)
    }
}
