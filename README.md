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

### Install

```bash
./build.sh install
```

This copies the binary to `/usr/local/bin/`.

### Uninstall

```bash
./build.sh uninstall
```

## Permissions

hyperesc requires **Accessibility** permission to intercept keyboard events.

1. Run `hyperesc` - macOS will prompt for permission
2. Go to **System Settings → Privacy & Security → Accessibility**
3. Enable hyperesc (or Terminal if running from terminal)
4. Restart hyperesc

If the binary doesn't appear in the list, add Terminal.app (or your IDE) to Accessibility instead - child processes inherit the parent's permissions.

## Usage

```bash
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
hyperesc

# Use 150ms tap threshold
hyperesc -t 150

# Use full Hyper key (Cmd+Opt+Ctrl+Shift)
hyperesc --full-hyper

# Custom threshold, full hyper, verbose output
hyperesc -t 250 -f -v
```

## Auto-Start with LaunchAgent

To start hyperesc automatically on login:

1. Copy the plist template:
```bash
cp templates/com.user.hyperesc.plist ~/Library/LaunchAgents/
```

2. Edit the plist if needed (threshold, flags)

3. Load the agent:
```bash
launchctl load ~/Library/LaunchAgents/com.user.hyperesc.plist
```

4. To unload:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.hyperesc.plist
```

## How It Works

1. hyperesc creates a CGEventTap to intercept keyboard events
2. When Caps Lock is pressed, it starts a timer
3. If Caps Lock is released within the threshold (default 200ms) without pressing another key, Escape is emitted
4. If another key is pressed while Caps Lock is held, the Hyper modifiers are added to that key event
5. The original Caps Lock event is suppressed (LED doesn't toggle)

## Troubleshooting

### "Accessibility permission required" error

- Grant permission in System Settings → Privacy & Security → Accessibility
- If running from Terminal, add Terminal.app to the list
- After granting permission, restart hyperesc

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
- **Caps Lock LED**: The LED state is suppressed but may briefly flash on some keyboards
- **Login screen**: Cannot run before login (requires user session)

## Performance

- CPU usage (idle): < 0.1%
- Memory footprint: < 5MB
- Tap-to-Escape latency: < 10ms

## License

MIT
