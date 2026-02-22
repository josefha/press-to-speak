import PressToSpeakCore
import PressToSpeakInfra
import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showPrevious = false
    @State private var currentPage: DashboardPage = .home
    @Environment(\.colorScheme) private var colorScheme

    private let websiteURL = URL(string: "https://www.presstospeak.com/")!

    var body: some View {
        ZStack {
            AppPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection

                    if currentPage == .home {
                        homePageContent
                    } else {
                        settingsPageContent
                    }
                }
                .padding(22)
            }
        }
        .font(AppTypography.body())
        .foregroundStyle(AppPalette.ink)
        .frame(minWidth: 820, minHeight: 700)
        .onAppear {
            viewModel.refreshUIStateOnOpen()
        }
    }

    private enum DashboardPage: String, CaseIterable {
        case home
        case settings

        var title: String {
            switch self {
            case .home:
                return "Home"
            case .settings:
                return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .home:
                return "house"
            case .settings:
                return "gearshape"
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Group {
                    if let logo = BrandingAssets.dashboardLogo(for: colorScheme) {
                        logo
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    } else {
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
                                .foregroundStyle(AppPalette.onInk)
                        }
                    }
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text("PressToSpeak")
                        .font(AppTypography.brandHeading(size: 34))
                    Text("Hold to record. Release to transcribe and paste anywhere.")
                        .font(AppTypography.body(size: 14))
                        .foregroundStyle(AppPalette.mutedText)
                }

                Spacer()

                Link(destination: websiteURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.callout.weight(.medium))
                        Text("Website")
                            .font(AppTypography.bodySemibold(size: 13))
                    }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .foregroundStyle(AppPalette.ink)
                        .background(AppPalette.softBlue)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppPalette.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Open website")
            }

            HStack(spacing: 10) {
                Label(viewModel.statusLabel, systemImage: statusIcon)
                    .font(AppTypography.bodyMedium(size: 14))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(statusBackgroundColor)
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())

                Text("Hotkey: \(viewModel.activeShortcutLabel)")
                    .font(AppTypography.bodyMedium(size: 13))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(AppPalette.softGray)
                    .foregroundStyle(AppPalette.ink)
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                ForEach(DashboardPage.allCases, id: \.self) { page in
                    Button {
                        currentPage = page
                    } label: {
                        Label(page.title, systemImage: page.systemImage)
                            .font(AppTypography.bodySemibold(size: 13))
                            .foregroundStyle(page == currentPage ? AppPalette.onInk.opacity(0.95) : AppPalette.mutedText)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(page == currentPage ? Color(red: 0.64, green: 0.63, blue: 0.61) : AppPalette.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(page == currentPage ? Color.clear : AppPalette.borderStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .cardStyle()
    }

    private var accountAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Account")
                    .font(AppTypography.brandHeading(size: 22))
                Spacer()
            }

            if viewModel.isAccountAuthenticated {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppPalette.softBlue)
                        Text(viewModel.accountProfileInitial)
                            .font(AppTypography.brandHeading(size: 20))
                            .foregroundStyle(AppPalette.ink)
                    }
                    .frame(width: 42, height: 42)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.accountProfileName)
                            .font(AppTypography.bodySemibold(size: 14))

                        HStack(spacing: 8) {
                            if !viewModel.accountProfileEmail.isEmpty {
                                Text(viewModel.accountProfileEmail)
                                    .font(AppTypography.body(size: 12))
                                    .foregroundStyle(AppPalette.mutedText)
                            }

                            Text(viewModel.accountTierLabel)
                                .font(AppTypography.bodySemibold(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AppPalette.softGray)
                                .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    Button("Sign Out") {
                        viewModel.signOutFromPressToSpeakAccount()
                    }
                    .buttonStyle(.brandSecondary)
                }
            } else {
                Text("A free PressToSpeak account is required to use transcription.")
                    .font(AppTypography.body(size: 14))
                Text("Create an account or log in to continue.")
                    .font(AppTypography.body(size: 14))
                    .foregroundStyle(AppPalette.mutedText)

                if !viewModel.isAccountAuthConfigured {
                    Text("Missing TRANSCRIPTION_PROXY_URL in app environment.")
                        .font(AppTypography.body(size: 12))
                        .foregroundStyle(AppPalette.error)
                }

                if viewModel.shouldShowAccountAuthForm {
                    TextField("Email", text: $viewModel.accountEmailInput)
                        .dashboardTextInputStyle()
                    SecureField("Password", text: $viewModel.accountPasswordInput)
                        .dashboardTextInputStyle()

                    HStack(spacing: 10) {
                        Button(viewModel.isCreateAccountFlow ? "Create Account" : "Log In") {
                            viewModel.submitCurrentAccountFlow()
                        }
                        .buttonStyle(.brandPrimary)
                        .disabled(viewModel.isAuthInProgress)

                        Button("Cancel") {
                            viewModel.cancelAccountFlow()
                        }
                        .buttonStyle(.brandSecondary)
                        .disabled(viewModel.isAuthInProgress)
                    }
                } else {
                    HStack(spacing: 10) {
                        Button("Create Free Account") {
                            viewModel.beginCreateAccountFlow()
                        }
                        .buttonStyle(.brandPrimary)

                        Button("Log In to Transcribe") {
                            viewModel.beginSignInFlow()
                        }
                        .buttonStyle(.brandSecondary)
                    }
                }

                if !viewModel.accountAuthError.isEmpty {
                    errorBanner(viewModel.accountAuthError)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var homePageContent: some View {
        if !viewModel.hasAccessibilityPermission {
            permissionSection
        }
        accountAccessSection
        quickActionsSection
        latestTranscriptionSection
        previousTranscriptionsSection
    }

    private var settingsPageContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            hotkeySettingsSection
            settingsSection
            permissionSection
        }
    }

    private var hotkeySettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hotkey")
                .font(AppTypography.brandHeading(size: 22))

            HStack(spacing: 10) {
                Text(viewModel.hotkeyCaptureHelpText)
                    .font(AppTypography.body(size: 14))
                    .foregroundStyle(viewModel.isCapturingHotkey ? AppPalette.warning : AppPalette.mutedText)

                Spacer()

                if viewModel.isCapturingHotkey {
                    Button("Cancel") {
                        viewModel.cancelHotkeyUpdate()
                    }
                    .buttonStyle(.brandSecondary)
                } else {
                    Button("Update Hotkey") {
                        viewModel.beginHotkeyUpdate()
                    }
                    .buttonStyle(.brandSecondary)
                }
            }

            if viewModel.isCapturingHotkey {
                Text("Press one key or a key combo, for example ⌘ + ,")
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.mutedText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(AppTypography.brandHeading(size: 22))

            HStack(spacing: 10) {
                Button {
                    viewModel.startCapture()
                } label: {
                    Label("Start Recording", systemImage: "mic.fill")
                }
                .buttonStyle(.brandPrimary)
                .disabled(!viewModel.canTranscribe)

                Button {
                    viewModel.finishCapture()
                } label: {
                    Label("Stop + Transcribe", systemImage: "waveform")
                }
                .buttonStyle(.brandSecondary)
                .disabled(!viewModel.canTranscribe)

                Spacer()
            }

            if !viewModel.canTranscribe {
                Text("Sign in above to enable transcription.")
                    .font(AppTypography.body(size: 12))
                    .foregroundStyle(AppPalette.mutedText)
            }

            if !viewModel.lastError.isEmpty {
                errorBanner(viewModel.lastError)
            }
        }
        .cardStyle()
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription Settings")
                .font(AppTypography.brandHeading(size: 22))

            TextField("Locale (optional)", text: $viewModel.settingsStore.settings.locale)
                .dashboardTextInputStyle()

            textArea(
                title: "Default System Prompt",
                text: $viewModel.settingsStore.settings.defaultSystemPrompt,
                minHeight: 112
            )

            textArea(
                title: "User Context",
                text: $viewModel.settingsStore.settings.userContext,
                minHeight: 112
            )

            textArea(
                title: "Vocabulary Hints",
                text: $viewModel.settingsStore.settings.vocabularyHintText,
                minHeight: 100
            )
        }
        .cardStyle()
    }

    private var latestTranscriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Latest transcription")
                    .font(AppTypography.brandHeading(size: 22))
                Spacer()

                if let latest = viewModel.historyItems.first {
                    Button {
                        viewModel.copyToClipboard(latest.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.brandSecondary)
                    .help("Copy latest transcription")
                }
            }

            if let latest = viewModel.historyItems.first {
                Text(latest.text)
                    .font(AppTypography.body(size: 14))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppPalette.softGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("No transcriptions yet.")
                    .foregroundStyle(AppPalette.mutedText)
            }

            HStack(spacing: 10) {
                Button(showPrevious ? "Hide Previous" : "View Previous") {
                    showPrevious.toggle()
                }
                .buttonStyle(.brandSecondary)

                if !viewModel.historyItems.isEmpty {
                    Button("Clear History") {
                        viewModel.clearHistory()
                    }
                    .buttonStyle(.brandSecondary)
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
                    .font(AppTypography.brandHeading(size: 22))

                if viewModel.historyItems.dropFirst().isEmpty {
                    Text("No previous entries yet.")
                        .foregroundStyle(AppPalette.mutedText)
                } else {
                    ForEach(Array(viewModel.historyItems.dropFirst().prefix(30))) { item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.body(size: 12))
                                    .foregroundStyle(AppPalette.mutedText)
                                Text(item.text)
                                    .font(AppTypography.body(size: 14))
                                    .lineLimit(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                viewModel.copyToClipboard(item.text)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.brandSecondary)
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
                .font(AppTypography.brandHeading(size: 22))

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
                .buttonStyle(.brandPrimary)

                Button("Refresh") {
                    viewModel.refreshAccessibilityPermission()
                }
                .buttonStyle(.brandSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func textArea(title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.bodyMedium(size: 13))
            TextEditor(text: text)
                .font(AppTypography.body(size: 14))
                .tint(AppPalette.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(AppPalette.softGray)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.borderStrong, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppPalette.error)
            Text(message)
                .font(AppTypography.body(size: 13))
                .foregroundStyle(AppPalette.error)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(AppPalette.errorSoft)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppPalette.error.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var statusBackgroundColor: Color {
        switch viewModel.status {
        case .idle:
            return AppPalette.successSoft
        case .recording:
            return AppPalette.errorSoft
        case .transcribing:
            return AppPalette.warningSoft
        case .error:
            return AppPalette.errorSoft
        }
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle:
            return AppPalette.success
        case .recording:
            return AppPalette.error
        case .transcribing:
            return AppPalette.warning
        case .error:
            return AppPalette.error
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

private extension View {
    func dashboardTextInputStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .tint(AppPalette.ink)
            .font(AppTypography.body(size: 14))
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .background(AppPalette.softGray)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(AppPalette.borderStrong, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
