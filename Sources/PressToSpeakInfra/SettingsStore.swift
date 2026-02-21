import Combine
import Foundation
import PressToSpeakCore

public struct AppSettings: Codable {
    public var apiMode: APIMode
    public var activationShortcut: String
    public var defaultSystemPrompt: String
    public var userContext: String
    public var vocabularyHintText: String
    public var locale: String

    public init(
        apiMode: APIMode = .bringYourOwnElevenLabsKey,
        activationShortcut: String = KeyboardShortcut.defaultShortcut.storageValue,
        defaultSystemPrompt: String = "Transcribe accurately. Produce polished written language with correct punctuation and grammar.",
        userContext: String = "",
        vocabularyHintText: String = "",
        locale: String = ""
    ) {
        self.apiMode = apiMode
        self.activationShortcut = activationShortcut
        self.defaultSystemPrompt = defaultSystemPrompt
        self.userContext = userContext
        self.vocabularyHintText = vocabularyHintText
        self.locale = locale
    }

    public var activationShortcutValue: KeyboardShortcut {
        get {
            KeyboardShortcut.fromStoredValue(activationShortcut)
        }
        set {
            activationShortcut = newValue.storageValue
        }
    }

    public var vocabularyHints: [String] {
        vocabularyHintText
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var settings: AppSettings {
        didSet {
            save()
        }
    }

    private let defaults: UserDefaults
    private let key = "pressToSpeak.settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(settings) else {
            return
        }
        defaults.set(encoded, forKey: key)
    }
}
