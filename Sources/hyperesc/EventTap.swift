import CoreGraphics
import Foundation

// Key codes
// Caps Lock is remapped to F18 (0x4F = 79) via hidutil to avoid system Caps Lock behavior
private let kCapsLockKeyCode: Int64 = 57  // Original Caps Lock (for flagsChanged)
private let kF18KeyCode: Int64 = 79       // F18 (remapped Caps Lock)

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

        // Handle F18 (remapped Caps Lock via hidutil)
        // F18 comes as keyDown/keyUp events, not flagsChanged
        if keyCode == kF18KeyCode {
            if type == .keyDown {
                keyHandler.handleCapsLockDown(timestamp: timestamp)
                if verbose {
                    print("[EventTap] F18 (Caps Lock) DOWN")
                }
            } else if type == .keyUp {
                if keyHandler.handleCapsLockUp(timestamp: timestamp) {
                    keyHandler.postEscapeKey()
                }
                if verbose {
                    print("[EventTap] F18 (Caps Lock) UP")
                }
            }
            // Suppress the F18 event
            return nil
        }

        // Handle original Caps Lock flagsChanged (backup, in case hidutil remap not active)
        if type == .flagsChanged && keyCode == kCapsLockKeyCode {
            let flags = event.flags

            if flags.contains(.maskAlphaShift) {
                keyHandler.handleCapsLockDown(timestamp: timestamp)
            } else {
                if keyHandler.handleCapsLockUp(timestamp: timestamp) {
                    keyHandler.postEscapeKey()
                }
            }
            return nil
        }

        // Handle other key events while Caps Lock is held
        if type == .keyDown && keyHandler.isCapsLockHeld {
            keyHandler.handleOtherKeyPressed()

            // Inject hyper modifiers
            if let modifiedEvent = keyHandler.postModifiedKey(event: event) {
                return Unmanaged.passRetained(modifiedEvent)
            }
        }

        // Pass through all other events unchanged
        return Unmanaged.passUnretained(event)
    }
}
