#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="darkplaces"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/DarkPlacesEngine/DarkPlaces.git"
SOURCE_DIR="darkplaces"

echo "=== Starting packaging process for ${PKG_NAME} on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the source code (using lowercase variable target matching)
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning DarkPlaces source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository already exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Compile the specific sdl-release target using all available CPU threads
echo "-> Compiling DarkPlaces Engine with $(nproc) threads..."
make clean
make -j$(nproc) sdl-release
cd ..

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/darkplaces"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled SDL binary into the architecture-specific triplet library path
echo "-> Copying executable engine binaries..."
if [ -f "$SOURCE_DIR/darkplaces-sdl" ]; then
    cp "$SOURCE_DIR/darkplaces-sdl" "$DIR_NAME/usr/lib/${TRIPLET}/darkplaces/darkplaces-sdl-bin"
else
    echo "Error: Compiled binary 'darkplaces-sdl' not found in source directory."
    exit 1
fi

# 6. Create a smart startup script wrapper that resolves the triplet path context dynamically
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/darkplaces-sdl"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.darkplaces/id1"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Jump directly into your home folder context so the scanner reads your game data files natively
cd "$HOME/.darkplaces"

# 4. Launch the primary engine binary context safely passing down execution variables
exec /usr/lib/${TRIPLET}/darkplaces/darkplaces-sdl-bin "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/darkplaces-sdl"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/darkplaces.desktop"
[Desktop Entry]
Name=DarkPlaces
Comment=Advanced Quake 1 Engine Modification
Exec=/usr/games/darkplaces-sdl
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

# 8. Generate the Debian control file dynamically with the live version, architecture, and multiarch fields
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Multi-Arch: same
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libjpeg62-turbo, libpng16-16, libcurl4, libgl1
Description: DarkPlaces Quake engine port (Multiarch Build)
 DarkPlaces is an advanced, high-fidelity modification of the original
 Quake 1 engine featuring modern rendering and extended script support.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv2 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: darkplaces
Source: ${REPO_URL}

Files: *
Copyright: 1999-2026 Forest "LordHavoc" Hale, id Software, and the DarkPlaces contributors
License: GPL-2.0-or-later
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 2 can be found in "/usr/share/common-licenses/GPL-2".
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

