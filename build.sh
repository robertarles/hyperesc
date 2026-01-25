#!/bin/bash
#
# build.sh - Build script for hyperesc
#
# Usage:
#   ./build.sh              Build universal binary
#   ./build.sh install      Build and install to /usr/local/bin
#   ./build.sh uninstall    Remove from /usr/local/bin
#   ./build.sh app-bundle   Create app bundle + LaunchAgent (recommended)
#   ./build.sh uninstall-app Remove app bundle, LaunchAgent, and restore Caps Lock
#   ./build.sh clean        Clean build artifacts
#

set -e

PRODUCT_NAME="hyperesc"
BUILD_DIR=".build"
RELEASE_DIR="$BUILD_DIR/release"
INSTALL_DIR="/usr/local/bin"
APP_BUNDLE_DIR="/Applications/hyperesc.app"
BUNDLE_ID="com.robertarles.hyperesc"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PLIST="$LAUNCH_AGENT_DIR/$BUNDLE_ID.plist"
MAX_SIZE=1048576  # 1MB in bytes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

clean() {
    log_info "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR"
    log_info "Clean complete."
}

build() {
    log_info "Building $PRODUCT_NAME for arm64..."
    swift build -c release --arch arm64

    log_info "Building $PRODUCT_NAME for x86_64..."
    swift build -c release --arch x86_64

    # Find the architecture-specific binaries
    ARM64_BINARY=$(find "$BUILD_DIR" -path "*arm64*" -name "$PRODUCT_NAME" -type f 2>/dev/null | head -1)
    X86_BINARY=$(find "$BUILD_DIR" -path "*x86_64*" -name "$PRODUCT_NAME" -type f 2>/dev/null | head -1)

    if [ -z "$ARM64_BINARY" ] || [ -z "$X86_BINARY" ]; then
        log_error "Could not find architecture-specific binaries"
        exit 1
    fi

    log_info "Creating universal binary..."
    mkdir -p "$RELEASE_DIR"
    lipo -create -output "$RELEASE_DIR/$PRODUCT_NAME" "$ARM64_BINARY" "$X86_BINARY"

    log_info "Stripping symbols..."
    strip "$RELEASE_DIR/$PRODUCT_NAME"

    # Verify size
    SIZE=$(stat -f%z "$RELEASE_DIR/$PRODUCT_NAME" 2>/dev/null || stat -c%s "$RELEASE_DIR/$PRODUCT_NAME")
    SIZE_KB=$((SIZE / 1024))

    if [ "$SIZE" -gt "$MAX_SIZE" ]; then
        log_warn "Binary size (${SIZE_KB}KB) exceeds 1MB target"
    else
        log_info "Binary size: ${SIZE_KB}KB"
    fi

    # Verify universal binary
    log_info "Verifying universal binary..."
    file "$RELEASE_DIR/$PRODUCT_NAME"

    # Check dependencies
    log_info "Dependencies:"
    otool -L "$RELEASE_DIR/$PRODUCT_NAME" | tail -n +2

    log_info "Build complete: $RELEASE_DIR/$PRODUCT_NAME"
}

