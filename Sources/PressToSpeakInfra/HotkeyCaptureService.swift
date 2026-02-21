import AppKit
import Foundation
import PressToSpeakCore

@MainActor
public final class HotkeyCaptureService {
    private var globalKeyDownMonitor: Any?
    private var globalFlagsChangedMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localFlagsChangedMonitor: Any?

    private var onCaptured: ((KeyboardShortcut) -> Void)?
    private var pendingModifierShortcut: KeyboardShortcut?

    public init() {}

    public func beginCapture(onCaptured: @escaping (KeyboardShortcut) -> Void) {
        stopCapture()
        self.onCaptured = onCaptured

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.handleKeyDown(event: event)
            }
        }

        globalFlagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            Task { @MainActor in
                self?.handleFlagsChanged(event: event)
            }
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleKeyDown(event: event)
            return event
        }

        localFlagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event: event)
            return event
        }
    }

    public func stopCapture() {
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
        }

        globalKeyDownMonitor = nil
        globalFlagsChangedMonitor = nil
        localKeyDownMonitor = nil
        localFlagsChangedMonitor = nil
        pendingModifierShortcut = nil
        onCaptured = nil
    }

    private func handleKeyDown(event: NSEvent) {
        guard !event.isARepeat else {
            return
        }

        pendingModifierShortcut = nil

        let modifiers = orderedModifiers(from: event.modifierFlags)
        let shortcut = KeyboardShortcut(
            keyCode: event.keyCode,
            modifiers: modifiers,
            isModifierOnly: false
        )

        finishCapture(with: shortcut)
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard let modifier = modifierForKeyCode(event.keyCode) else {
            return
        }

        let active = Set(orderedModifiers(from: event.modifierFlags))
        guard active.contains(modifier) else {
            if let pendingModifierShortcut {
                finishCapture(with: pendingModifierShortcut)
            } else {
                pendingModifierShortcut = nil
            }
            return
        }

        pendingModifierShortcut = KeyboardShortcut(
            keyCode: event.keyCode,
            modifiers: [modifier],
            isModifierOnly: true
        )
    }

    private func finishCapture(with shortcut: KeyboardShortcut) {
        let callback = onCaptured
        stopCapture()
        callback?(shortcut)
    }

    private func orderedModifiers(from flags: NSEvent.ModifierFlags) -> [ShortcutModifier] {
        var result: [ShortcutModifier] = []

        if flags.contains(.command) {
            result.append(.command)
        }
        if flags.contains(.control) {
            result.append(.control)
        }
        if flags.contains(.option) {
            result.append(.option)
        }
        if flags.contains(.shift) {
            result.append(.shift)
        }

        return result
    }

    private func modifierForKeyCode(_ keyCode: UInt16) -> ShortcutModifier? {
        switch keyCode {
        case 54, 55:
            return .command
        case 58, 61:
            return .option
        case 56, 60:
            return .shift
        case 59, 62:
            return .control
        default:
            return nil
        }
    }
}
