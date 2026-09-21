#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="chocolate-doom3-bfg"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/klaussilveira/chocolate-doom3-bfg.git"
SOURCE_DIR="chocolate-doom3-bfg"

echo "=== Starting packaging process for ${PKG_NAME} on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the engine source code repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning live Chocolate DOOM-3-BFG source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest development commits..."
    cd "$SOURCE_DIR"
    git pull
    cd ..
fi

# 3. Configure and Compile using CMake out-of-source build rules
echo "-> Formatting build configuration via CMake..."
cmake -B "$SOURCE_DIR/build" -S "$SOURCE_DIR" -DCMAKE_BUILD_TYPE=Release
echo "-> Compiling engine targets with $(nproc) threads..."
cmake --build "$SOURCE_DIR/build" -j$(nproc)

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/chocolate-doom3-bfg"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy natively compiled binaries and engine asset dependencies into triplet paths
echo "-> Staging executable binaries and core engine targets..."
# The build output generates a primary binary named Doom3BFG or chocolate-doom3-bfg depending on platform setup
if [ -f "$SOURCE_DIR/build/Doom3BFG" ]; then
    cp "$SOURCE_DIR/build/Doom3BFG" "$DIR_NAME/usr/lib/${TRIPLET}/chocolate-doom3-bfg/chocolate-doom3-bfg-bin"
elif [ -f "$SOURCE_DIR/build/chocolate-doom3-bfg" ]; then
    cp "$SOURCE_DIR/build/chocolate-doom3-bfg" "$DIR_NAME/usr/lib/${TRIPLET}/chocolate-doom3-bfg/chocolate-doom3-bfg-bin"
else
    echo "Error: Compiled engine binary not detected inside the build/ layout root."
    exit 1
fi

# FIXED: Copy the internal base directory assets from the repository into system staging AFTER the build
echo "-> Copying internal base mechanics resources into the package layout..."
cp -r "$SOURCE_DIR/base" "$DIR_NAME/usr/lib/${TRIPLET}/chocolate-doom3-bfg/"

# 6. Create a smart multiarch startup script wrapper that handles home data folder setup safely
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/chocolate-doom3-bfg"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.chocolate-doom3-bfg/base"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Automatically symlink the package's internal engine base files right into the user home context
if [ -d "/usr/lib/${TRIPLET}/chocolate-doom3-bfg/base" ]; then
    ln -sf /usr/lib/${TRIPLET}/chocolate-doom3-bfg/base/* "$HOME/.chocolate-doom3-bfg/base/" 2>/dev/null || true
fi

# 4. Hop inside your personal directory context so all generated files land safely inside it
cd "$HOME/.chocolate-doom3-bfg"

# 5. Launch the primary engine binary context natively passing down parameters
exec /usr/lib/${TRIPLET}/chocolate-doom3-bfg/chocolate-doom3-bfg-bin "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/chocolate-doom3-bfg"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/chocolate-doom3-bfg.desktop"
[Desktop Entry]
Name=Chocolate Doom 3 BFG
Comment=Doom 3 BFG Edition source port focused on preserving the original experience
Exec=/usr/games/chocolate-doom3-bfg
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
Provides: doom-engine
License: GPL-3.0-only
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libopenal1, libgl1
Description: Doom 3 BFG source port focused on preserving the vanilla experience (Multiarch)
 Chocolate DOOM-3-BFG is a source port of Doom 3: BFG Edition, forked from 
 RBDOOM-3-BFG. It accurately reproduces the vanilla gameplay and visual 
 aesthetic while leveraging modern performance and compatibility fixes.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv3 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: chocolate-doom3-bfg
Source: ${REPO_URL}

Files: *
Copyright: 2004-2012 id Software, Inc.
           2012-2026 Robert Beckebans and the RBDOOM-3-BFG contributors
           2023-2026 Klaus Silveira and the chocolate-doom3-bfg contributors
License: GPL-3.0-only
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 3 can be found in "/usr/share/common-licenses/GPL-3".
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
