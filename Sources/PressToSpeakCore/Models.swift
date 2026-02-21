import Foundation
import Carbon

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

public enum ShortcutModifier: String, Codable, CaseIterable {
    case command
    case option
    case shift
    case control

    public var symbol: String {
        switch self {
        case .command:
            return "⌘"
        case .option:
            return "⌥"
        case .shift:
            return "⇧"
        case .control:
            return "⌃"
        }
    }
}

public struct KeyboardShortcut: Codable, Equatable {
    public let keyCode: UInt16
    public let modifiers: [ShortcutModifier]
    public let isModifierOnly: Bool

    public init(keyCode: UInt16, modifiers: [ShortcutModifier] = [], isModifierOnly: Bool = false) {
        self.keyCode = keyCode
        self.modifiers = Self.normalizedModifiers(modifiers)
        self.isModifierOnly = isModifierOnly
    }

    public static let defaultShortcut = KeyboardShortcut(
        keyCode: 61, // Right Option
        modifiers: [.option],
        isModifierOnly: true
    )

    public var displayLabel: String {
        if isModifierOnly {
            switch keyCode {
            case 61:
                return "Right Option"
            case 54:
                return "Right Command"
            default:
                return Self.keyLabel(for: keyCode)
            }
        }

        let prefix = modifiers.map(\.symbol)
        let key = Self.keyLabel(for: keyCode)

        if prefix.isEmpty {
            return key
        }

        return (prefix + [key]).joined(separator: " + ")
    }

    public var storageValue: String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else {
            return ""
        }
        return "v1:\(data.base64EncodedString())"
    }

    public static func fromStoredValue(_ value: String) -> KeyboardShortcut {
        if let decoded = Self.fromStorageString(value) {
            return decoded
        }

        if let legacy = Self.fromLegacyActivationShortcut(value) {
            return legacy
        }

        return .defaultShortcut
    }

    public static func fromStorageString(_ value: String) -> KeyboardShortcut? {
        guard value.hasPrefix("v1:") else {
            return nil
        }

        let payload = String(value.dropFirst(3))
        guard let data = Data(base64Encoded: payload) else {
            return nil
        }

        return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
    }

    private static func normalizedModifiers(_ modifiers: [ShortcutModifier]) -> [ShortcutModifier] {
        var seen = Set<ShortcutModifier>()
        let ordered: [ShortcutModifier] = [.command, .control, .option, .shift]

        for modifier in modifiers {
            seen.insert(modifier)
        }

        return ordered.filter { seen.contains($0) }
    }

    private static func fromLegacyActivationShortcut(_ value: String) -> KeyboardShortcut? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "rightoption", "right option (hold)", "right option":
            return KeyboardShortcut(keyCode: 61, modifiers: [.option], isModifierOnly: true)
        case "rightcommand", "right command (hold)", "right command":
            return KeyboardShortcut(keyCode: 54, modifiers: [.command], isModifierOnly: true)
        case "f18", "f18 (hold)":
            return KeyboardShortcut(keyCode: 79)
        case "f19", "f19 (hold)":
            return KeyboardShortcut(keyCode: 80)
        case "f20", "f20 (hold)":
            return KeyboardShortcut(keyCode: 90)
        case "graveaccent", "grave accent ` (hold)", "grave accent `":
            return KeyboardShortcut(keyCode: 50)
        default:
            return nil
        }
    }

    private static func keyLabel(for keyCode: UInt16) -> String {
        if let localized = localizedPrintableKeyLabel(for: keyCode) {
            return localized
        }

        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        case 54: return "Right Command"
        case 55: return "Left Command"
        case 56: return "Left Shift"
        case 57: return "Caps Lock"
        case 58: return "Left Option"
        case 59: return "Left Control"
        case 60: return "Right Shift"
        case 61: return "Right Option"
        case 62: return "Right Control"
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Escape"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        case 105: return "F13"
        case 107: return "F14"
        case 113: return "F15"
        case 106: return "F16"
        case 64: return "F17"
        case 79: return "F18"
        case 80: return "F19"
        case 90: return "F20"
        default:
            return "Key \(keyCode)"
        }
    }

    private static func localizedPrintableKeyLabel(for keyCode: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }

        guard let rawLayoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        guard let keyboardLayoutPtr = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        var deadKeyState: UInt32 = 0
        var actualLength: Int = 0
        var unicodeChars = [UniChar](repeating: 0, count: 4)

        let status: OSStatus = keyboardLayoutPtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { reboundPtr in
            UCKeyTranslate(
                reboundPtr,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                unicodeChars.count,
                &actualLength,
                &unicodeChars
            )
        }

        guard status == noErr, actualLength > 0 else {
            return nil
        }

        let output = String(utf16CodeUnits: unicodeChars, count: actualLength)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !output.isEmpty else {
            return nil
        }

        if output.count == 1 {
            return output.uppercased()
        }

        return output
    }
}

// Legacy migration support for previously saved values.
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
