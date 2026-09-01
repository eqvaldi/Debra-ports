#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="luanti"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/luanti-org/luanti.git"
SOURCE_DIR="luanti"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the main engine core repository
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning Luanti main platform engine source..."
    git clone --depth 1 "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Core engine directory exists. Pulling latest commits..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Pull sub-component dependencies into correct inner locations
echo "-> Checking out required library extensions and game asset trees..."

# IrrlichtMT graphic subsystem library framework binding 
if [ ! -d "lib/irrlichtmt" ]; then
    git clone --depth 1 https://github.com/minetest/irrlicht.git lib/irrlichtmt
else
    cd lib/irrlichtmt && git pull && cd ../..
fi

# FIXED: Ensure games folder structure exists explicitly inside the repository root
mkdir -p games

# Core Minetest sandbox base game asset profiles mapped directly to the internal games track
if [ ! -d "games/minetest_game" ]; then
    git clone --depth 1 https://github.com/minetest/minetest_game.git games/minetest_game
else
    cd games/minetest_game && git pull && cd ../..
fi

# Complementary Liminal Space Backrooms exploration mod module mapped to internal games track
if [ ! -d "games/backroomtest" ]; then
    git clone https://codeberg.org/SumianVoice/backroomtest.git games/backroomtest
else
    cd games/backroomtest && git pull && cd ../..
fi

# 4. Generate configurations and compile using standard system-wide install layouts
echo "-> Launching CMake configurations targeting global system layout paths..."
rm -rf build
mkdir -p build
cd build

cmake .. \
    -DRUN_IN_PLACE=FALSE \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_GETTEXT=TRUE \
    -DENABLE_SOUND=TRUE

echo "-> Building execution binaries utilizing $(nproc) threads..."
make -j$(nproc)

# Use CMake's staging system to safely direct the system install files into our packaging root
echo "-> Redirecting compiled engine installation hierarchy into staging target..."
cd ../..
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
make -C "$SOURCE_DIR/build" install DESTDIR="$PWD/$DIR_NAME"

# FIXED: Fallback verification loop to guarantee games are safely forced into package staging paths
# Maps data targets cleanly whether the target path uses 'luanti' or 'minetest' folder layout naming standards
DATA_PATH=$(find "$DIR_NAME/usr/share" -maxdepth 1 -type d \( -name "luanti" -o -name "minetest" \) | head -n 1)
if [ -d "$DATA_PATH" ]; then
    echo "-> Forcing game asset bundle synchronization inside staging layout ($DATA_PATH/games)..."
    mkdir -p "$DATA_PATH/games"
    cp -r "$SOURCE_DIR/games/minetest_game" "$DATA_PATH/games/"
    cp -r "$SOURCE_DIR/games/backroomtest" "$DATA_PATH/games/"
fi

# 5. Create the desktop shortcut launcher file dynamically pointing to standard share targets
echo "-> Creating desktop shortcut..."
mkdir -p "$DIR_NAME/usr/share/applications"
cat << EOF > "$DIR_NAME/usr/share/applications/luanti.desktop"
[Desktop Entry]
Name=Luanti (Minetest)
Comment=Voxel Sandbox Game Engine with Backroomtest Mod
Exec=/usr/bin/luanti
Icon=luanti
Terminal=false
Type=Application
Categories=Game;Simulation;
EOF

# 6. Generate the Debian control file dynamically with modern universal system libraries
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Provides: doom-engine
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libpng16-16, libjpeg62-turbo, zlib1g, libgl1, libluajit-5.1-2, libcurl4, libopenal1, libvorbisfile3
Description: Luanti sandbox engine bundled with backroomtest mod
 Luanti (formerly Minetest) is an infinite-world voxel sandbox 
 framework compiled with standard system pathways, minetest_game assets, 
 and the custom liminal space Backroomtest environment tracking code.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 7. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 8. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

