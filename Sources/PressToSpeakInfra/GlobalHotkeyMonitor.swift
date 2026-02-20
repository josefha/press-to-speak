import AppKit
import Carbon
import Foundation
import PressToSpeakCore

public final class GlobalHotkeyMonitor {
    private var shortcut: ActivationShortcut
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
        shortcut: ActivationShortcut,
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
        if let monitor = localKeyDownMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalFlagsChangedMonitor {
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

    public func updateShortcut(_ shortcut: ActivationShortcut) {
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
        if shortcut.isModifierShortcut {
            return
        }

        guard event.keyCode == shortcut.keyCode else {
            return
        }

        transition(isPressed: isKeyDown, ignoreRepeats: event.isARepeat)
    }

    private func handleFlagsChanged(event: NSEvent) {
        guard shortcut.isModifierShortcut else {
            return
        }

        guard event.keyCode == shortcut.keyCode else {
            return
        }

        transition(isPressed: shortcut.isPressed(in: event.modifierFlags), ignoreRepeats: false)
    }

    private func transition(isPressed shouldBePressed: Bool, ignoreRepeats: Bool) {
        if shouldBePressed {
            guard !ignoreRepeats else {
                return
            }
            guard !isPressed else {
                return
            }
            isPressed = true
            Task { @MainActor in
                onPress()
            }
        } else {
            guard isPressed else {
                return
            }

            isPressed = false
            Task { @MainActor in
                onRelease()
            }
        }
    }
}

private extension ActivationShortcut {
    var isModifierShortcut: Bool {
        switch self {
        case .rightOption, .rightCommand:
            return true
        case .f18, .f19, .f20, .graveAccent:
            return false
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .rightOption:
            return UInt16(kVK_RightOption)
        case .rightCommand:
            return UInt16(kVK_RightCommand)
        case .f18:
            return UInt16(kVK_F18)
        case .f19:
            return UInt16(kVK_F19)
        case .f20:
            return UInt16(kVK_F20)
        case .graveAccent:
            return UInt16(kVK_ANSI_Grave)
        }
    }

    func isPressed(in flags: NSEvent.ModifierFlags) -> Bool {
        switch self {
        case .rightOption:
            return flags.contains(.option)
        case .rightCommand:
            return flags.contains(.command)
        case .f18, .f19, .f20, .graveAccent:
            return false
        }
    }
}
