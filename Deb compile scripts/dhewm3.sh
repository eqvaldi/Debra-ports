#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="dhewm3"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/dhewm/dhewm3.git"
SOURCE_DIR="dhewm3"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source code
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning dhewm3 source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository already exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Download and extract the complementary mods asset
if [ ! -f "dhewm3-mods-1.5.5_Linux_amd64.tar.gz" ]; then
    echo "-> Downloading game mods asset..."
    wget https://github.com/dhewm/dhewm3/releases/download/1.5.5/dhewm3-mods-1.5.5_Linux_amd64.tar.gz
fi
echo "-> Extracting game mods asset..."
tar -xvf ./dhewm3-mods-1.5.5_Linux_amd64.tar.gz

# 4. Configure and Compile using CMake out-of-source build rules
echo "-> Configuring and compiling with CMake..."
mkdir -p build
cd build
cmake ../neo/
make -j$(nproc)
cd ../.. # Return back to script execution root

# 5. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 6. Copy compiled binaries and extracted mod assets into packaging staging
echo "-> Copying binaries and mod game extensions..."
cp "$SOURCE_DIR/build/dhewm3" "$DIR_NAME/usr/games/"
# If your compilation generated dedicated server binaries or .so files, add them here:
if [ -f "$SOURCE_DIR/build/dhewm3ded" ]; then
    cp "$SOURCE_DIR/build/dhewm3ded" "$DIR_NAME/usr/games/"
fi

# 7. Create the desktop shortcut file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/dhewm3.desktop"
[Desktop Entry]
Name=dhewm3
Comment=Doom 3 Source Port
Exec=/usr/games/dhewm3
Terminal=false
Type=Application
Categories=Game;ActionGame;
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
Depends: libsdl2-2.0-0, libopenal1, libcurl4, libgl1
Description: dhewm3 engine port for Doom 3
 dhewm3 is a Doom 3 GPL source port optimized to work seamlessly
 on modern 64-bit systems using SDL2 and OpenAL.
 Automatically packaged on $(date).
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
