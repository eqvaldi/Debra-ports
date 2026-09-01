#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="quakespasm"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/sezero/quakespasm.git"
SOURCE_DIR="quakespasm"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source code
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning QuakeSpasm source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR/Quake"
else
    echo "-> Repository already exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
    cd Quake
fi

# 3. Compile the SDL2 target using all available CPU threads
echo "-> Compiling QuakeSpasm Engine with $(nproc) threads..."
make clean
make USE_SDL2=1 -j$(nproc)
cd ../.. # Return back to script execution root

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/games/quakespasm"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binary and core asset pack file into staging
echo "-> Copying executable engine binaries and asset pack..."
if [ -f "$SOURCE_DIR/Quake/quakespasm" ]; then
    cp "$SOURCE_DIR/Quake/quakespasm" "$DIR_NAME/usr/games/"
    cp "$SOURCE_DIR/Quake/quakespasm.pak" "$DIR_NAME/usr/share/games/quakespasm/"
else
    echo "Error: Compiled binary 'quakespasm' not found."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/quakespasm.desktop"
[Desktop Entry]
Name=QuakeSpasm
Comment=Modern engine port of Quake 1 based on FitzQuake
Exec=/usr/games/quakespasm
Terminal=false
Type=Application
Categories=Game;ActionGame;
EOF

# 7. Generate the Debian control file dynamically
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libvorbisfile3, libmad0, libogg0
Description: QuakeSpasm engine port for Quake 1
 QuakeSpasm is a modern, cross-platform Quake engine port featuring
 high-fidelity 64-bit support, smooth SDL2 mouse input, and external music.
 Automatically packaged on $(date).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
