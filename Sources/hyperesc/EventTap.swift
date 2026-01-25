import CoreGraphics
import Foundation

// The hidutil remap converts Caps Lock to Escape (keycode 53)
private let kRemappedCapsLockKeyCode: Int64 = 53

/// Global callback function for CGEventTap (C calling convention)
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

/// Manages the CGEventTap for keyboard event interception
class EventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let keyHandler: KeyHandler

    init(keyHandler: KeyHandler) {
        self.keyHandler = keyHandler
    }

    /// Start the event tap
    func start() -> Bool {
        // Event mask: keyDown and keyUp
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        // Create the tap, passing self as userInfo
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            fputs("ERROR: Failed to create event tap. Check accessibility permissions.\n", stderr)
            return false
        }

        eventTap = tap

        // Create and add run loop source
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            fputs("ERROR: Failed to create run loop source.\n", stderr)
            return false
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        if keyHandler.config.verbose {
            fputs("[EventTap] Event tap started successfully\n", stderr)
        }

        return true
    }

    /// Run the event loop (blocks until terminated)
    func run() {
        CFRunLoopRun()
    }

    /// Stop the event tap
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    /// Handle an incoming event
    fileprivate func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Handle tap being disabled (e.g., secure input fields)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let timestamp = Double(event.timestamp) / 1_000_000_000.0

        // Handle the remapped Caps Lock (comes as Escape keycode 53 from hidutil)
        if keyCode == kRemappedCapsLockKeyCode {
            if type == .keyDown {
                // Caps Lock pressed - enter held state
                keyHandler.handleCapsLockDown(timestamp: timestamp)
                if keyHandler.config.verbose {
                    fputs("[EventTap] CapsLock DOWN (keycode 53)\n", stderr)
                }
                return nil  // Suppress - don't emit escape yet
            } else if type == .keyUp {
                // Caps Lock released - maybe emit escape
                if keyHandler.handleCapsLockUp(timestamp: timestamp) {
                    keyHandler.postEscapeKey()
                    if keyHandler.config.verbose {
                        fputs("[EventTap] CapsLock UP - emitting Escape\n", stderr)
                    }
                } else {
                    if keyHandler.config.verbose {
                        fputs("[EventTap] CapsLock UP - no Escape (was modifier)\n", stderr)
                    }
                }
                return nil  // Suppress the original event
            }
        }

        // Handle other keys while Caps Lock is held
        if type == .keyDown && keyHandler.isCapsLockHeld {
            keyHandler.handleOtherKeyPressed()
            if let modifiedEvent = keyHandler.addModifiers(to: event) {
                if keyHandler.config.verbose {
                    fputs("[EventTap] Added Cmd+Opt to keycode \(keyCode)\n", stderr)
                }
                return Unmanaged.passRetained(modifiedEvent)
            }
        }

        // Pass through unchanged
        return Unmanaged.passUnretained(event)
    }
}
