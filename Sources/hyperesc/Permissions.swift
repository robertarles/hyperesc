import ApplicationServices

/// Check if the app has accessibility permission, prompting the user if not.
/// Returns true if permission is granted, false otherwise.
func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)

    if !trusted {
        fputs("ERROR: Accessibility permission required.\n", stderr)
        fputs("Go to: System Settings -> Privacy & Security -> Accessibility\n", stderr)
        fputs("Enable this app and restart.\n", stderr)
    }
    return trusted
}
