#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="kenbuild"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://voidpoint.io/terminx/eduke32.git"
SOURCE_DIR="eduke32-kenbuild"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source repository from GitLab
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning EDuke32 source repository for KenBuild..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Compile the specific ekenbuild target using your exact build optimizations
echo "-> Compiling ekenbuild binary target with optimized stripped flags..."
make clean
make ekenbuild -j$(nproc) USE_OPENGL=0 POLYMER=0 USE_LIBVPX=0 OPTLEVEL=2 WITHOUT_GTK=1
cd .. # Return back to the script execution root directory

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binary into staging
echo "-> Staging executable game binaries..."
if [ -f "$SOURCE_DIR/ekenbuild" ]; then
    cp "$SOURCE_DIR/ekenbuild" "$DIR_NAME/usr/games/kenbuild"
else
    echo "Error: Compiled binary target 'ekenbuild' not found in source directory folder root."
    exit 1
fi

# 6. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/kenbuild.desktop"
[Desktop Entry]
Name=KenBuild
Comment=Classic Build Engine Test Environment (Software Renderer)
Exec=/usr/games/kenbuild
Terminal=false
Type=Application
Categories=Game;Development;
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
Depends: libsdl2-2.0-0, libgl1, libvpx9, libgtk-3-0 | libgtk2.0-0
Description: KenBuild classic engine testing build based on EDuke32
 An optimized software-rendered build of Ken Silverman's legendary initial 
 Build Engine showcase world, compiled via modern EDuke32 libraries.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 9. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
