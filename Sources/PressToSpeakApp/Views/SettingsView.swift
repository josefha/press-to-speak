import PressToSpeakCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    private var shortcutBinding: Binding<ActivationShortcut> {
        Binding(
            get: { viewModel.settingsStore.settings.activationShortcutValue },
            set: { viewModel.settingsStore.settings.activationShortcutValue = $0 }
        )
    }

    var body: some View {
        Form {
            Picker("API Mode", selection: $viewModel.settingsStore.settings.apiMode) {
                ForEach(APIMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            Picker("Activation Shortcut", selection: shortcutBinding) {
                ForEach(ActivationShortcut.allCases) { shortcut in
                    Text(shortcut.label).tag(shortcut)
                }
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
