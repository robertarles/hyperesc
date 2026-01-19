import ApplicationServices

func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)
    if !trusted {
        fputs("ERROR: Accessibility permission required.\n", stderr)
        fputs("Go to: System Settings → Privacy & Security → Accessibility\n", stderr)
        fputs("Enable this app and restart.\n", stderr)
    }
    return trusted
}
