import Foundation

public enum AppStatus: String, Codable {
    case idle
    case recording
    case transcribing
    case error

    public var label: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .transcribing:
            return "Transcribing"
        case .error:
            return "Error"
        }
    }
}

public enum ActivationShortcut: String, Codable, CaseIterable, Identifiable {
    case rightOption
    case rightCommand
    case f18
    case f19
    case f20
    case graveAccent

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .rightOption:
            return "Right Option (hold)"
        case .rightCommand:
            return "Right Command (hold)"
        case .f18:
            return "F18 (hold)"
        case .f19:
            return "F19 (hold)"
        case .f20:
            return "F20 (hold)"
        case .graveAccent:
            return "Grave Accent ` (hold)"
        }
    }

    public static func fromStoredValue(_ value: String) -> ActivationShortcut {
        if let match = ActivationShortcut(rawValue: value) {
            return match
        }

        switch value.lowercased() {
        case "right option (hold)":
            return .rightOption
        case "right command (hold)":
            return .rightCommand
        case "f18 (hold)":
            return .f18
        case "f19 (hold)":
            return .f19
        case "f20 (hold)":
            return .f20
        case "grave accent ` (hold)":
            return .graveAccent
        default:
            return .rightOption
        }
    }
}

public enum APIMode: String, Codable, CaseIterable, Identifiable {
    case bringYourOwnElevenLabsKey
    case proxy

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .bringYourOwnElevenLabsKey:
            return "Bring Your Own ElevenLabs Key"
        case .proxy:
            return "Use Proxy API"
        }
    }
}

public struct TranscriptionRequest {
    public let audioFileURL: URL
    public let systemPrompt: String
    public let userContext: String
    public let vocabularyHints: [String]
    public let locale: String?

    public init(
        audioFileURL: URL,
        systemPrompt: String,
        userContext: String,
        vocabularyHints: [String],
        locale: String?
    ) {
        self.audioFileURL = audioFileURL
        self.systemPrompt = systemPrompt
        self.userContext = userContext
        self.vocabularyHints = vocabularyHints
        self.locale = locale
    }
}

public struct TranscriptionResult {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}
