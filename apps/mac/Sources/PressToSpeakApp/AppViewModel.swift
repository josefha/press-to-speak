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
    @Published private(set) var accountProfileName: String = "PressToSpeak User"
    @Published private(set) var accountProfileEmail: String = ""
    @Published private(set) var accountTierLabel: String = PressToSpeakAccountTier.free.label
    @Published private(set) var accountAuthFlow: AccountAuthFlow = .none
    @Published private(set) var accountAuthError: String = ""
    @Published var showAdvancedModeOptions = false
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var updateCheckError: String = ""
    @Published private(set) var updateStatus: AppUpdateStatus?

    var settingsStore: SettingsStore
    var historyStore: TranscriptionHistoryStore

    private let configuration: AppConfiguration
    private let recorder: AudioRecorder
    private let paster: TextPaster
    private let promptBuilder: PromptBuilding
    private let credentialVault: CredentialVault
    private let accountAuthService: any PressToSpeakAccountAuthServicing
    private let appUpdateService: any AppUpdateChecking
    private let hotkeyMonitor: GlobalHotkeyMonitor
    private let hotkeyCaptureService: HotkeyCaptureService
    private var accountSession: PressToSpeakAccountSession?
    private var accountStateRefreshTask: Task<Void, Never>?
    private var accessibilityStateRefreshTask: Task<Void, Never>?
    private var lastUpdateCheckAt: Date?
    private let automaticUpdateCheckIntervalSeconds: TimeInterval = 5

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
        self.accountAuthService = SupabaseAuthService(configuration: configuration)
        self.appUpdateService = AppUpdateService(configuration: configuration)
        self.hotkeyCaptureService = HotkeyCaptureService()

        // Keep account mode as the current product default.
        self.settingsStore.settings.apiMode = .pressToSpeakAccount

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

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.refreshUIStateOnOpen()
            }
            .store(in: &cancellables)

        Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.hasAccessibilityPermission else {
                    return
                }
                self.refreshAccessibilityPermission()
            }
            .store(in: &cancellables)

        Timer.publish(every: automaticUpdateCheckIntervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForUpdatesIfNeeded()
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
        return [.pressToSpeakAccount]
    }

    var canTranscribe: Bool {
        isAccountAuthenticated
    }

    var shouldShowAccountAuthForm: Bool {
        accountAuthFlow != .none
    }

    var isCreateAccountFlow: Bool {
        accountAuthFlow == .createAccount
    }

    var accountProfileInitial: String {
        let name = accountProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = name.first else {
            return "P"
        }
        return String(first).uppercased()
    }

    var isAccountAuthConfigured: Bool {
        return configuration.proxyURL != nil
    }

    var currentAppVersionLabel: String {
        let shortVersion = normalizedNonEmpty(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "0.0.0"
        let buildNumber = normalizedNonEmpty(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)

        if let buildNumber {
            return "\(shortVersion) (\(buildNumber))"
        }

        return shortVersion
    }

    var isUpdateAvailable: Bool {
        updateStatus?.updateAvailable ?? false
    }

    var isUpdateRequired: Bool {
        updateStatus?.updateRequired ?? false
    }

    var latestVersionLabel: String {
        updateStatus?.latestVersion ?? ""
    }

    var canOpenUpdateDownload: Bool {
        updateStatus?.downloadURL != nil
    }

    var canOpenUpdateReleaseNotes: Bool {
        updateStatus?.releaseNotesURL != nil
    }

    func startCapture() {
        guard status == .idle else {
            return
        }

        guard !isCapturingHotkey else {
            return
        }

        if !canTranscribe {
            status = .idle
            lastError = ""
            accountAuthError = "Sign in with a free PressToSpeak account to transcribe."
            if accountAuthFlow == .none {
                accountAuthFlow = .signIn
            }
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
                let provider = try await selectedProvider()
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

    func refreshUIStateOnOpen() {
        refreshAccessibilityPermission()
        checkForUpdatesIfNeeded()

        accessibilityStateRefreshTask?.cancel()
        accessibilityStateRefreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else {
                return
            }
            self.refreshAccessibilityPermission()

            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else {
                return
            }
            self.refreshAccessibilityPermission()
        }

        accountStateRefreshTask?.cancel()
        accountStateRefreshTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.refreshAccountStateOnOpen()
        }
    }

    func checkForUpdatesManually() {
        performUpdateCheck(force: true)
    }

    func openUpdateDownloadPage() {
        guard let url = updateStatus?.downloadURL else {
            updateCheckError = "Download link is not configured yet."
            return
        }

        NSWorkspace.shared.open(url)
    }

    func openUpdateReleaseNotes() {
        guard let url = updateStatus?.releaseNotesURL else {
            updateCheckError = "Release notes link is not configured yet."
            return
        }

        NSWorkspace.shared.open(url)
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

    func beginSignInFlow() {
        accountAuthFlow = .signIn
        accountAuthError = ""
    }

    func beginCreateAccountFlow() {
        accountAuthFlow = .createAccount
        accountAuthError = ""
    }

    func cancelAccountFlow() {
        accountAuthFlow = .none
        accountPasswordInput = ""
        accountAuthError = ""
    }

    func submitCurrentAccountFlow() {
        if accountAuthFlow == .createAccount {
            signUpWithPressToSpeakAccount()
            return
        }

        signInWithPressToSpeakAccount()
    }

    func signInWithPressToSpeakAccount() {
        let email = accountEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = accountPasswordInput

        guard !email.isEmpty, !password.isEmpty else {
            accountAuthError = "Enter email and password."
            return
        }

        isAuthInProgress = true
        accountAuthError = ""

        Task {
            do {
                let session = try await accountAuthService.signIn(email: email, password: password)
                let storedSession = makeStoredSession(from: session)
                try credentialVault.saveAccountSession(storedSession)
                applySignedInSession(storedSession)
                accountPasswordInput = ""
                accountAuthFlow = .none
            } catch {
                accountAuthError = error.localizedDescription
            }

            isAuthInProgress = false
        }
    }

    func signUpWithPressToSpeakAccount() {
        let email = accountEmailInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = accountPasswordInput

        guard !email.isEmpty, !password.isEmpty else {
            accountAuthError = "Enter email and password."
            return
        }

        isAuthInProgress = true
        accountAuthError = ""

        Task {
            do {
                let result = try await accountAuthService.signUp(email: email, password: password)
                switch result {
                case .signedIn(let session):
                    let storedSession = makeStoredSession(from: session)
                    try credentialVault.saveAccountSession(storedSession)
                    applySignedInSession(storedSession)
                    accountAuthFlow = .none
                case .requiresEmailConfirmation:
                    accountAuthFlow = .signIn
                    accountAuthError = "Account created. Check your email for confirmation, then log in."
                }
                accountPasswordInput = ""
            } catch {
                accountAuthError = error.localizedDescription
            }

            isAuthInProgress = false
        }
    }

    func signOutFromPressToSpeakAccount() {
        let accessToken = accountSession?.accessToken
        resetSignedInAccountState()
        resetError()
        accountAuthError = ""
        accountAuthFlow = .none

        do {
            try credentialVault.clearAccountSession()
        } catch {
            accountAuthError = error.localizedDescription
        }

        if let accessToken {
            Task {
                await accountAuthService.signOut(accessToken: accessToken)
            }
        }
    }

    private func selectedProvider() async throws -> TranscriptionProvider {
        guard configuration.proxyURL != nil else {
            throw AppConfigurationError.proxyURLRequired
        }

        let session = try await resolveActiveAccountSession()

        return ProxyTranscriptionProvider(
            configuration: configuration,
            additionalHeaders: [
                "Authorization": "Bearer \(session.accessToken)"
            ]
        )
    }

    private func resolveActiveAccountSession() async throws -> PressToSpeakAccountSession {
        guard let currentSession = accountSession else {
            throw AppConfigurationError.accountSignInRequired
        }

        guard currentSession.shouldRefresh() else {
            return currentSession
        }

        do {
            let refreshed = try await accountAuthService.refreshSession(refreshToken: currentSession.refreshToken)
            let storedSession = makeStoredSession(from: refreshed)
            try credentialVault.saveAccountSession(storedSession)
            applySignedInSession(storedSession)
            return storedSession
        } catch {
            if !currentSession.shouldRefresh(leewaySeconds: 0) {
                return currentSession
            }

            resetSignedInAccountState()
            signedInAccountLabel = "Session expired. Sign in again."
            try? credentialVault.clearAccountSession()
            throw error
        }
    }

    private func refreshAccountStateOnOpen() async {
        do {
            guard let storedSession = try credentialVault.loadAccountSession() else {
                if isAccountAuthenticated {
                    resetSignedInAccountState()
                }
                return
            }

            applySignedInSession(storedSession)
            _ = try await resolveActiveAccountSession()
        } catch AppConfigurationError.accountSignInRequired {
            resetSignedInAccountState()
        } catch {
            AppLogger.log("Account: refresh on open failed: \(error.localizedDescription)")
        }
    }

    private func checkForUpdatesIfNeeded() {
        performUpdateCheck(force: false)
    }

    private func performUpdateCheck(force: Bool) {
        guard !isCheckingForUpdates else {
            return
        }

        if !force, let lastUpdateCheckAt, Date().timeIntervalSince(lastUpdateCheckAt) < automaticUpdateCheckIntervalSeconds {
            return
        }

        isCheckingForUpdates = true
        if force {
            updateCheckError = ""
        }

        let currentVersion = normalizedNonEmpty(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)

        Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.isCheckingForUpdates = false
                self.lastUpdateCheckAt = Date()
            }

            do {
                let info = try await self.appUpdateService.fetchLatestUpdate(currentVersion: currentVersion)
                let updateAvailable = info.updateAvailable ??
                    Self.isVersion(currentVersion, lessThan: info.latestVersion)
                let updateRequired = info.updateRequired ??
                    Self.isVersion(currentVersion, lessThan: info.minimumSupportedVersion)

                self.updateStatus = AppUpdateStatus(
                    latestVersion: info.latestVersion,
                    minimumSupportedVersion: info.minimumSupportedVersion,
                    updateAvailable: updateAvailable,
                    updateRequired: updateRequired,
                    downloadURL: info.downloadURL,
                    releaseNotesURL: info.releaseNotesURL
                )
                self.updateCheckError = ""
            } catch {
                AppLogger.log("Updates: check failed: \(error.localizedDescription)")
                if force {
                    self.updateCheckError = error.localizedDescription
                }
            }
        }
    }

    private func loadSecureState() {
        do {
            if let storedSession = try credentialVault.loadAccountSession() {
                applySignedInSession(storedSession)
            }
        } catch {
            accountAuthError = error.localizedDescription
        }
    }

    private func applySignedInSession(_ session: PressToSpeakAccountSession) {
        accountSession = session
        isAccountAuthenticated = true
        accountProfileName = resolveProfileName(session: session)
        accountProfileEmail = session.email ?? ""
        accountTierLabel = session.resolvedAccountTier.label
        signedInAccountLabel = "Signed in as \(accountProfileName)"
        accountAuthError = ""
    }

    private func makeStoredSession(from session: SupabaseAuthSession) -> PressToSpeakAccountSession {
        PressToSpeakAccountSession(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            userID: session.userID,
            email: session.email,
            profileName: session.profileName,
            accountTier: session.accountTier,
            accessTokenExpiresAtEpochSeconds: session.accessTokenExpiresAtEpochSeconds
        )
    }

    private func resolveProfileName(session: PressToSpeakAccountSession) -> String {
        if let explicitName = normalizedNonEmpty(session.profileName) {
            return displayName(from: explicitName)
        }

        if let email = normalizedNonEmpty(session.email) {
            let localPart = email.split(separator: "@").first.map(String.init) ?? email
            if let derived = normalizedNonEmpty(localPart.replacingOccurrences(of: ".", with: " ")) {
                return displayName(from: derived)
            }
        }

        if let userID = normalizedNonEmpty(session.userID) {
            return displayName(from: userID)
        }

        return "PressToSpeak User"
    }

    private func resetSignedInAccountState() {
        accountSession = nil
        isAccountAuthenticated = false
        signedInAccountLabel = "Not signed in"
        accountProfileName = "PressToSpeak User"
        accountProfileEmail = ""
        accountTierLabel = PressToSpeakAccountTier.free.label
    }

    private func displayName(from rawValue: String) -> String {
        let normalized = rawValue
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return "PressToSpeak User"
        }

        return normalized
            .split(separator: " ")
            .map { segment in
                segment.prefix(1).uppercased() + segment.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func isVersion(_ left: String?, lessThan right: String) -> Bool {
        guard let left else {
            return false
        }

        return compareVersionStrings(left, right) == .orderedAscending
    }

    private static func compareVersionStrings(_ left: String, _ right: String) -> ComparisonResult {
        let leftSegments = parseVersionSegments(left)
        let rightSegments = parseVersionSegments(right)
        let maxCount = max(leftSegments.count, rightSegments.count)

        for index in 0..<maxCount {
            let leftValue = index < leftSegments.count ? leftSegments[index] : 0
            let rightValue = index < rightSegments.count ? rightSegments[index] : 0
            if leftValue < rightValue {
                return .orderedAscending
            }
            if leftValue > rightValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func parseVersionSegments(_ version: String) -> [Int] {
        let cleaned = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            return [0, 0, 0, 0]
        }

        let rawSegments = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        var parsed = rawSegments.map { segment -> Int in
            Int(segment) ?? 0
        }

        if parsed.count < 4 {
            parsed.append(contentsOf: repeatElement(0, count: 4 - parsed.count))
        }

        return parsed
    }
}

private enum AppConfigurationError: LocalizedError {
    case accountSignInRequired
    case proxyURLRequired

    var errorDescription: String? {
        switch self {
        case .accountSignInRequired:
            return "PressToSpeak Account mode requires signing in first."
        case .proxyURLRequired:
            return "TRANSCRIPTION_PROXY_URL is required."
        }
    }
}

enum AccountAuthFlow {
    case none
    case signIn
    case createAccount
}

struct AppUpdateStatus {
    let latestVersion: String
    let minimumSupportedVersion: String
    let updateAvailable: Bool
    let updateRequired: Bool
    let downloadURL: URL?
    let releaseNotesURL: URL?
}
