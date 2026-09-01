#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="ioquake3"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/ioquake/ioq3.git"
SOURCE_DIR="ioq3"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the engine source code repository
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning ioquake3 source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Configure workspace meta-blueprints and compile targets
echo "-> Formatting build directories via CMake..."
cmake ./
echo "-> Compiling core client and dedicated server binaries with $(nproc) threads..."
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/ioquake3"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binaries and modular renderer components into staging
echo "-> Copying executable targets and architecture binaries from Release/..."
if [ -f "$SOURCE_DIR/Release/ioquake3" ]; then
    # Copy main binaries
    cp "$SOURCE_DIR/Release/ioquake3" "$DIR_NAME/usr/games/ioquake3"
    cp "$SOURCE_DIR/Release/ioq3ded" "$DIR_NAME/usr/games/ioq3ded"
    
    # Copy library-level modular renderer extensions (.so drivers)
    cp "$SOURCE_DIR"/Release/renderer_opengl*.so "$DIR_NAME/usr/lib/ioquake3/" 2>/dev/null || true
    
    # Copy baseline code modules if generated
    if [ -d "$SOURCE_DIR/Release/baseq3" ]; then
        cp -r "$SOURCE_DIR/Release/baseq3" "$DIR_NAME/usr/lib/ioquake3/" 2>/dev/null || true
    fi
else
    echo "Error: Compiled engine binaries not detected in $SOURCE_DIR/Release/"
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/ioquake3.desktop"
[Desktop Entry]
Name=ioquake3
Comment=Community Quake III Arena Engine Evolution
Exec=/usr/games/ioquake3
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
Depends: libsdl2-2.0-0, libopenal1, libcurl4, libjpeg62-turbo
Description: ioquake3 engine port for Quake III Arena
 ioquake3 is the premier community-driven engine overhaul for id Software's 
 Quake III Arena, supporting modern 64-bit platforms, SDL2, and OpenAL.
 Automatically packaged on $(date).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
