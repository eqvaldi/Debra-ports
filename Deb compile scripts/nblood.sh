#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="nblood"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/NBlood/NBlood.git"
SOURCE_DIR="NBlood"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source code
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning NBlood source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository already exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Compile the specific nblood target using all available CPU threads
echo "-> Compiling NBlood engine binaries with $(nproc) threads..."
make clean
make nblood -j$(nproc)
cd ..

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/nblood"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binaries and engine asset data files into staging library paths
echo "-> Copying executable binaries and .pk3 support definitions..."
if [ -f "$SOURCE_DIR/nblood" ] && [ -f "$SOURCE_DIR/nblood.pk3" ]; then
    cp "$SOURCE_DIR/nblood" "$DIR_NAME/usr/lib/nblood/"
    cp "$SOURCE_DIR/nblood.pk3" "$DIR_NAME/usr/lib/nblood/"
else
    echo "Error: Compiled engine binary or nblood.pk3 resource asset not detected in root."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles your home data folder setup safely
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/nblood"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and mods
mkdir -p "$HOME/.nblood"

# 2. Automatically link the required engine .pk3 resource asset directly into your home folder context
ln -sf /usr/lib/nblood/nblood.pk3 "$HOME/.nblood/nblood.pk3"

# 3. Hop inside your personal directory context so all generated files/saves land safely inside it
cd "$HOME/.nblood"

# 4. Launch the primary engine binary context natively 
exec /usr/lib/nblood/nblood "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/nblood"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/nblood.desktop"
[Desktop Entry]
Name=NBlood
Comment=Blood Source Port (Build Engine)
Exec=/usr/games/nblood
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
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
Description: NBlood engine port for One Unit Whole Blood
 NBlood is a spectacular, reverse-engineered source port of the 
 classic 1997 game Blood built using advanced EDuke32 technologies.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

