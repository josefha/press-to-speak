import ApplicationServices
import Foundation

public enum AccessibilityPermissionService {
    public static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func promptIfNeeded() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
