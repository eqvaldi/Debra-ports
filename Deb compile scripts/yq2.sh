#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and baked release version
VERSION="8.70"
ARCH="amd64"
PKG_NAME="yamagiquake2"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
ZIP_URL="https://github.com/yquake2/yquake2/archive/refs/tags/QUAKE2_8_70.zip"
SOURCE_DIR="yquake2-QUAKE2_8_70"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Fetch and prepare the explicit version archive source tree from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Downloading Yamagi Quake II source release zip..."
    wget -O source.zip "$ZIP_URL"
    echo "-> Unpacking zip archive..."
    unzip source.zip
    rm -f source.zip
else
    echo "-> Source folder '$SOURCE_DIR' already exists. Skipping download..."
fi

# 3. Compile the binaries using multi-core optimizations
echo "-> Entering source directory and compiling engine with $(nproc) threads..."
cd "$SOURCE_DIR"
make clean
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/yquake2/baseq2"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binaries and internal base mechanics libraries
echo "-> Copying executable targets and library mods from release..."
if [ -f "$SOURCE_DIR/release/quake2" ]; then
    # Copy primary client program and dedicated server
    cp "$SOURCE_DIR/release/quake2" "$DIR_NAME/usr/games/yquake2"
    cp "$SOURCE_DIR/release/q2ded" "$DIR_NAME/usr/games/yq2ded"
    
    # Copy Yamagi engine baseline shared libraries (.so modules) into library stack
    cp "$SOURCE_DIR/release/baseq2/game.so" "$DIR_NAME/usr/lib/yquake2/baseq2/"
    
    # Copy renderer and utility shared libraries from the root of release folder
    cp "$SOURCE_DIR"/release/*.so "$DIR_NAME/usr/lib/yquake2/" 2>/dev/null || true
else
    echo "Error: Compiled engine binaries not detected in expected layout ($SOURCE_DIR/release)."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/yamagiquake2.desktop"
[Desktop Entry]
Name=Yamagi Quake II
Comment=Modern enhanced source port of Quake II
Exec=/usr/games/yquake2
Terminal=false
Type=Application
Categories=Game;ActionGame;
EOF

# 7. Generate the Debian control file dynamically with the baked-in version
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1-mesa-glx, libopenal1, libcurl4
Description: Yamagi Quake II engine source port
 Yamagi Quake II is an enhanced, incredibly stable client port of id 
 Software's classic Quake II, focused on security, stability, and bugs.
 Automatically packaged on 2026-09-01.
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
