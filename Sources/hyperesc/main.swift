import Foundation

// MARK: - Globals for signal handling

private var globalEventTap: EventTap?

// MARK: - CLI Argument Parsing

func printUsage() {
    let usage = """
    USAGE: hyperesc [OPTIONS]

    OPTIONS:
      -f, --full-hyper       Use full hyper key (Cmd+Opt+Ctrl+Shift)
      -v, --verbose          Enable verbose debug output
      -h, --help             Display help information
    """
    print(usage)
}

func parseArguments() -> Config? {
    var useFullHyper = false
    var verbose = false

    let args = Array(CommandLine.arguments.dropFirst())
    var i = 0

    while i < args.count {
        let arg = args[i]

        switch arg {
        case "-h", "--help":
            printUsage()
            return nil

        case "-v", "--verbose":
            verbose = true

        case "-f", "--full-hyper":
            useFullHyper = true

        default:
            fputs("ERROR: Unknown option: \(arg)\n", stderr)
            printUsage()
            return nil
        }

        i += 1
    }

    return Config(useFullHyper: useFullHyper, verbose: verbose)
}

// MARK: - Caps Lock Control via hidutil

/// Remap Caps Lock to F18 using hidutil
func disableCapsLock() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    task.arguments = [
        "property",
        "--set",
        #"{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000006D}]}"#
    ]

    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    } catch {
        fputs("ERROR: Failed to run hidutil: \(error)\n", stderr)
        return false
    }
}

/// Restore Caps Lock to normal behavior
func restoreCapsLock() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
    task.arguments = ["property", "--set", #"{"UserKeyMapping":[]}"#]
    try? task.run()
    task.waitUntilExit()
}

// MARK: - Signal Handling

func setupSignalHandlers() {
    signal(SIGINT) { _ in
        fputs("\nReceived SIGINT, shutting down...\n", stderr)
        restoreCapsLock()
        globalEventTap?.stop()
        exit(0)
    }

    signal(SIGTERM) { _ in
        fputs("\nReceived SIGTERM, shutting down...\n", stderr)
        restoreCapsLock()
        globalEventTap?.stop()
        exit(0)
    }
}

// MARK: - Main

// Parse CLI arguments
guard let config = parseArguments() else {
    exit(0)  // Help was shown or error occurred
}

if config.verbose {
    fputs("[main] Starting hyperesc with fullHyper=\(config.useFullHyper)\n", stderr)
}

// Check accessibility permission (prompts user if not granted)
guard checkAccessibilityPermission() else {
    exit(1)
}

// Disable system Caps Lock via hidutil (remap to F18)
if config.verbose {
    fputs("[main] Remapping Caps Lock to F18 via hidutil...\n", stderr)
}
guard disableCapsLock() else {
    fputs("ERROR: Failed to remap Caps Lock via hidutil\n", stderr)
    exit(1)
}

// Create components
let keyHandler = KeyHandler(config: config)
let eventTap = EventTap(keyHandler: keyHandler)
globalEventTap = eventTap

// Setup signal handlers for clean shutdown
setupSignalHandlers()

// Start event tap
guard eventTap.start() else {
    restoreCapsLock()
    exit(1)
}

print("hyperesc running. Press Ctrl+C to stop.")
if config.verbose {
    fputs("[main] Entering run loop...\n", stderr)
}

// Run event loop (blocks until terminated)
eventTap.run()

// Cleanup (reached if run loop exits normally)
restoreCapsLock()
