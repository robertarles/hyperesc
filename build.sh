#!/bin/bash
#
# build.sh - Build script for hyperesc
#
# Usage:
#   ./build.sh              Build universal binary
#   ./build.sh install      Build and install to /usr/local/bin
#   ./build.sh uninstall    Remove from /usr/local/bin
#   ./build.sh clean        Clean build artifacts
#

set -e

PRODUCT_NAME="hyperesc"
BUILD_DIR=".build"
RELEASE_DIR="$BUILD_DIR/release"
INSTALL_DIR="/usr/local/bin"
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
    clean)
        clean
        ;;
    *)
        echo "Usage: $0 {build|install|uninstall|clean}"
        exit 1
        ;;
esac
