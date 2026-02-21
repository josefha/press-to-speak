import PressToSpeakCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Form {
            Picker("API Mode", selection: $viewModel.settingsStore.settings.apiMode) {
                ForEach(viewModel.availableAPIModes) { mode in
                    Text(mode.label).tag(mode)
                }
            }

            if !viewModel.showAdvancedModeOptions {
                Button("Show Advanced Mode (Bring Your Own Keys)") {
                    viewModel.showAdvancedModeOptions = true
                }
            }

            if viewModel.settingsStore.settings.apiMode == .pressToSpeakAccount {
                Section("PressToSpeak Account") {
                    Text(viewModel.signedInAccountLabel)
                        .foregroundStyle(.secondary)

                    if !viewModel.isSupabaseConfigured {
                        Text("Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY in app environment.")
                            .foregroundStyle(.red)
                    }

                    if viewModel.isAccountAuthenticated {
                        Button("Sign Out") {
                            viewModel.signOutFromPressToSpeakAccount()
                        }
                    } else {
                        TextField("Email", text: $viewModel.accountEmailInput)
                        SecureField("Password", text: $viewModel.accountPasswordInput)

                        HStack {
                            Button("Sign In") {
                                viewModel.signInWithPressToSpeakAccount()
                            }
                            .disabled(viewModel.isAuthInProgress)

                            Button("Sign Up") {
                                viewModel.signUpWithPressToSpeakAccount()
                            }
                            .disabled(viewModel.isAuthInProgress)
                        }
                    }
                }
            } else {
                Section("Bring Your Own Keys") {
                    Text("Advanced mode. Keys are stored in macOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField("OpenAI API Key", text: $viewModel.bringYourOwnOpenAIKeyInput)
                    SecureField("ElevenLabs API Key", text: $viewModel.bringYourOwnElevenLabsKeyInput)

                    HStack {
                        Button("Save Keys") {
                            viewModel.saveBringYourOwnProviderKeys()
                        }
                        Button("Clear Keys") {
                            viewModel.clearBringYourOwnProviderKeys()
                        }
                    }
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
