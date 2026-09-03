#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="eduke32"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://voidpoint.io/terminx/eduke32.git"
SOURCE_DIR="eduke32"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source code
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning EDuke32 source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository already exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Compile using all available CPU cores
echo "-> Compiling EDuke32 with $(nproc) threads..."
make clean
make -j$(nproc)
cd ..

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/eduke32"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binaries to an isolated library path
echo "-> Copying binaries..."
if [ -f "$SOURCE_DIR/eduke32" ] && [ -f "$SOURCE_DIR/mapster32" ]; then
    cp "$SOURCE_DIR/eduke32" "$SOURCE_DIR/mapster32" "$DIR_NAME/usr/lib/eduke32/"
else
    echo "Error: Compiled engine binaries not found in repository root."
    exit 1
fi

# 6. Create smart startup script wrappers that handle your home data folder setup safely
echo "-> Creating application launcher wrappers with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/eduke32"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.eduke32"

# 2. Hop inside your personal directory context so all generated files/saves land safely inside it
cd "$HOME/.eduke32"

# 3. Launch the primary engine binary context natively 
exec /usr/lib/eduke32/eduke32 "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/eduke32"

cat << 'EOF' > "$DIR_NAME/usr/games/mapster32"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.eduke32"

# 2. Hop inside your personal directory context so map creation files land safely inside it
cd "$HOME/.eduke32"

# 3. Launch the map editor binary context natively 
exec /usr/lib/eduke32/mapster32 "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/mapster32"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/eduke32.desktop"
[Desktop Entry]
Name=EDuke32
Comment=Duke Nukem 3D Port
Exec=/usr/games/eduke32
Terminal=false
Type=Application
Icon=applications-games
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
License: GPL-2.0-or-later AND BSD-3-Clause
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1, libvpx9, libgtk-3-0 | libgtk2.0-0
Description: EDuke32 engine port for Duke Nukem 3D
 EDuke32 is a feature-packed homebrew port of the classic 3D
 Realms game Duke Nukem 3D. Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

