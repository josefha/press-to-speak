import SwiftUI

@main
struct PressToSpeakMenuBarApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra("PressToSpeak", systemImage: viewModel.statusSymbol) {
            MenuBarContentView(viewModel: viewModel)
        }

        Settings {
            SettingsView(viewModel: viewModel)
                .padding(20)
                .frame(width: 580)
        }
    }
}
