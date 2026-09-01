#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="voidsw"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://voidpoint.io/terminx/eduke32.git"
SOURCE_DIR="eduke32-voidsw"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the repository from GitLab
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning EDuke32 source repository for VoidSW..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Compile the specific voidsw target using multi-core optimizations
echo "-> Compiling VoidSW binary target with $(nproc) threads..."
make clean
make voidsw -j$(nproc)
cd .. # Return back to the script execution root directory

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binary into staging
echo "-> Staging executable game binaries..."
if [ -f "$SOURCE_DIR/voidsw" ]; then
    cp "$SOURCE_DIR/voidsw" "$DIR_NAME/usr/games/"
else
    echo "Error: Compiled binary target 'voidsw' not found in source directory folder root."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/voidsw.desktop"
[Desktop Entry]
Name=VoidSW
Comment=Modern source port for Shadow Warrior (1997) based on EDuke32
Exec=/usr/games/voidsw
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
Depends: libsdl2-2.0-0, libgl1-mesa-glx, libflac8, libvpx7, libgtk2.0-0
Description: VoidSW source port engine for Shadow Warrior
 VoidSW is a high-performance source port of the classic 1997 3D Realms 
 title Shadow Warrior, optimized and maintained as part of the EDuke32 project.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
