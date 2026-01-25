import CoreGraphics
import Foundation

/// Configuration for the key handler
struct Config {
    let useFullHyper: Bool
    let verbose: Bool
}

/// State machine states for Caps Lock handling
enum KeyState {
    case idle
    case held(pressTime: TimeInterval)
    case modified
}

/// Handles the Caps Lock key state machine and event synthesis
class KeyHandler {
    private var state: KeyState = .idle
    let config: Config

    init(config: Config) {
        self.config = config
    }

    /// Called when Caps Lock (F18) is pressed
    func handleCapsLockDown(timestamp: TimeInterval) {
        state = .held(pressTime: timestamp)
        if config.verbose {
            fputs("[KeyHandler] CapsLock DOWN, entering held state\n", stderr)
        }
    }

    /// Called when Caps Lock is released
    /// Returns true if Escape should be emitted (pressed alone, no other key was pressed)
    func handleCapsLockUp(timestamp: TimeInterval) -> Bool {
        switch state {
        case .held(let pressTime):
            // Caps Lock was pressed and released without pressing any other key
            // Emit Escape regardless of how long it was held
            let elapsed = timestamp - pressTime
            state = .idle
            if config.verbose {
                fputs("[KeyHandler] CapsLock UP after \(Int(elapsed * 1000))ms, pressed alone -> emit Escape\n", stderr)
            }
            return true

        case .modified:
            // Another key was pressed while Caps Lock was held - don't emit Escape
            state = .idle
            if config.verbose {
                fputs("[KeyHandler] CapsLock UP, was used as modifier -> no Escape\n", stderr)
            }
            return false

        case .idle:
            return false
        }
    }

    /// Check if Caps Lock is currently held
    var isCapsLockHeld: Bool {
        switch state {
        case .held, .modified:
            return true
        case .idle:
            return false
        }
    }

    /// Called when another key is pressed while Caps Lock is held
    func handleOtherKeyPressed() {
        if case .held = state {
            state = .modified
            if config.verbose {
                fputs("[KeyHandler] Other key pressed, entering modified state\n", stderr)
            }
        }
    }

    /// Emit an Escape key press and release
    func postEscapeKey() {
        let escapeKeyCode: CGKeyCode = 0x35

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: escapeKeyCode, keyDown: true) else {
            return
        }
        keyDown.post(tap: .cghidEventTap)

        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: escapeKeyCode, keyDown: false) else {
            return
        }
        keyUp.post(tap: .cghidEventTap)

        if config.verbose {
            fputs("[KeyHandler] Posted Escape key\n", stderr)
        }
    }

    /// Add Cmd+Opt (or full hyper) modifiers to an event
    func addModifiers(to event: CGEvent) -> CGEvent? {
        guard let modifiedEvent = event.copy() else { return nil }

        var flags = modifiedEvent.flags
        if config.useFullHyper {
            flags.insert([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        } else {
            flags.insert([.maskCommand, .maskAlternate])
        }
        modifiedEvent.flags = flags

        if config.verbose {
            fputs("[KeyHandler] Added modifiers to key event\n", stderr)
        }

        return modifiedEvent
    }
}
