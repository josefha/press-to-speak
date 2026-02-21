import PressToSpeakCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Section("PressToSpeak Account") {
                if viewModel.isAccountAuthenticated {
                    Text(viewModel.signedInAccountLabel)
                        .foregroundStyle(.secondary)

                    Button("Sign Out") {
                        viewModel.signOutFromPressToSpeakAccount()
                    }
                } else {
                    Text("Account login and creation are in the dashboard account box.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Hotkey")
                Spacer()
                Text(viewModel.activeShortcutLabel)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if viewModel.isCapturingHotkey {
                    Button("Cancel Hotkey Update") {
                        viewModel.cancelHotkeyUpdate()
                    }
                } else {
                    Button("Update Hotkey") {
                        viewModel.beginHotkeyUpdate()
                    }
                }
                Text(viewModel.hotkeyCaptureHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Locale (optional)", text: $viewModel.settingsStore.settings.locale)

            VStack(alignment: .leading, spacing: 8) {
                Text("Default System Prompt")
                TextEditor(text: $viewModel.settingsStore.settings.defaultSystemPrompt)
                    .frame(minHeight: 80)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("User Context")
                TextEditor(text: $viewModel.settingsStore.settings.userContext)
                    .frame(minHeight: 80)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Vocabulary Hints (comma or newline separated)")
                TextEditor(text: $viewModel.settingsStore.settings.vocabularyHintText)
                    .frame(minHeight: 80)
                    .font(.body)
            }
        }
        .formStyle(.grouped)
    }
}
