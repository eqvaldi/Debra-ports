#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="taradino"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/fabiangreffrath/taradino.git"
SOURCE_DIR="taradino"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

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

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binary into staging
echo "-> Copying executable targets..."
if [ -f "$SOURCE_DIR/taradino" ]; then
    cp "$SOURCE_DIR/taradino" "$DIR_NAME/usr/games/"
else
    echo "Error: Compiled binary 'taradino' not found in source directory."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/taradino.desktop"
[Desktop Entry]
Name=Taradino (Rise of the Triad)
Comment=SDL2 port of Rise of the Triad
Exec=/usr/games/taradino
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
Depends: libsdl2-2.0-0, libsdl2-mixer-2.0-0, libgl1
Description: Taradino engine port for Rise of the Triad
 Taradino is a modern SDL2 source port of Apogee's classic 1994 
 3D action title Rise of the Triad, bringing modern OS compatibility.
 Automatically packaged on $(date).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
