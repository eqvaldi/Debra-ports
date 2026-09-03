#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="uzdoom"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/UZDoom/UZDoom.git"
SOURCE_DIR="UZDoom"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning UZDoom source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
    cd ..
fi

# 3. Configure and compile using Ninja in an out-of-source build folder
echo "-> Creating build workspace folder and configuring via CMake..."
mkdir -p "$SOURCE_DIR/build"
cd "$SOURCE_DIR/build"

cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -G Ninja ..
echo "-> Compiling UZDoom engine assets utilizing Ninja..."
cmake --build .
cd ../.. # Return back to the script execution root directory

# 4. Create the clean staging directory structure (Targeting standard share/games paths)
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/games/uzdoom"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binaries, script libraries, and sound assets into correct system paths
echo "-> Staging executable binaries and core engine .pk3 resource assets..."
if [ -f "$SOURCE_DIR/build/uzdoom" ]; then
    # Install main binary engine path
    cp "$SOURCE_DIR/build/uzdoom" "$DIR_NAME/usr/games/"
    
    # Stash mandatory system script package frameworks (.pk3 targets) into the correct search path
    cp "$SOURCE_DIR/build/uzdoom.pk3" "$DIR_NAME/usr/share/games/uzdoom/"
    cp "$SOURCE_DIR/build/brightmaps.pk3" "$DIR_NAME/usr/share/games/uzdoom/"
    cp "$SOURCE_DIR/build/lights.pk3" "$DIR_NAME/usr/share/games/uzdoom/"
    cp "$SOURCE_DIR/build/game_widescreen_gfx.pk3" "$DIR_NAME/usr/share/games/uzdoom/"
    cp "$SOURCE_DIR/build/game_support.pk3" "$DIR_NAME/usr/share/games/uzdoom/"
    
    # Mirror sound fonts asset directories completely into the engine directory
    if [ -d "$SOURCE_DIR/build/soundfonts" ]; then
        cp -r "$SOURCE_DIR/build/soundfonts" "$DIR_NAME/usr/share/games/uzdoom/"
    fi
else
    echo "Error: Compiled engine binaries not detected inside the build/ directory layout."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/uzdoom.desktop"
[Desktop Entry]
Name=UZDoom
Comment=Advanced feature-centric engine port for Doom based on GZDoom
Exec=/usr/games/uzdoom
Terminal=false
Type=Application
Categories=Game;ActionGame;
EOF

# 7. Generate the Debian control file dynamically with the live version stamp and provides target
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Provides: doom-engine
License: GPL-3.0-or-later
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1, libopenal1, libsndfile1, libmpg123-0, libvpx9, zlib1g, libfluidsynth3, libvulkan1
Description: UZDoom advanced feature-rich source port based on GZDoom
 UZDoom is a modern continuation of ZDoom and GZDoom adding enhanced 
 high-resolution hardware scripting capabilities, dynamic lighting systems, 
 full Vulkan/OpenGL acceleration, and 3D floor maps support.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
