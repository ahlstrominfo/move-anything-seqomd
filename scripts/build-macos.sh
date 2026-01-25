#!/usr/bin/env bash
# Build Move Anything on macOS without Docker
#
# This script installs the ARM64 Linux cross-compiler toolchain via Homebrew
# and builds the project for Ableton Move (aarch64 Linux).
#
# Usage:
#   ./scripts/build-macos.sh           # Install toolchain if needed, then build
#   ./scripts/build-macos.sh --install # Only install toolchain
#   ./scripts/build-macos.sh --build   # Only build (assumes toolchain installed)
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
QUICKJS_DIR="$REPO_ROOT/libs/quickjs/quickjs-2025-04-26"

# Cross-compiler settings
CROSS_PREFIX="aarch64-unknown-linux-gnu-"
HOMEBREW_TAP="messense/macos-cross-toolchains"
HOMEBREW_FORMULA="aarch64-unknown-linux-gnu"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}==>${NC} $1"; }
warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
error() { echo -e "${RED}Error:${NC} $1"; exit 1; }

check_macos() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script is for macOS only. Use Docker or WSL on other platforms."
    fi
}

check_homebrew() {
    if ! command -v brew &>/dev/null; then
        error "Homebrew is required. Install from https://brew.sh"
    fi
}

check_toolchain() {
    if command -v ${CROSS_PREFIX}gcc &>/dev/null; then
        return 0
    fi
    return 1
}

install_toolchain() {
    info "Installing ARM64 Linux cross-compiler toolchain..."

    # Add tap if not already added
    if ! brew tap | grep -q "$HOMEBREW_TAP"; then
        info "Adding Homebrew tap: $HOMEBREW_TAP"
        brew tap "$HOMEBREW_TAP"
    fi

    # Install cross-compiler
    if ! brew list "$HOMEBREW_FORMULA" &>/dev/null; then
        info "Installing $HOMEBREW_FORMULA (this may take a few minutes)..."
        brew install "$HOMEBREW_FORMULA"
    else
        info "Cross-compiler already installed"
    fi

    # Verify installation
    if ! check_toolchain; then
        error "Toolchain installation failed. ${CROSS_PREFIX}gcc not found in PATH."
    fi

    info "Toolchain installed successfully"
    ${CROSS_PREFIX}gcc --version | head -1
}

build_quickjs() {
    info "Building QuickJS for ARM64 Linux..."

    cd "$QUICKJS_DIR"

    # Clean previous build
    make clean 2>/dev/null || true

    # Build static library
    CC=${CROSS_PREFIX}gcc make libquickjs.a

    if [[ ! -f "libquickjs.a" ]]; then
        error "QuickJS build failed - libquickjs.a not found"
    fi

    info "QuickJS built successfully"
    cd "$REPO_ROOT"
}

build_project() {
    info "Building Move Anything..."

    cd "$REPO_ROOT"

    # Export cross-compiler prefix for build.sh
    export CROSS_PREFIX

    # Run the main build script
    ./scripts/build.sh

    # Package
    info "Creating package..."
    ./scripts/package.sh

    info "Build complete!"
    echo ""
    echo "Output: $REPO_ROOT/move-anything.tar.gz"
    echo ""
    echo "To install on Move:"
    echo "  ./scripts/install.sh local"
}

verify_binary() {
    local binary="$REPO_ROOT/build/move-anything"

    if [[ ! -f "$binary" ]]; then
        error "Build failed - binary not found at $binary"
    fi

    # Check architecture
    local arch=$(file "$binary")
    if [[ "$arch" != *"ARM aarch64"* ]]; then
        warn "Binary may not be correct architecture:"
        echo "$arch"
    else
        info "Binary architecture verified: ARM64"
    fi
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build Move Anything for Ableton Move on macOS without Docker."
    echo ""
    echo "Options:"
    echo "  --install    Only install the cross-compiler toolchain"
    echo "  --build      Only build (skip toolchain check/install)"
    echo "  --help       Show this help message"
    echo ""
    echo "With no options, installs toolchain if needed and builds the project."
}

main() {
    local install_only=false
    local build_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                install_only=true
                shift
                ;;
            --build)
                build_only=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    echo "=== Move Anything macOS Build ==="
    echo ""

    check_macos
    check_homebrew

    if $install_only; then
        install_toolchain
        exit 0
    fi

    if ! $build_only; then
        # Check if toolchain is installed, install if not
        if ! check_toolchain; then
            warn "Cross-compiler not found. Installing..."
            install_toolchain
        else
            info "Cross-compiler found: ${CROSS_PREFIX}gcc"
        fi
    else
        # Build only - verify toolchain exists
        if ! check_toolchain; then
            error "Cross-compiler not found. Run with --install first or without --build."
        fi
    fi

    # Build QuickJS if needed
    if [[ ! -f "$QUICKJS_DIR/libquickjs.a" ]]; then
        build_quickjs
    else
        info "QuickJS already built (use 'make clean' in libs/quickjs/quickjs-2025-04-26 to rebuild)"
    fi

    # Build project
    build_project

    # Verify
    verify_binary

    echo ""
    info "Done!"
}

main "$@"
