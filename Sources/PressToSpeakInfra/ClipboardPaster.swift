import AppKit
import Carbon
import Foundation
import PressToSpeakCore

public enum ClipboardPasterError: LocalizedError {
    case failedToCreatePasteEvents

    public var errorDescription: String? {
        switch self {
        case .failedToCreatePasteEvents:
            return "Unable to synthesize Cmd+V paste events. Verify Accessibility permission is granted."
        }
    }
}

private struct PasteboardSnapshot {
    let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let payload: [[NSPasteboard.PasteboardType: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var dictionary: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dictionary[type] = data
                }
            }
            return dictionary
        }

        return PasteboardSnapshot(items: payload)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let reconstructed: [NSPasteboardItem] = items.map { element in
            let pasteboardItem = NSPasteboardItem()
            for (type, data) in element {
                pasteboardItem.setData(data, forType: type)
            }
            return pasteboardItem
        }

        if !reconstructed.isEmpty {
            pasteboard.writeObjects(reconstructed)
        }
    }
}

public final class ClipboardPaster: TextPaster {
    public init() {}

    public func paste(text: String) throws {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            throw ClipboardPasterError.failedToCreatePasteEvents
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        Thread.sleep(forTimeInterval: 0.12)
        snapshot.restore(to: pasteboard)
    }
}
