import AppKit
import Combine
import Foundation
import PressToSpeakCore
import PressToSpeakInfra

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var status: AppStatus = .idle
    @Published var lastTranscription: String = ""
    @Published var lastError: String = ""
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var historyItems: [TranscriptionHistoryItem] = []
    @Published private(set) var isCapturingHotkey = false
    @Published var accountEmailInput: String = ""
    @Published var accountPasswordInput: String = ""
    @Published private(set) var isAuthInProgress = false
    @Published private(set) var isAccountAuthenticated = false
    @Published private(set) var signedInAccountLabel: String = "Not signed in"
    @Published var showAdvancedModeOptions = false
    @Published var bringYourOwnOpenAIKeyInput: String = ""
    @Published var bringYourOwnElevenLabsKeyInput: String = ""

    var settingsStore: SettingsStore
    var historyStore: TranscriptionHistoryStore

    private let configuration: AppConfiguration
    private let recorder: AudioRecorder
    private let paster: TextPaster
    private let promptBuilder: PromptBuilding
    private let credentialVault: CredentialVault
    private let supabaseAuthService: SupabaseAuthService
    private let hotkeyMonitor: GlobalHotkeyMonitor
    private let hotkeyCaptureService: HotkeyCaptureService
    private var accountSession: PressToSpeakAccountSession?

    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: SettingsStore? = nil,
        historyStore: TranscriptionHistoryStore? = nil
    ) {
        self.settingsStore = settingsStore ?? SettingsStore()
        self.historyStore = historyStore ?? TranscriptionHistoryStore()

        let configuration = AppConfiguration()
        self.configuration = configuration
        self.recorder = AVAudioRecorderAdapter()
        self.paster = ClipboardPaster()
        self.promptBuilder = DefaultPromptBuilder()
        self.credentialVault = CredentialVault()
        self.supabaseAuthService = SupabaseAuthService(configuration: configuration)
        self.hotkeyCaptureService = HotkeyCaptureService()

        self.hotkeyMonitor = GlobalHotkeyMonitor(
            shortcut: self.settingsStore.settings.activationShortcutValue,
            onPress: {},
            onRelease: {}
        )

        hotkeyMonitor.updateCallbacks(
            onPress: { [weak self] in self?.startCapture() },
            onRelease: { [weak self] in self?.finishCapture() }
        )

        hasAccessibilityPermission = AccessibilityPermissionService.isTrusted()
        hotkeyMonitor.start()

        self.historyItems = self.historyStore.items
        if let first = self.historyStore.items.first {
            self.lastTranscription = first.text
        }

        loadSecureState()

        self.settingsStore.$settings
            .map(\.activationShortcutValue)
            .removeDuplicates()
            .sink { [weak self] shortcut in
                self?.hotkeyMonitor.updateShortcut(shortcut)
            }
            .store(in: &cancellables)

        self.historyStore.$items
            .sink { [weak self] items in
                self?.historyItems = items
                self?.lastTranscription = items.first?.text ?? ""
            }
            .store(in: &cancellables)
    }

    var statusLabel: String {
        status.label
    }

    var statusSymbol: String {
        switch status {
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    var activeShortcutLabel: String {
        settingsStore.settings.activationShortcutValue.displayLabel
    }

    var selectedShortcut: KeyboardShortcut {
        settingsStore.settings.activationShortcutValue
    }

    var hotkeyCaptureHelpText: String {
        if isCapturingHotkey {
            return "Press one key or a key combination now..."
        }

        return "Current hotkey: \(activeShortcutLabel)"
    }

    var availableAPIModes: [APIMode] {
        if showAdvancedModeOptions || settingsStore.settings.apiMode == .bringYourOwnKeys {
            return APIMode.allCases
        }

        return [.pressToSpeakAccount]
    }

    var hasStoredBringYourOwnKeys: Bool {
        normalizedNonEmpty(bringYourOwnOpenAIKeyInput) != nil &&
            normalizedNonEmpty(bringYourOwnElevenLabsKeyInput) != nil
    }

    var isSupabaseConfigured: Bool {
        configuration.supabaseURL != nil &&
            normalizedNonEmpty(configuration.supabasePublishableKey) != nil
    }

    func startCapture() {
        guard status == .idle else {
            return
        }

        guard !isCapturingHotkey else {
            return
        }

        lastError = ""
        AppLogger.log("Capture: start requested")

        do {
            try recorder.startRecording()
            status = .recording
            AppLogger.log("Capture: recording started")
        } catch {
            status = .error
            lastError = error.localizedDescription
            AppLogger.log("Capture: start failed: \(error.localizedDescription)")
        }
    }

    func finishCapture() {
        guard status == .recording else {
            return
        }

        AppLogger.log("Capture: finish requested")
        let settings = settingsStore.settings

        Task {
            status = .transcribing

            do {
                let provider = try await selectedProvider(mode: settings.apiMode)
                let orchestrator = TranscriptionOrchestrator(
                    recorder: recorder,
                    provider: provider,
                    paster: paster,
                    promptBuilder: promptBuilder
                )

                let output = try await orchestrator.finishCapture(
                    defaultPrompt: settings.defaultSystemPrompt,
                    userContext: settings.userContext,
                    vocabularyHints: settings.vocabularyHints,
                    locale: settings.locale.isEmpty ? nil : settings.locale,
                    providerOverride: nil
                )

                historyStore.add(text: output)
                status = .idle
                AppLogger.log("Capture: transcription success (\(output.count) chars)")
            } catch {
                status = .error
                lastError = error.localizedDescription
                AppLogger.log("Capture: finish failed: \(error.localizedDescription)")
            }
        }
    }

    func beginHotkeyUpdate() {
        guard !isCapturingHotkey else {
            return
        }

        isCapturingHotkey = true
        lastError = ""
        AppLogger.log("Hotkey: capture mode started")

        hotkeyMonitor.stop()
        hotkeyCaptureService.beginCapture { [weak self] newShortcut in
            guard let self else {
                return
            }

            self.settingsStore.settings.activationShortcutValue = newShortcut
            self.isCapturingHotkey = false
            self.hotkeyMonitor.start()
            AppLogger.log("Hotkey: updated to \(newShortcut.displayLabel)")
        }
    }

    func cancelHotkeyUpdate() {
        guard isCapturingHotkey else {
            return
        }

        hotkeyCaptureService.stopCapture()
        isCapturingHotkey = false
        hotkeyMonitor.start()
        AppLogger.log("Hotkey: capture mode canceled")
    }

    func requestAccessibilityPermissionPrompt() {
        AccessibilityPermissionService.promptIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshAccessibilityPermission()
        }
    }

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AccessibilityPermissionService.isTrusted()
    }

    func resetError() {
        if status == .error {
            status = .idle
        }
        lastError = ""
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func copyLatestToClipboard() {
        guard let latest = historyItems.first else {
            return
        }
        copyToClipboard(latest.text)
    }

    var hasLatestTranscription: Bool {
        !historyItems.isEmpty
    }

    func clearHistory() {
        historyStore.clear()
    }

    func signInWithPressToSpeakAccount() {
        let email = accountEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = accountPasswordInput

        guard !email.isEmpty, !password.isEmpty else {
            lastError = "Enter email and password."
            return
        }

        isAuthInProgress = true
        lastError = ""

        Task {
            do {
                let session = try await supabaseAuthService.signIn(email: email, password: password)
                let storedSession = makeStoredSession(from: session)
                try credentialVault.saveAccountSession(storedSession)
                applySignedInSession(storedSession)
                accountPasswordInput = ""
            } catch {
                lastError = error.localizedDescription
            }

            isAuthInProgress = false
        }
    }

    func signUpWithPressToSpeakAccount() {
        let email = accountEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = accountPasswordInput

        guard !email.isEmpty, !password.isEmpty else {
            lastError = "Enter email and password."
            return
        }

        isAuthInProgress = true
        lastError = ""

        Task {
            do {
                let result = try await supabaseAuthService.signUp(email: email, password: password)
                switch result {
                case .signedIn(let session):
                    let storedSession = makeStoredSession(from: session)
                    try credentialVault.saveAccountSession(storedSession)
                    applySignedInSession(storedSession)
                case .requiresEmailConfirmation:
                    signedInAccountLabel = "Sign-up complete. Confirm your email, then sign in."
                }
                accountPasswordInput = ""
            } catch {
                lastError = error.localizedDescription
            }

            isAuthInProgress = false
        }
    }

    func signOutFromPressToSpeakAccount() {
        let accessToken = accountSession?.accessToken
        accountSession = nil
        isAccountAuthenticated = false
        signedInAccountLabel = "Not signed in"

        do {
            try credentialVault.clearAccountSession()
        } catch {
            lastError = error.localizedDescription
        }

        if let accessToken {
            Task {
                await supabaseAuthService.signOut(accessToken: accessToken)
            }
        }
    }

    func saveBringYourOwnProviderKeys() {
        guard
            let openAIKey = normalizedNonEmpty(bringYourOwnOpenAIKeyInput),
            let elevenLabsKey = normalizedNonEmpty(bringYourOwnElevenLabsKeyInput)
        else {
            lastError = "Both OpenAI and ElevenLabs keys are required in BYOK mode."
            return
        }

        do {
            try credentialVault.saveBringYourOwnProviderKeys(
                openAIAPIKey: openAIKey,
                elevenLabsAPIKey: elevenLabsKey
            )
            bringYourOwnOpenAIKeyInput = openAIKey
            bringYourOwnElevenLabsKeyInput = elevenLabsKey
            lastError = ""
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearBringYourOwnProviderKeys() {
        do {
            try credentialVault.clearBringYourOwnProviderKeys()
            bringYourOwnOpenAIKeyInput = ""
            bringYourOwnElevenLabsKeyInput = ""
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func selectedProvider(mode: APIMode) async throws -> TranscriptionProvider {
        guard configuration.proxyURL != nil else {
            throw AppConfigurationError.proxyURLRequired
        }

        switch mode {
        case .pressToSpeakAccount:
            let session = try await resolveActiveAccountSession()

            return ProxyTranscriptionProvider(
                configuration: configuration,
                additionalHeaders: [
                    "Authorization": "Bearer \(session.accessToken)"
                ]
            )
        case .bringYourOwnKeys:
            guard
                let openAIKey = normalizedNonEmpty(bringYourOwnOpenAIKeyInput),
                let elevenLabsKey = normalizedNonEmpty(bringYourOwnElevenLabsKeyInput)
            else {
                throw AppConfigurationError.bringYourOwnKeysRequired
            }

            return ProxyTranscriptionProvider(
                configuration: configuration,
                additionalHeaders: [
                    "x-openai-api-key": openAIKey,
                    "x-elevenlabs-api-key": elevenLabsKey
                ]
            )
        }
    }

    private func resolveActiveAccountSession() async throws -> PressToSpeakAccountSession {
        guard let currentSession = accountSession else {
            throw AppConfigurationError.accountSignInRequired
        }

        guard currentSession.shouldRefresh() else {
            return currentSession
        }

        do {
            let refreshed = try await supabaseAuthService.refreshSession(refreshToken: currentSession.refreshToken)
            let storedSession = makeStoredSession(from: refreshed)
            try credentialVault.saveAccountSession(storedSession)
            applySignedInSession(storedSession)
            return storedSession
        } catch {
            if !currentSession.shouldRefresh(leewaySeconds: 0) {
                return currentSession
            }

            accountSession = nil
            isAccountAuthenticated = false
            signedInAccountLabel = "Session expired. Sign in again."
            try? credentialVault.clearAccountSession()
            throw error
        }
    }

    private func loadSecureState() {
        do {
            if let storedSession = try credentialVault.loadAccountSession() {
                applySignedInSession(storedSession)
            }

            let byok = try credentialVault.loadBringYourOwnProviderKeys()
            bringYourOwnOpenAIKeyInput = byok.openAIAPIKey ?? ""
            bringYourOwnElevenLabsKeyInput = byok.elevenLabsAPIKey ?? ""
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func applySignedInSession(_ session: PressToSpeakAccountSession) {
        accountSession = session
        isAccountAuthenticated = true
        let label = session.email ?? session.userID
        signedInAccountLabel = "Signed in as \(label)"
    }

    private func makeStoredSession(from session: SupabaseAuthSession) -> PressToSpeakAccountSession {
        PressToSpeakAccountSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userID: session.userID,
            email: session.email,
            accessTokenExpiresAtEpochSeconds: session.accessTokenExpiresAtEpochSeconds
        )
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

private enum AppConfigurationError: LocalizedError {
    case accountSignInRequired
    case bringYourOwnKeysRequired
    case proxyURLRequired

    var errorDescription: String? {
        switch self {
        case .accountSignInRequired:
            return "PressToSpeak Account mode requires signing in first."
        case .bringYourOwnKeysRequired:
            return "Bring Your Own Keys mode requires both OpenAI and ElevenLabs keys."
        case .proxyURLRequired:
            return "TRANSCRIPTION_PROXY_URL is required."
        }
    }
}
