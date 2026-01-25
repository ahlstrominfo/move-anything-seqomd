# Building Without Docker

This guide covers building Move Anything natively on macOS and Windows without Docker.

## Overview

Move Anything targets **Ableton Move** which runs ARM64 Linux (aarch64). Building requires a cross-compiler toolchain to produce ARM64 binaries from your x86/ARM Mac or PC.

## macOS

### Quick Start

```bash
./scripts/build-macos.sh
```

This script automatically:
1. Installs the ARM64 Linux cross-compiler via Homebrew (first run only)
2. Builds QuickJS for ARM64
3. Builds Move Anything
4. Creates `move-anything.tar.gz`

### Script Options

```bash
./scripts/build-macos.sh              # Full build (install toolchain if needed)
./scripts/build-macos.sh --install    # Only install toolchain
./scripts/build-macos.sh --build      # Only build (skip toolchain check)
./scripts/build-macos.sh --help       # Show help
```

### Manual Installation

If you prefer to install the toolchain manually:

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add the cross-toolchain tap
brew tap messense/macos-cross-toolchains

# Install ARM64 Linux cross-compiler
brew install aarch64-unknown-linux-gnu
```

### Manual Build

After installing the toolchain:

```bash
# Build QuickJS
cd libs/quickjs/quickjs-2025-04-26
CC=aarch64-unknown-linux-gnu-gcc make libquickjs.a
cd ../../..

# Build Move Anything
CROSS_PREFIX=aarch64-unknown-linux-gnu- ./scripts/build.sh

# Create package
./scripts/package.sh
```

### Requirements

- **macOS** 10.15+ (Catalina or later)
- **Homebrew** - https://brew.sh
- ~2GB disk space for toolchain

### Troubleshooting (macOS)

**"brew: command not found"**
Install Homebrew from https://brew.sh

**"aarch64-unknown-linux-gnu-gcc: command not found"**
```bash
brew tap messense/macos-cross-toolchains
brew install aarch64-unknown-linux-gnu
```

**QuickJS build fails with missing headers**
Ensure you're using the cross-compiler, not the system compiler:
```bash
CC=aarch64-unknown-linux-gnu-gcc make libquickjs.a
```

**Binary shows wrong architecture**
```bash
file build/move-anything
# Should show: ELF 64-bit LSB executable, ARM aarch64
```

If it shows x86_64 or Mach-O, the native compiler was used instead of the cross-compiler.

---

## Windows

### Option 1: WSL2 (Recommended)

Windows Subsystem for Linux provides the best experience.

#### Setup WSL2

1. Open PowerShell as Administrator:
   ```powershell
   wsl --install -d Ubuntu
   ```

2. Restart your computer

3. Open Ubuntu from Start menu and complete setup

#### Install Toolchain

```bash
sudo apt update
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu make
```

#### Build

```bash
# Clone repo (or access from Windows via /mnt/c/...)
cd /path/to/move-anything

# Build QuickJS
cd libs/quickjs/quickjs-2025-04-26
CC=aarch64-linux-gnu-gcc make libquickjs.a
cd ../../..

# Build Move Anything
CROSS_PREFIX=aarch64-linux-gnu- ./scripts/build.sh

# Create package
./scripts/package.sh
```

### Option 2: MSYS2

MSYS2 provides a Unix-like environment on Windows.

#### Setup

1. Download and install MSYS2 from https://www.msys2.org

2. Open MSYS2 UCRT64 terminal

3. Install dependencies:
   ```bash
   pacman -Syu
   pacman -S make git
   ```

4. Install cross-compiler (if available in repos):
   ```bash
   pacman -S mingw-w64-ucrt-x86_64-aarch64-linux-gnu-gcc
   ```

   Note: ARM64 Linux cross-compiler availability in MSYS2 varies. WSL2 is more reliable.

### Option 3: Docker Desktop for Windows

If native options don't work, Docker Desktop remains the most reliable:

```powershell
./scripts/build-docker.sh
```

### Troubleshooting (Windows)

**WSL2 not available**
- Requires Windows 10 version 2004+ or Windows 11
- Enable "Windows Subsystem for Linux" in Windows Features

**Permission denied errors in WSL**
Don't build from `/mnt/c/` (Windows filesystem). Clone the repo inside WSL's native filesystem (`~` or `/home/user/`).

**Slow build in WSL**
Building from the Windows filesystem (`/mnt/c/`) is slow. Clone the repo to the Linux filesystem for better performance.

---

## Verifying the Build

After building, verify the output:

```bash
# Check binary architecture
file build/move-anything
# Expected: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), dynamically linked...

# Check shared library
file build/move-anything-shim.so
# Expected: ELF 64-bit LSB shared object, ARM aarch64...

# Check module DSP
file build/modules/seqomd/dsp.so
# Expected: ELF 64-bit LSB shared object, ARM aarch64...
```

## Installing on Move

After a successful build:

```bash
./scripts/install.sh local
```

Or manually:

```bash
scp move-anything.tar.gz ableton@move.local:~/
ssh ableton@move.local 'tar -xf move-anything.tar.gz'
```

## Cross-Compiler Reference

| Platform | Toolchain Package | Prefix |
|----------|------------------|--------|
| macOS (Homebrew) | `aarch64-unknown-linux-gnu` | `aarch64-unknown-linux-gnu-` |
| Debian/Ubuntu | `gcc-aarch64-linux-gnu` | `aarch64-linux-gnu-` |
| Fedora | `gcc-aarch64-linux-gnu` | `aarch64-linux-gnu-` |
| Arch Linux | `aarch64-linux-gnu-gcc` | `aarch64-linux-gnu-` |

The `CROSS_PREFIX` environment variable tells the build script which prefix to use for gcc, g++, strip, etc.
