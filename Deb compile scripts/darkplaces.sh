#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="darkplaces"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/DarkPlacesEngine/DarkPlaces.git"
SOURCE_DIR="darkplaces"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

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

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled SDL binary into packaging staging
echo "-> Copying executable engine binaries..."
if [ -f "$SOURCE_DIR/darkplaces-sdl" ]; then
    cp "$SOURCE_DIR/darkplaces-sdl" "$DIR_NAME/usr/games/"
else
    echo "Error: Compiled binary 'darkplaces-sdl' not found in source directory."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/darkplaces.desktop"
[Desktop Entry]
Name=DarkPlaces
Comment=Advanced Quake 1 Engine Modification
Exec=/usr/games/darkplaces-sdl
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
Depends: libsdl2-2.0-0, libjpeg62-turbo, libpng16-16, libcurl4, libgl1
Description: DarkPlaces Quake engine port
 DarkPlaces is an advanced, high-fidelity modification of the original
 Quake 1 engine featuring modern rendering and extended script support.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
