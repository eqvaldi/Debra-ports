#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="ecwolf"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/ECWolfEngine/ECWolf.git"
SOURCE_DIR="ECWolf"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source code repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning ECWolf source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest commits..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Configure and compile via CMake utilizing all CPU threads
echo "-> Formatting build configuration via CMake..."
cmake ./
echo "-> Compiling engine binaries and data assets with $(nproc) threads..."
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/games/ecwolf"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binary and core engine .pk3 archive file into staging
echo "-> Staging executable binaries and engine runtime data structures..."
if [ -f "$SOURCE_DIR/ecwolf" ]; then
    cp "$SOURCE_DIR/ecwolf" "$DIR_NAME/usr/games/"
    cp "$SOURCE_DIR/ecwolf.pk3" "$DIR_NAME/usr/share/games/ecwolf/"
else
    echo "Error: Compiled binary files not detected in core repository folder root."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/ecwolf.desktop"
[Desktop Entry]
Name=ECWolf
Comment=Advanced Wolfenstein 3D engine source port based on ZDoom features
Exec=/usr/games/ecwolf
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
Depends: libsdl2-2.0-0, libsdl2-net-2.0-0, libjpeg62-turbo, libpng16-16, zlib1g, libgl1
Description: ECWolf advanced engine port for Wolfenstein 3D
 ECWolf is an evolutionary port of Wolfenstein 3D extending modern 
 widescreen setups, flexible WASD inputs, and advanced ZDoom data scripting features.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
