#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="taradino"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/fabiangreffrath/taradino.git"
SOURCE_DIR="taradino"

echo "=== Starting packaging process for ${PKG_NAME} on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the engine source code repository
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning Taradino source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Configure and compile using CMake
echo "-> Formatting build directories via CMake..."
cmake ./
echo "-> Compiling Taradino binary with $(nproc) threads..."
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/taradino"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binary into architecture-specific staging execution folder tree
echo "-> Copying executable targets..."
if [ -f "$SOURCE_DIR/taradino" ]; then
    cp "$SOURCE_DIR/taradino" "$DIR_NAME/usr/lib/${TRIPLET}/taradino/taradino-bin"
else
    echo "Error: Compiled binary 'taradino' not found in source directory."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles multiarch paths dynamically
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/taradino"
#!/bin/bash
# 1. Ensure the user's custom home folder exists
mkdir -p "$HOME/.taradino"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Hop inside your personal directory context so all generated files/saves land safely inside it
cd "$HOME/.taradino"

# 4. Launch the primary engine binary context natively 
exec /usr/lib/${TRIPLET}/taradino/taradino-bin "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/taradino"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/taradino.desktop"
[Desktop Entry]
Name=Taradino (Rise of the Triad)
Comment=SDL2 port of Rise of the Triad
Exec=/usr/games/taradino
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
Depends: libsdl2-2.0-0, libsdl2-mixer-2.0-0, libgl1
Description: Taradino engine port for Rise of the Triad (Multiarch Build)
 Taradino is a modern SDL2 source port of Apogee's classic 1994 
 3D action title Rise of the Triad, bringing modern OS compatibility.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv2 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: taradino
Source: ${REPO_URL}

Files: *
Copyright: 1993-1994, James R. Dose
           1993-1996, Id Software, Inc.
           1993-2008, Raven Software
           1994-1995, Apogee Software, Ltd.
           2002-2015, Steven Fuller, Ryan C. Gordon, John Hall, Dan Olson
           2005-2018, Simon Howard
           2006-2025, Fabian Greffrath
           2023-2025, erysdren
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

