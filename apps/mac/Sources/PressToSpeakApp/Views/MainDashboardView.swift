import PressToSpeakCore
import PressToSpeakInfra
import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showPrevious = false

    private let websiteURL = URL(string: "https://press-to-speak-jes3r9liz-josef-karakocas-projects.vercel.app")!

    var body: some View {
        ZStack {
            AppPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection
                    quickActionsSection
                    latestTranscriptionSection
                    previousTranscriptionsSection
                    settingsSection
                    permissionSection
                }
                .padding(22)
            }
        }
        .frame(minWidth: 820, minHeight: 700)
        .onAppear {
            viewModel.refreshAccessibilityPermission()
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.brandTop, AppPalette.brandBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "waveform.and.mic")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PressToSpeak")
                        .font(.title2.weight(.semibold))
                    Text("Hold to record. Release to transcribe and paste anywhere.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Link(destination: websiteURL) {
                    Image(systemName: "globe")
                        .font(.callout.weight(.medium))
                        .padding(9)
                        .background(AppPalette.softBlue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Open website")
            }

            HStack(spacing: 10) {
                Label(viewModel.statusLabel, systemImage: statusIcon)
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(statusColor.opacity(0.14))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(viewModel.hotkeyCaptureHelpText)
                        .font(.callout)
                        .foregroundStyle(viewModel.isCapturingHotkey ? AppPalette.warning : .secondary)

                    Spacer()

                    if viewModel.isCapturingHotkey {
                        Button("Cancel") {
                            viewModel.cancelHotkeyUpdate()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Update Hotkey") {
                            viewModel.beginHotkeyUpdate()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppPalette.brandBottom)
                    }
                }

                if viewModel.isCapturingHotkey {
                    Text("Press one key or a key combo, for example ⌘ + ,")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    viewModel.startCapture()
                } label: {
                    Label("Start Recording", systemImage: "mic.fill")
                        .padding(.horizontal, 6)
                        .frame(minHeight: 34)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppPalette.brandBottom)

                Button {
                    viewModel.finishCapture()
                } label: {
                    Label("Stop + Transcribe", systemImage: "waveform")
                        .padding(.horizontal, 6)
                        .frame(minHeight: 34)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()
            }

            if !viewModel.lastError.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(viewModel.lastError)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .cardStyle()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription Settings")
                .font(.headline)

            Picker("API Mode", selection: $viewModel.settingsStore.settings.apiMode) {
                ForEach(viewModel.availableAPIModes) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if !viewModel.showAdvancedModeOptions {
                Button("Show Advanced Mode (Bring Your Own Keys)") {
                    viewModel.showAdvancedModeOptions = true
                }
                .buttonStyle(.bordered)
            }

            if viewModel.settingsStore.settings.apiMode == .pressToSpeakAccount {
                accountModeSettings
            } else {
                byokModeSettings
            }

            TextField("Locale (optional)", text: $viewModel.settingsStore.settings.locale)
                .textFieldStyle(.roundedBorder)

            textArea(
                title: "Default System Prompt",
                text: $viewModel.settingsStore.settings.defaultSystemPrompt,
                minHeight: 92
            )

            textArea(
                title: "User Context",
                text: $viewModel.settingsStore.settings.userContext,
                minHeight: 92
            )

            textArea(
                title: "Vocabulary Hints",
                text: $viewModel.settingsStore.settings.vocabularyHintText,
                minHeight: 80
            )
        }
        .cardStyle()
    }

    private var accountModeSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PressToSpeak Account")
                .font(.subheadline.weight(.semibold))
            Text(viewModel.signedInAccountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.isSupabaseConfigured {
                            Text("Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY in app environment.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if viewModel.isAccountAuthenticated {
                Button("Sign Out") {
                    viewModel.signOutFromPressToSpeakAccount()
                }
                .buttonStyle(.bordered)
            } else {
                TextField("Email", text: $viewModel.accountEmailInput)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password", text: $viewModel.accountPasswordInput)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Button("Sign In") {
                        viewModel.signInWithPressToSpeakAccount()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAuthInProgress)

                    Button("Sign Up") {
                        viewModel.signUpWithPressToSpeakAccount()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isAuthInProgress)
                }
            }
        }
        .padding(10)
        .background(AppPalette.softGray)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var byokModeSettings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bring Your Own Keys")
                .font(.subheadline.weight(.semibold))
            Text("Advanced mode. Your keys are stored in macOS Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("OpenAI API Key", text: $viewModel.bringYourOwnOpenAIKeyInput)
                .textFieldStyle(.roundedBorder)
            SecureField("ElevenLabs API Key", text: $viewModel.bringYourOwnElevenLabsKeyInput)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Save Keys") {
                    viewModel.saveBringYourOwnProviderKeys()
                }
                .buttonStyle(.borderedProminent)

                Button("Clear Keys") {
                    viewModel.clearBringYourOwnProviderKeys()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(AppPalette.softGray)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var latestTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Latest transcription")
                    .font(.headline)
                Spacer()

                if let latest = viewModel.historyItems.first {
                    Button {
                        viewModel.copyToClipboard(latest.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .help("Copy latest transcription")
                }
            }

            if let latest = viewModel.historyItems.first {
                Text(latest.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppPalette.softGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("No transcriptions yet.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(showPrevious ? "Hide Previous" : "View Previous") {
                    showPrevious.toggle()
                }
                .buttonStyle(.bordered)

                if !viewModel.historyItems.isEmpty {
                    Button("Clear History") {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var previousTranscriptionsSection: some View {
        if showPrevious {
            VStack(alignment: .leading, spacing: 10) {
                Text("Previous")
                    .font(.headline)

                if viewModel.historyItems.dropFirst().isEmpty {
                    Text("No previous entries yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.historyItems.dropFirst().prefix(30))) { item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(item.text)
                                    .lineLimit(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                viewModel.copyToClipboard(item.text)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .help("Copy this transcription")
                        }
                        .padding(11)
                        .background(AppPalette.softGray)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .cardStyle()
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Permissions")
                .font(.headline)

            Text(
                viewModel.hasAccessibilityPermission
                ? "Accessibility is granted."
                : "Accessibility is required for global hotkey and paste."
            )
            .foregroundStyle(viewModel.hasAccessibilityPermission ? AppPalette.success : AppPalette.warning)

            HStack(spacing: 10) {
                Button("Grant Accessibility") {
                    viewModel.requestAccessibilityPermissionPrompt()
                }
                .buttonStyle(.bordered)

                Button("Refresh") {
                    viewModel.refreshAccessibilityPermission()
                }
                .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }

    private func textArea(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle:
            return AppPalette.success
        case .recording:
            return .red
        case .transcribing:
            return AppPalette.warning
        case .error:
            return .red
        }
    }

    private var statusIcon: String {
        switch viewModel.status {
        case .idle:
            return "checkmark.circle.fill"
        case .recording:
            return "mic.circle.fill"
        case .transcribing:
            return "waveform.circle.fill"
        case .error:
            return "xmark.circle.fill"
        }
    }
}

private enum AppPalette {
    static let canvas = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.99, blue: 1.0),
            Color(red: 0.965, green: 0.98, blue: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let brandTop = Color(red: 0.26, green: 0.57, blue: 0.99)
    static let brandBottom = Color(red: 0.13, green: 0.41, blue: 0.95)
    static let softBlue = Color(red: 0.90, green: 0.95, blue: 1.0)
    static let softGray = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let border = Color(red: 0.87, green: 0.90, blue: 0.94)
    static let success = Color(red: 0.15, green: 0.55, blue: 0.30)
    static let warning = Color(red: 0.82, green: 0.52, blue: 0.14)
}

private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
