#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="yamagiquake2-remaster"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/yquake2/yquake2remaster.git"
SOURCE_DIR="yquake2remaster"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the repository directly from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning Yamagi Quake II Remaster source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest commits..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Configure via CMake and compile with multi-core optimizations
echo "-> Formatting build directories via CMake..."
cmake ./
echo "-> Compiling engine binaries with $(nproc) threads..."
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/yquake2remaster/baseq2"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binaries and modular renderer components from the verified release folder
echo "-> Copying executable targets and library modules from release..."
if [ -f "$SOURCE_DIR/release/quake2" ]; then
    # Copy primary client program and dedicated server
    cp "$SOURCE_DIR/release/quake2" "$DIR_NAME/usr/games/yquake2-remaster"
    cp "$SOURCE_DIR/release/q2ded" "$DIR_NAME/usr/games/yq2ded-remaster"
    
    # Copy baseline core game engine logic shared object library
    if [ -f "$SOURCE_DIR/release/baseq2/game.so" ]; then
        cp "$SOURCE_DIR/release/baseq2/game.so" "$DIR_NAME/usr/lib/yquake2remaster/baseq2/"
    fi
    
    # Copy renderer subsystem dynamic libraries (*.so drivers: gl1, gl3, gl4, gles3, soft, vk)
    cp "$SOURCE_DIR"/release/*.so "$DIR_NAME/usr/lib/yquake2remaster/" 2>/dev/null || true
else
    echo "Error: Compiled engine binaries not detected in $SOURCE_DIR/release"
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/yamagiquake2-remaster.desktop"
[Desktop Entry]
Name=Yamagi Quake II Remaster
Comment=Yamagi Quake II fork with Quake II Enhanced/Remaster support
Exec=/usr/games/yquake2-remaster
Terminal=false
Type=Application
Categories=Game;ActionGame;
EOF

# 7. Generate the Debian control file dynamically with the live version stamp
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1, libopenal1, libcurl4, libvulkan1
Description: Yamagi Quake II engine fork for Q2 Remaster assets
 An experimental fork of Yamagi Quake II featuring modern renderers
 and structural compatibility with Nightdive Studios' Quake II Enhanced.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
