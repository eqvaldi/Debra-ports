#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="iortcw"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/iortcw/iortcw.git"
SOURCE_DIR="iortcw"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the engine source code repository
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning iortcw source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
    cd ..
fi

# 3. Compile the Single Player (SP) Engine
echo "-> Entering SP directory and compiling Single Player..."
cd "$SOURCE_DIR/SP"
make clean
make -j$(nproc)

# Move the release directory to a standardized 'SP' name as requested
cd build
rm -rf SP
mv release-linux* SP
cd ../../.. # Back to script execution root

# 4. Compile the Multiplayer (MP) Engine
echo "-> Entering MP directory and compiling Multiplayer..."
cd "$SOURCE_DIR/MP"
make clean
make -j$(nproc)

# Move the release directory to a standardized 'MP' name as requested
cd build
rm -rf MP
mv release-linux* MP
cd ../../.. # Back to script execution root

# 5. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/lib/iortcw"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 6. Copy the compiled application binaries and libraries into staging
echo "-> Staging compiled SP and MP client/server files..."
cp -r "$SOURCE_DIR/SP/build/SP"/* "$DIR_NAME/usr/lib/iortcw/"
cp -r "$SOURCE_DIR/MP/build/MP"/* "$DIR_NAME/usr/lib/iortcw/"

# Create convenient global symlinks in /usr/games/ for the actual game engines
# (Matches the typical x86_64 binary naming format used by iortcw)
ln -s /usr/lib/iortcw/iowolfsp.x86_64 "$DIR_NAME/usr/games/iowolfsp"
ln -s /usr/lib/iortcw/iowolfmp.x86_64 "$DIR_NAME/usr/games/iowolfmp"
if [ -f "$DIR_NAME/usr/lib/iortcw/iowolfded.x86_64" ]; then
    ln -s /usr/lib/iortcw/iowolfded.x86_64 "$DIR_NAME/usr/games/iowolfded"
fi

# 7. Create desktop application menu shortcuts dynamically
echo "-> Creating desktop shortcuts..."
cat << EOF > "$DIR_NAME/usr/share/applications/iowolfsp.desktop"
[Desktop Entry]
Name=iortcw Single Player
Comment=Return to Castle Wolfenstein Single Player Port
Exec=/usr/games/iowolfsp
Terminal=false
Type=Application
Categories=Game;ActionGame;
EOF

cat << EOF > "$DIR_NAME/usr/share/applications/iowolfmp.desktop"
[Desktop Entry]
Name=iortcw Multiplayer
Comment=Return to Castle Wolfenstein Multiplayer Port
Exec=/usr/games/iowolfmp
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
Depends: libsdl2-2.0-0, libopenal1, libcurl4, libjpeg62-turbo, libpng16-16
Description: iortcw engine port for Return to Castle Wolfenstein
 Merged ioquake3 features and fixes into Return to Castle Wolfenstein (RTCW).
 Includes both full Single Player campaign and Multiplayer engine components.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
