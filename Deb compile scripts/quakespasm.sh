#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="quakespasm"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/sezero/quakespasm.git"
SOURCE_DIR="quakespasm"

echo "=== Starting packaging process for ${PKG_NAME} on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the source code
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning QuakeSpasm source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR/Quake"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
    cd Quake
fi

# 3. Compile the SDL2 target with User Directory routing baked in
echo "-> Compiling QuakeSpasm Engine with $(nproc) threads..."
make clean
make USE_SDL2=1 DO_USERDIRS=1 -j$(nproc)
cd ../.. # Return back to script execution root

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/quakespasm"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binary and core asset pack file into architecture-specific paths
echo "-> Copying executable engine binaries and asset pack..."
if [ -f "$SOURCE_DIR/Quake/quakespasm" ]; then
    # Move raw binary and data pak to isolated system triplet library folder
    cp "$SOURCE_DIR/Quake/quakespasm" "$DIR_NAME/usr/lib/${TRIPLET}/quakespasm/quakespasm-bin"
    cp "$SOURCE_DIR/Quake/quakespasm.pak" "$DIR_NAME/usr/lib/${TRIPLET}/quakespasm/"
else
    echo "Error: Compiled binary 'quakespasm' not found."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles multiarch paths dynamically
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/quakespasm"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.quakespasm/id1"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Launch the primary engine binary context natively mapping the global layout asset file location
exec /usr/lib/${TRIPLET}/quakespasm/quakespasm-bin -userdir "$HOME/.quakespasm" -basedir "$HOME/.quakespasm" -pakdir /usr/lib/${TRIPLET}/quakespasm "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/quakespasm"

# 7. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/quakespasm.desktop"
[Desktop Entry]
Name=QuakeSpasm
Comment=Modern engine port of Quake 1 based on FitzQuake
Exec=/usr/games/quakespasm
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

# 8. Generate the Debian control file dynamically with the live version, architecture, and Multi-Arch fields
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Multi-Arch: same
License: GPL-2.0-or-later
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1, libvorbisfile3, libmad0, libogg0
Description: QuakeSpasm engine port for Quake 1 (Multiarch Build)
 QuakeSpasm is a modern, cross-platform Quake engine port featuring
 high-fidelity CPU support, smooth SDL2 mouse input, and external music.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv2 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: quakespasm
Source: ${REPO_URL}

Files: *
Copyright: 1999-2005 id Software, Inc.
           2010-2026 Anssi Hannula, Ozkan Sezer, Eric Wasylishen, and the QuakeSpasm contributors
License: GPL-2.0-or-later
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2 of the License.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 2 can be found in "/usr/share/common-licenses/GPL-2".
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
