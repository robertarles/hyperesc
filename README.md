# hyperesc

A lightweight macOS utility that transforms Caps Lock into a dual-function key:

- **Tap** Caps Lock alone → Escape (on key release)
- **Hold** Caps Lock + another key → Hyper modifier (Cmd+Opt)

Written in Swift with zero dependencies. Single binary < 1MB.

## Features

- Caps Lock pressed alone emits Escape on release
- Caps Lock held with another key adds Cmd+Opt modifiers
- Configurable modifier: Cmd+Opt (default) or full Cmd+Opt+Ctrl+Shift
- Caps Lock LED stays off (no toggling)
- Minimal resource usage (< 0.1% CPU, < 5MB memory)
- Universal binary (Intel + Apple Silicon)
- No external dependencies

## Installation

### Quick Install (Recommended)

```bash
git clone https://github.com/robertarles/hyperesc.git
cd hyperesc
sudo ./build.sh app-bundle
```

This will:

1. Build a universal binary
2. Create `/Applications/hyperesc.app`
3. Install a LaunchAgent for auto-start
4. Print setup instructions

### Manual Build

```bash
./build.sh              # Build only
./build.sh install      # Build and install to /usr/local/bin
```

### Uninstall

```bash
# Remove app bundle, LaunchAgent, and restore Caps Lock
./build.sh uninstall-app

# Remove from /usr/local/bin only
./build.sh uninstall
```

## Permissions

hyperesc requires **Accessibility** permission to intercept keyboard events.

1. Run hyperesc (it will prompt for permission)
2. Go to **System Settings → Privacy & Security → Accessibility**
3. Enable **hyperesc** in the list
4. Restart hyperesc

## Usage

```bash
# Start manually
/Applications/hyperesc.app/Contents/MacOS/hyperesc

# With options
/Applications/hyperesc.app/Contents/MacOS/hyperesc -v        # Verbose mode
/Applications/hyperesc.app/Contents/MacOS/hyperesc -f        # Full hyper (Cmd+Opt+Ctrl+Shift)
```

### Options

| Flag | Description |
|------|-------------|
| `-f, --full-hyper` | Use full Hyper key (Cmd+Opt+Ctrl+Shift) |
| `-v, --verbose` | Enable verbose debug output |
| `-h, --help` | Display help information |

## Auto-Start

The `app-bundle` install automatically creates a LaunchAgent. To enable:

```bash
# Enable auto-start
launchctl load ~/Library/LaunchAgents/com.robertarles.hyperesc.plist

# Disable auto-start
launchctl unload ~/Library/LaunchAgents/com.robertarles.hyperesc.plist

# Check if running
launchctl list | grep hyperesc
```

Logs are written to `/tmp/hyperesc.out` and `/tmp/hyperesc.err`.

## How It Works

1. `hidutil` remaps Caps Lock at the HID level (prevents LED toggling)
2. CGEventTap intercepts keyboard events
3. When Caps Lock is pressed, hyperesc enters "held" state
4. If released without pressing another key → Escape is emitted
5. If another key is pressed while held → Cmd+Opt modifiers are added
6. On exit, Caps Lock mapping is restored to default

## Troubleshooting

### "Accessibility permission required" error

- Grant permission in System Settings → Privacy & Security → Accessibility
- After granting, restart hyperesc

### hyperesc doesn't appear in Accessibility list

Use the app bundle installation: `sudo ./build.sh app-bundle`

### Not working in certain apps

Some apps use "secure input" mode (password fields) which disables event taps. This is expected macOS security behavior.

## Known Limitations

- **Secure input fields**: Event tap disabled in password prompts
- **Login screen**: Cannot run before login (requires user session)

## Build Commands

| Command | Description |
|---------|-------------|
| `./build.sh` | Build universal binary |
| `sudo ./build.sh app-bundle` | Create app bundle + LaunchAgent (recommended) |
| `./build.sh install` | Install to /usr/local/bin |
| `./build.sh uninstall-app` | Remove app bundle, LaunchAgent, restore Caps Lock |
| `./build.sh uninstall` | Remove from /usr/local/bin |
| `./build.sh clean` | Clean build artifacts |

## License

MIT
