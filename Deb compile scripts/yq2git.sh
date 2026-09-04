#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="yamagiquake2"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/yquake2/yquake2.git"
SOURCE_DIR="yquake2"

echo "=== Starting packaging process for ${PKG_NAME} master version ${VERSION} on ${ARCH} ==="

# 2. Clone or update the engine source code repository directly from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning live Yamagi Quake II source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest master commits..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Compile the binaries using multi-core optimizations
echo "-> Compiling engine with $(nproc) threads..."
make clean
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/yquake2/baseq2"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binaries and internal shared objects from release into staging
echo "-> Copying executable targets and library mods from release..."
if [ -f "$SOURCE_DIR/release/quake2" ]; then
    # Copy primary client program to the multiarch system path
    cp "$SOURCE_DIR/release/quake2" "$DIR_NAME/usr/lib/${TRIPLET}/yquake2/yquake2-bin"
    
    # Isolate dedicated server binary into triplet folder and link globally
    cp "$SOURCE_DIR/release/q2ded" "$DIR_NAME/usr/lib/${TRIPLET}/yquake2/q2ded-bin"
    ln -s /usr/lib/${TRIPLET}/yquake2/q2ded-bin "$DIR_NAME/usr/games/yq2ded"
    
    # Copy Yamagi engine baseline shared libraries (.so modules) into triplet structure
    cp "$SOURCE_DIR/release/baseq2/game.so" "$DIR_NAME/usr/lib/${TRIPLET}/yquake2/baseq2/"
    
    # Copy renderer and utility shared libraries from the root of release folder
    cp "$SOURCE_DIR"/release/*.so "$DIR_NAME/usr/lib/${TRIPLET}/yquake2/" 2>/dev/null || true
else
    echo "Error: Compiled engine binaries not detected in expected layout ($SOURCE_DIR/release)."
    exit 1
fi

# 6. Create a smart multiarch-aware startup script wrapper that handles your home data folder setup safely
echo "-> Creating application launcher wrapper..."
cat << 'EOF' > "$DIR_NAME/usr/games/yquake2"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists
mkdir -p "$HOME/.yquake2/baseq2"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Automatically map all architecture-specific system rendering modules into the user's home folder
ln -sf /usr/lib/${TRIPLET}/yquake2/*.so "$HOME/.yquake2/"

# 4. Launch the primary engine binary targeting the user's home data folder safely
exec /usr/lib/${TRIPLET}/yquake2/yquake2-bin -datadir "$HOME/.yquake2" "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/yquake2"

# 7. Create the standard desktop shortcut launcher file pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/yamagiquake2.desktop"
[Desktop Entry]
Name=Yamagi Quake II (Git Master)
Comment=Modern enhanced source port of Quake II - Development Build
Exec=/usr/games/yquake2
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
Depends: libsdl2-2.0-0, libgl1, libopenal1, libcurl4
Description: Yamagi Quake II engine source port (Development Build)
 Yamagi Quake II is an enhanced, incredibly stable client port of id 
 Software's classic Quake II. Built and packaged straight from master source.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv2 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: yamagiquake2
Source: ${REPO_URL}

Files: *
Copyright: 1997-2001 id Software, Inc.
           2006-2026 Fabian Greffrath and the Yamagi Quake II contributors
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

