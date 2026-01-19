import Foundation

struct Config {
    let tapThreshold: Int  // milliseconds
    let useFullHyper: Bool
    let verbose: Bool

    static func `default`() -> Config {
        Config(tapThreshold: 200, useFullHyper: false, verbose: false)
    }
}

func printHelp() {
    let help = """
        hyperesc - Caps Lock to Escape/Hyper key mapper for macOS

        USAGE:
            hyperesc [OPTIONS]

        OPTIONS:
            -t, --threshold <ms>    Tap threshold in milliseconds (default: 200)
            -f, --full-hyper        Use full Hyper key (Cmd+Opt+Ctrl+Shift)
                                    Default is Cmd+Opt only
            -v, --verbose           Enable verbose debug output
            -h, --help              Display this help information

        EXAMPLES:
            hyperesc                    Run with defaults (200ms threshold, Cmd+Opt)
            hyperesc -t 150             Use 150ms tap threshold
            hyperesc --full-hyper       Use Cmd+Opt+Ctrl+Shift as Hyper
            hyperesc -t 250 -f -v       Custom threshold, full hyper, verbose
        """
    print(help)
}

func parseArguments() -> Config? {
    let args = Array(CommandLine.arguments.dropFirst())

    var tapThreshold = 200
    var useFullHyper = false
    var verbose = false

    var i = 0
    while i < args.count {
        let arg = args[i]

        switch arg {
        case "-h", "--help":
            printHelp()
            exit(0)

        case "-f", "--full-hyper":
            useFullHyper = true

        case "-v", "--verbose":
            verbose = true

        case "-t", "--threshold":
            i += 1
            guard i < args.count else {
                fputs("Error: --threshold requires a value\n", stderr)
                fputs("Use --help for usage information\n", stderr)
                return nil
            }
            guard let value = Int(args[i]), value > 0 else {
                fputs("Error: --threshold must be a positive integer\n", stderr)
                fputs("Use --help for usage information\n", stderr)
                return nil
            }
            tapThreshold = value

        default:
            fputs("Error: Unknown argument '\(arg)'\n", stderr)
            fputs("Use --help for usage information\n", stderr)
            return nil
        }

        i += 1
    }

    return Config(tapThreshold: tapThreshold, useFullHyper: useFullHyper, verbose: verbose)
}

// Main entry point
guard let config = parseArguments() else {
    exit(1)
}

if config.verbose {
    print("Configuration:")
    print("  Tap threshold: \(config.tapThreshold)ms")
    print("  Full hyper: \(config.useFullHyper)")
    print("  Verbose: \(config.verbose)")
}

// Check accessibility permission before proceeding
guard checkAccessibilityPermission() else {
    exit(1)
}

print("hyperesc initializing...")

// Create key handler and event tap
let keyHandler = KeyHandler(config: config)
let eventTap = EventTap(keyHandler: keyHandler, verbose: config.verbose)

// Start the event tap
guard eventTap.start() else {
    fputs("ERROR: Failed to start event tap.\n", stderr)
    exit(1)
}

print("hyperesc running. Press Ctrl+C to quit.")

// Handle SIGINT (Ctrl+C) for clean shutdown
signal(SIGINT) { _ in
    print("\nhyperesc shutting down...")
    exit(0)
}

// Run the event loop (blocks until terminated)
eventTap.run()
