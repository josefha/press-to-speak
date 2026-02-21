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

    var settingsStore: SettingsStore
    var historyStore: TranscriptionHistoryStore

    private let recorder: AudioRecorder
    private let paster: TextPaster
    private let promptBuilder: PromptBuilding
    private let elevenLabsProvider: TranscriptionProvider
    private let proxyProvider: TranscriptionProvider
    private let hotkeyMonitor: GlobalHotkeyMonitor
    private let hotkeyCaptureService: HotkeyCaptureService

    private var cancellables = Set<AnyCancellable>()

    init(
        settingsStore: SettingsStore? = nil,
        historyStore: TranscriptionHistoryStore? = nil
    ) {
        self.settingsStore = settingsStore ?? SettingsStore()
        self.historyStore = historyStore ?? TranscriptionHistoryStore()

        let configuration = AppConfiguration()
        self.recorder = AVAudioRecorderAdapter()
        self.paster = ClipboardPaster()
        self.promptBuilder = DefaultPromptBuilder()
        self.elevenLabsProvider = ElevenLabsTranscriptionProvider(configuration: configuration)
        self.proxyProvider = ProxyTranscriptionProvider(configuration: configuration)
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
        let provider = selectedProvider(mode: settings.apiMode)
        let orchestrator = TranscriptionOrchestrator(
            recorder: recorder,
            provider: elevenLabsProvider,
            paster: paster,
            promptBuilder: promptBuilder
        )

        Task {
            status = .transcribing

            do {
                let output = try await orchestrator.finishCapture(
                    defaultPrompt: settings.defaultSystemPrompt,
                    userContext: settings.userContext,
                    vocabularyHints: settings.vocabularyHints,
                    locale: settings.locale.isEmpty ? nil : settings.locale,
                    providerOverride: provider
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

    private func selectedProvider(mode: APIMode) -> TranscriptionProvider {
        switch mode {
        case .bringYourOwnElevenLabsKey:
            return elevenLabsProvider
        case .proxy:
            return proxyProvider
        }
    }
}