install_binary() {
    if [ ! -f "$RELEASE_DIR/$PRODUCT_NAME" ]; then
        log_info "Binary not found, building first..."
        build
    fi

    log_info "Installing to $INSTALL_DIR..."
    sudo cp "$RELEASE_DIR/$PRODUCT_NAME" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/$PRODUCT_NAME"

    log_info "Verifying installation..."
    if command -v "$PRODUCT_NAME" &> /dev/null; then
        log_info "Installed successfully: $(which $PRODUCT_NAME)"
        "$PRODUCT_NAME" --help | head -3
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

uninstall_binary() {
    if [ -f "$INSTALL_DIR/$PRODUCT_NAME" ]; then
        log_info "Removing $INSTALL_DIR/$PRODUCT_NAME..."
        sudo rm "$INSTALL_DIR/$PRODUCT_NAME"
        log_info "Uninstalled successfully."
    else
        log_warn "$PRODUCT_NAME is not installed in $INSTALL_DIR"
    fi
}

app_bundle() {
    if [ ! -f "$RELEASE_DIR/$PRODUCT_NAME" ]; then
        log_info "Binary not found, building first..."
        build
    fi

    log_info "Creating app bundle at $APP_BUNDLE_DIR..."

    # Create bundle structure
    sudo mkdir -p "$APP_BUNDLE_DIR/Contents/MacOS"

    # Copy binary
    sudo cp "$RELEASE_DIR/$PRODUCT_NAME" "$APP_BUNDLE_DIR/Contents/MacOS/"
    sudo chmod +x "$APP_BUNDLE_DIR/Contents/MacOS/$PRODUCT_NAME"

    # Create Info.plist
    sudo tee "$APP_BUNDLE_DIR/Contents/Info.plist" > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>HyperEsc</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

    # Ad-hoc code sign the app bundle for stable Accessibility permissions
    log_info "Code signing app bundle (ad-hoc)..."
    sudo codesign --force --deep --sign - "$APP_BUNDLE_DIR"

    # Verify signature
    if codesign --verify --verbose "$APP_BUNDLE_DIR" 2>/dev/null; then
        log_info "Code signature verified successfully"
    else
        log_warn "Code signature verification returned warnings (ad-hoc signatures may show as 'invalid' but still work for permissions)"
    fi

    log_info "App bundle created: $APP_BUNDLE_DIR"

    # Create LaunchAgent plist
    log_info "Installing LaunchAgent to $LAUNCH_AGENT_PLIST..."
    mkdir -p "$LAUNCH_AGENT_DIR"
    cat > "$LAUNCH_AGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$BUNDLE_ID</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_BUNDLE_DIR/Contents/MacOS/$PRODUCT_NAME</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/hyperesc.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/hyperesc.out</string>
</dict>
</plist>
EOF

    log_info "LaunchAgent installed."
    log_info ""
    log_info "=============================================="
    log_info "SETUP COMPLETE"
    log_info "=============================================="
    log_info ""
    log_info "1. Grant Accessibility permission:"
    log_info "   System Settings -> Privacy & Security -> Accessibility"
    log_info "   Enable 'hyperesc'"
    log_info ""
    log_info "2. Enable auto-start (run once):"
    log_info "   launchctl load $LAUNCH_AGENT_PLIST"
    log_info ""
    log_info "3. Or start manually:"
    log_info "   $APP_BUNDLE_DIR/Contents/MacOS/$PRODUCT_NAME"
    log_info ""
    log_info "To disable auto-start:"
    log_info "   launchctl unload $LAUNCH_AGENT_PLIST"
    log_info ""
}

uninstall_app_bundle() {
    # Stop running hyperesc process
    if pgrep -x "$PRODUCT_NAME" > /dev/null; then
        log_info "Stopping running hyperesc process..."
        pkill -x "$PRODUCT_NAME" 2>/dev/null || true
        sleep 1
    fi

    # Unload and disable LaunchAgent
    if [ -f "$LAUNCH_AGENT_PLIST" ]; then
        log_info "Disabling LaunchAgent..."
        launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || \
            launchctl unload "$LAUNCH_AGENT_PLIST" 2>/dev/null || true
        log_info "Removing $LAUNCH_AGENT_PLIST..."
        rm -f "$LAUNCH_AGENT_PLIST"
        log_info "LaunchAgent removed."
    fi

    # Remove app bundle
    if [ -d "$APP_BUNDLE_DIR" ]; then
        log_info "Removing $APP_BUNDLE_DIR..."
        sudo rm -rf "$APP_BUNDLE_DIR"
        log_info "App bundle removed."
    else
        log_warn "App bundle not found at $APP_BUNDLE_DIR"
    fi

    # Remove Accessibility permission entry
    log_info "Removing Accessibility permission entry..."
    tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true

    # Restore Caps Lock mapping
    log_info "Restoring Caps Lock to default..."
    hidutil property --set '{"UserKeyMapping":[]}' > /dev/null
    log_info "Uninstall complete."
}

# Main
case "${1:-build}" in
    build)
        build
        ;;
    install)
        install_binary
        ;;
    uninstall)
        uninstall_binary
        ;;
    app-bundle)
        app_bundle
        ;;
    uninstall-app)
        uninstall_app_bundle
        ;;
    clean)
        clean
        ;;
    *)
        echo "Usage: $0 {build|install|uninstall|app-bundle|uninstall-app|clean}"
        exit 1
        ;;
esac
