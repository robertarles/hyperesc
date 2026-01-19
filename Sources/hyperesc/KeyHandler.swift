import Foundation

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
}
