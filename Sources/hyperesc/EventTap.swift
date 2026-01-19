import CoreGraphics
import Foundation

// Caps Lock virtual key code
private let kCapsLockKeyCode: Int64 = 57

// Global callback function for CGEvent tap
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let eventTap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
    return eventTap.handleEvent(proxy: proxy, type: type, event: event)
}

class EventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let keyHandler: KeyHandler
    private let verbose: Bool

    init(keyHandler: KeyHandler, verbose: Bool) {
        self.keyHandler = keyHandler
        self.verbose = verbose
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        // Event mask for key events and modifier changes
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                                      (1 << CGEventType.keyUp.rawValue) |
                                      (1 << CGEventType.flagsChanged.rawValue)

        // Create event tap
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            fputs("ERROR: Failed to create event tap. Check Accessibility permissions.\n", stderr)
            return false
        }

        eventTap = tap

        // Create run loop source
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            fputs("ERROR: Failed to create run loop source.\n", stderr)
            eventTap = nil
            return false
        }

        runLoopSource = source

        // Add to run loop and enable
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        if verbose {
            print("[EventTap] Event tap created and enabled")
        }

        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)

            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
                runLoopSource = nil
            }

            CFMachPortInvalidate(tap)
            eventTap = nil

            if verbose {
                print("[EventTap] Event tap stopped")
            }
        }
    }

    func run() {
        if verbose {
            print("[EventTap] Starting run loop...")
        }
        CFRunLoopRun()
    }

    // MARK: - Event Handling

    fileprivate func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disabled events (e.g., secure input fields)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                if verbose {
                    print("[EventTap] Re-enabled tap after disable")
                }
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let timestamp = Double(event.timestamp) / 1_000_000_000.0  // Convert to seconds

        // Handle Caps Lock (flagsChanged event with keycode 57)
        if type == .flagsChanged && keyCode == kCapsLockKeyCode {
            let flags = event.flags

            if flags.contains(.maskAlphaShift) {
                // Caps Lock pressed down
                keyHandler.handleCapsLockDown(timestamp: timestamp)
            } else {
                // Caps Lock released
                if keyHandler.handleCapsLockUp(timestamp: timestamp) {
                    keyHandler.postEscapeKey()
                }
            }

            // Suppress the Caps Lock event (don't toggle Caps Lock LED)
            return nil
        }

        // Handle other key events while Caps Lock might be held
        if type == .keyDown {
            keyHandler.handleOtherKeyPressed()

            // If we're in modified state, inject hyper modifiers
            if let modifiedEvent = keyHandler.postModifiedKey(event: event) {
                return Unmanaged.passRetained(modifiedEvent)
            }
        }

        // Pass through all other events unchanged
        return Unmanaged.passUnretained(event)
    }
}
