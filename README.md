# hyperesc

A lightweight macOS utility that transforms Caps Lock into a dual-function key:

- **Tap** Caps Lock → Escape
- **Hold** Caps Lock + another key → Hyper modifier (Cmd+Opt by default)

Written in Swift with zero dependencies. Single binary < 1MB.

## Features

- Caps Lock tap emits Escape (configurable threshold)
- Caps Lock hold acts as Hyper key modifier
- Configurable modifier: Cmd+Opt (default) or full Cmd+Opt+Ctrl+Shift
- Minimal resource usage (< 0.1% CPU, < 5MB memory)
- Universal binary (Intel + Apple Silicon)
- No external dependencies

## Installation

### Build from Source

```bash
git clone https://github.com/robertarles/hyperesc.git
cd hyperesc
./build.sh
```

### Install as App Bundle (Recommended)

The app bundle installation is recommended because it allows hyperesc to appear in the macOS Accessibility permissions list with its own identity.

```bash
./build.sh app-bundle
```

This creates `/Applications/hyperesc.app`. Run it with:

```bash
/Applications/hyperesc.app/Contents/MacOS/hyperesc
```

### Alternative: Install to /usr/local/bin

```bash
./build.sh install
```

Note: When installed this way, hyperesc inherits permissions from its parent process (Terminal, VS Code, etc.). You'll need to grant Accessibility permission to the terminal app you use.

### Uninstall

```bash
# Remove app bundle
./build.sh uninstall-app

# Remove from /usr/local/bin
./build.sh uninstall
```

## Permissions

hyperesc requires **Accessibility** permission to intercept keyboard events.

### With App Bundle (Recommended)

1. Run `/Applications/hyperesc.app/Contents/MacOS/hyperesc`
2. macOS will prompt for Accessibility permission
3. Go to **System Settings → Privacy & Security → Accessibility**
4. Enable **hyperesc** in the list
5. Restart hyperesc

### With CLI Binary

If you installed to `/usr/local/bin`, you need to grant permission to your terminal app:

1. Go to **System Settings → Privacy & Security → Accessibility**
2. Add your terminal app (Terminal.app, WezTerm, iTerm2, etc.)
3. Run `hyperesc` from that terminal

## Usage

```bash
# From app bundle
/Applications/hyperesc.app/Contents/MacOS/hyperesc [OPTIONS]

# From /usr/local/bin
hyperesc [OPTIONS]
```

### Options

| Flag | Description |
|------|-------------|
| `-t, --threshold <ms>` | Tap threshold in milliseconds (default: 200) |
| `-f, --full-hyper` | Use full Hyper key (Cmd+Opt+Ctrl+Shift) |
| `-v, --verbose` | Enable verbose debug output |
| `-h, --help` | Display help information |

### Examples

```bash
# Run with defaults (200ms threshold, Cmd+Opt modifier)
/Applications/hyperesc.app/Contents/MacOS/hyperesc

# Use 150ms tap threshold
/Applications/hyperesc.app/Contents/MacOS/hyperesc -t 150

# Use full Hyper key (Cmd+Opt+Ctrl+Shift)
/Applications/hyperesc.app/Contents/MacOS/hyperesc --full-hyper

# Custom threshold, full hyper, verbose output
/Applications/hyperesc.app/Contents/MacOS/hyperesc -t 250 -f -v
```

## Auto-Start with Launch Agent

To start hyperesc automatically on login, create a Launch Agent plist:

1. Create the plist file:

```bash
cat > ~/Library/LaunchAgents/com.robertarles.hyperesc.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.robertarles.hyperesc</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/hyperesc.app/Contents/MacOS/hyperesc</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/hyperesc.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/hyperesc.err</string>
</dict>
</plist>
EOF
```

1. Load the agent:

```bash
launchctl load ~/Library/LaunchAgents/com.robertarles.hyperesc.plist
```

1. Verify it's running:

```bash
launchctl list | grep hyperesc
```

1. To stop/unload:

```bash
launchctl unload ~/Library/LaunchAgents/com.robertarles.hyperesc.plist
```

**Note:** Do not add hyperesc to Login Items when using a Launch Agent—the agent handles startup automatically.

## How It Works

1. hyperesc remaps Caps Lock to F18 at the HID level using `hidutil` (prevents system Caps Lock behavior)
2. Creates a CGEventTap to intercept keyboard events
3. When Caps Lock (now F18) is pressed, it starts a timer
4. If released within the threshold (default 200ms) without pressing another key, Escape is emitted
5. If another key is pressed while held, the Hyper modifiers are added to that key event
6. On exit, the Caps Lock mapping is restored

## Troubleshooting

### "Accessibility permission required" error

- Use the app bundle installation (`./build.sh app-bundle`) for easiest permission management
- Grant permission in System Settings → Privacy & Security → Accessibility
- After granting permission, restart hyperesc

### hyperesc doesn't appear in Accessibility list

This happens with CLI binaries on recent macOS versions. Solutions:

1. Use the app bundle: `./build.sh app-bundle`
2. Or grant permission to your terminal app instead

### Caps Lock LED still toggles

This can happen if another app is also intercepting Caps Lock. Check for conflicts with:

- Karabiner-Elements
- System keyboard settings
- Other key remapping tools

### Not working in certain apps

Some apps use "secure input" mode (e.g., password fields) which temporarily disables event taps. This is expected macOS security behavior.

### High CPU usage

Run with `--verbose` to check for issues. Normal idle CPU should be < 0.1%.

## Known Limitations

- **Secure input fields**: Event tap is disabled in password prompts and other secure input areas (macOS security feature)
- **Caps Lock LED**: The LED does not toggle (by design)
- **Login screen**: Cannot run before login (requires user session)

## Performance

- CPU usage (idle): < 0.1%
- Memory footprint: < 5MB
- Tap-to-Escape latency: < 10ms

## Build Commands

| Command | Description |
|---------|-------------|
| `./build.sh` | Build universal binary |
| `./build.sh app-bundle` | Create app bundle in /Applications |
| `./build.sh install` | Install to /usr/local/bin |
| `./build.sh uninstall-app` | Remove app bundle |
| `./build.sh uninstall` | Remove from /usr/local/bin |
| `./build.sh clean` | Clean build artifacts |

## License

MIT
