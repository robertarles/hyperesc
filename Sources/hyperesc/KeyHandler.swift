import Foundation
import CoreGraphics

enum KeyState {
    case idle
    case held(pressTime: TimeInterval)
    case modified
}

class KeyHandler {
    private var state: KeyState = .idle
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func handleCapsLockDown(timestamp: TimeInterval) {
        state = .held(pressTime: timestamp)
        if config.verbose {
            print("[KeyHandler] CapsLock DOWN - state: held")
        }
    }

    func handleCapsLockUp(timestamp: TimeInterval) -> Bool {
        switch state {
        case .held(let pressTime):
            let elapsed = timestamp - pressTime
            let thresholdSeconds = Double(config.tapThreshold) / 1000.0
            let shouldEmitEscape = elapsed < thresholdSeconds
            if config.verbose {
                print("[KeyHandler] CapsLock UP - elapsed: \(Int(elapsed * 1000))ms, threshold: \(config.tapThreshold)ms, emit escape: \(shouldEmitEscape)")
            }
            state = .idle
            return shouldEmitEscape
        case .modified:
            if config.verbose {
                print("[KeyHandler] CapsLock UP - was modified, no escape")
            }
            state = .idle
            return false
        case .idle:
            return false
        }
    }

    func handleOtherKeyPressed() {
        if case .held = state {
            state = .modified
            if config.verbose {
                print("[KeyHandler] Other key pressed - state: modified")
            }
        }
    }

    // MARK: - Event Synthesis

    /// Synthesizes an Escape key press (down + up)
    func postEscapeKey() {
        let escapeKeyCode: CGKeyCode = 0x35

        // Escape key down
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: escapeKeyCode, keyDown: true) else {
            if config.verbose {
                print("[KeyHandler] ERROR: Failed to create Escape keyDown event")
            }
            return
        }
        keyDown.post(tap: .cghidEventTap)

        // Escape key up
        guard let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: escapeKeyCode, keyDown: false) else {
            if config.verbose {
                print("[KeyHandler] ERROR: Failed to create Escape keyUp event")
            }
            return
        }
        keyUp.post(tap: .cghidEventTap)

        if config.verbose {
            print("[KeyHandler] Posted Escape key (0x35)")
        }
    }

    /// Copies an event and injects modifier flags based on config
    func postModifiedKey(event: CGEvent) -> CGEvent? {
        guard let modifiedEvent = event.copy() else {
            if config.verbose {
                print("[KeyHandler] ERROR: Failed to copy event for modifier injection")
            }
            return nil
        }

        // Set modifier flags based on config
        var flags = modifiedEvent.flags
        if config.useFullHyper {
            // Full hyper: Cmd+Opt+Ctrl+Shift
            flags.insert([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        } else {
            // Default: Cmd+Opt
            flags.insert([.maskCommand, .maskAlternate])
        }
        modifiedEvent.flags = flags

        if config.verbose {
            let modifierStr = config.useFullHyper ? "Cmd+Opt+Ctrl+Shift" : "Cmd+Opt"
            print("[KeyHandler] Injected modifiers: \(modifierStr)")
        }

        return modifiedEvent
    }
}
