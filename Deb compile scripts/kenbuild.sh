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
make ekenbuild -j$(nproc)
cd .. # Return back to the script execution root directory

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/kenbuild"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binary into an isolated library path
echo "-> Staging executable game binaries..."
if [ -f "$SOURCE_DIR/ekenbuild" ]; then
    cp "$SOURCE_DIR/ekenbuild" "$DIR_NAME/usr/lib/kenbuild/kenbuild"
else
    echo "Error: Compiled binary target 'ekenbuild' not found in source directory folder root."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles your home data folder setup safely
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/kenbuild"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.kenbuild"

# 2. Hop inside your personal directory context so all generated files/saves land safely inside it
cd "$HOME/.kenbuild"

# 3. Launch the primary engine binary context natively 
exec /usr/lib/kenbuild/kenbuild "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/kenbuild"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/kenbuild.desktop"
[Desktop Entry]
Name=KenBuild
Comment=Classic Build Engine Test Environment (Software Renderer)
Exec=/usr/games/kenbuild
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;Development;
EOF

# 8. Generate the Debian control file dynamically with the live version stamp
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
License: GPL-2.0-or-later AND BSD-3-Clause
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1, libvpx9, libgtk-3-0 | libgtk2.0-0
Description: KenBuild classic engine testing build based on EDuke32
 An optimized software-rendered build of Ken Silverman's legendary initial 
 Build Engine showcase world, compiled via modern EDuke32 libraries.
 Automatically packaged on 2026-09-01.
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

