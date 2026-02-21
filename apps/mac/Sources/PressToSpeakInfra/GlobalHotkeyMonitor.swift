import AppKit
import Foundation
import PressToSpeakCore

public final class GlobalHotkeyMonitor {
    private var shortcut: KeyboardShortcut
    private var onPress: @MainActor () -> Void
    private var onRelease: @MainActor () -> Void

    private var isPressed = false

    private var globalKeyDownMonitor: Any?
    private var globalKeyUpMonitor: Any?
    private var globalFlagsChangedMonitor: Any?
    private var localKeyDownMonitor: Any?
    private var localKeyUpMonitor: Any?
    private var localFlagsChangedMonitor: Any?

    public init(
        shortcut: KeyboardShortcut,
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void
    ) {
        self.shortcut = shortcut
        self.onPress = onPress
        self.onRelease = onRelease
    }

    deinit {
        stop()
    }

    public func start() {
        stop()

        globalKeyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event: event, isKeyDown: true)
        }

        globalKeyUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            self?.handle(event: event, isKeyDown: false)
        }

        globalFlagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event: event)
        }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event: event, isKeyDown: true)
            return event
        }

        localKeyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { [weak self] event in
            self?.handle(event: event, isKeyDown: false)
            return event
        }

        localFlagsChangedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event: event)
            return event
        }
    }

    public func stop() {
        if let monitor = globalKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localFlagsChangedMonitor {
            NSEvent.removeMonitor(monitor)
        }

        globalKeyDownMonitor = nil
        globalKeyUpMonitor = nil
        globalFlagsChangedMonitor = nil
        localKeyDownMonitor = nil
        localKeyUpMonitor = nil
        localFlagsChangedMonitor = nil
        isPressed = false
    }

    public func updateShortcut(_ shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
        self.isPressed = false
    }

    public func updateCallbacks(
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void
    ) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    private func handle(event: NSEvent, isKeyDown: Bool) {
        if shortcut.isModifierOnly {
            return
        }

        if isKeyDown {
            guard !event.isARepeat else {
                return
            }
            guard matchesKeyDown(event: event, shortcut: shortcut) else {
                return
            }

            transition(isPressed: true)
            return
        }

        guard event.keyCode == shortcut.keyCode else {
            return
        }

        transition(isPressed: false)
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard shortcut.isModifierOnly else {
            return
        }

        guard event.keyCode == shortcut.keyCode else {
            return
        }

        guard let requiredModifier = shortcut.modifiers.first else {
            return
        }

        let activeModifiers = normalizedModifiers(from: event.modifierFlags)
        let shouldBePressed = activeModifiers.contains(requiredModifier)
        transition(isPressed: shouldBePressed)
    }

    private func matchesKeyDown(event: NSEvent, shortcut: KeyboardShortcut) -> Bool {
        guard event.keyCode == shortcut.keyCode else {
            return false
        }

        let active = normalizedModifiers(from: event.modifierFlags)
        let expected = Set(shortcut.modifiers)
        return active == expected
    }

    private func normalizedModifiers(from flags: NSEvent.ModifierFlags) -> Set<ShortcutModifier> {
        var result = Set<ShortcutModifier>()

        if flags.contains(.command) {
            result.insert(.command)
        }
        if flags.contains(.option) {
            result.insert(.option)
        }
        if flags.contains(.shift) {
            result.insert(.shift)
        }
        if flags.contains(.control) {
            result.insert(.control)
        }

        return result
    }

    private func transition(isPressed shouldBePressed: Bool) {
        if shouldBePressed {
            guard !isPressed else {
                return
            }
            isPressed = true
            Task { @MainActor in
                onPress()
            }
            return
        }

        guard isPressed else {
            return
        }

        isPressed = false
        Task { @MainActor in
            onRelease()
        }
    }
}
