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

# Core Minetest sandbox base game asset profiles
if [ ! -d "games/minetest_game" ]; then
    git clone --depth 1 https://github.com/minetest/minetest_game.git games/minetest_game
else
    cd games/minetest_game && git pull && cd ../..
fi

# Complementary Liminal Space Backrooms exploration mod module
if [ ! -d "games/backroomtest" ]; then
    git clone https://codeberg.org/SumianVoice/backroomtest.git games/backroomtest
else
    cd games/backroomtest && git pull && cd ../..
fi

# 4. Generate configurations and compile binaries
echo "-> Launching CMake configurations with RUN_IN_PLACE execution flags..."
cmake . -DRUN_IN_PLACE=TRUE
echo "-> Building execution binaries utilizing $(nproc) threads..."
make -j$(nproc)
cd .. # Return back to staging folder level 

# 5. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/opt/luanti"
mkdir -p "$DIR_NAME/usr/bin"
mkdir -p "$DIR_NAME/usr/share/applications"

# 6. Copy files (Since RUN_IN_PLACE=TRUE bundles assets next to the binary, we install to /opt)
echo "-> Staging portable runtime system assets..."
cp -r "$SOURCE_DIR"/* "$DIR_NAME/opt/luanti/"

# Create a system-wide symbolic link wrapper pointing to the /opt path binary execution target
ln -s /opt/luanti/bin/luanti "$DIR_NAME/usr/bin/luanti"

# 7. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/luanti.desktop"
[Desktop Entry]
Name=Luanti (Minetest)
Comment=Voxel Sandbox Game Engine with Backroomtest Mod
Exec=/usr/bin/luanti
Icon=/opt/luanti/misc/minetest.png
Terminal=false
Type=Application
Categories=Game;Simulation;
EOF

# 8. Generate the Debian control file dynamically
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libirrlicht1.8, libpng16-16, libjpeg62-turbo, zlib1g, libgl1, libluajit-5.1-2, libcurl4
Description: Luanti sandbox engine bundled with backroomtest mod
 Luanti (formerly Minetest) is an infinite-world voxel sandbox 
 framework compiled with local dependencies, minetest_game assets, 
 and the custom liminal space Backroomtest environment tracking code.
 Automatically packaged on $(date).
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
