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
cd ../.. # Back to repo root

# 4. Compile the Multiplayer (MP) Engine
echo "-> Entering MP directory and compiling Multiplayer..."
cd MP
make clean
make -j$(nproc)

# Move the release directory to a standardized 'MP' name as requested
cd build
rm -rf MP
mv release-linux* MP
cd ../../.. # Return back to script execution root

# 5. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/lib/iortcw/main"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/applications"

# 6. Copy the compiled application binaries and libraries into staging
echo "-> Staging compiled SP and MP client/server files..."
cp -r "$SOURCE_DIR/SP/build/SP"/* "$DIR_NAME/usr/lib/iortcw/"
cp -r "$SOURCE_DIR/MP/build/MP"/* "$DIR_NAME/usr/lib/iortcw/"

# Create a clean dedicated server binary symlink if it was compiled
if [ -f "$DIR_NAME/usr/lib/iortcw/iowolfded.x86_64" ]; then
    ln -s /usr/lib/iortcw/iowolfded.x86_64 "$DIR_NAME/usr/games/iowolfded"
fi

# 7. Create smart startup script wrappers targeting your custom renamed home folder path
echo "-> Creating application launcher wrappers with iortcw directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/iowolfsp"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and custom mods
mkdir -p "$HOME/.iortcw/main"

# 2. Automatically link your system libraries and game binaries natively into your home folder context
if [ -d /usr/lib/iortcw/main ]; then
    ln -sf /usr/lib/iortcw/main/*.so "$HOME/.iortcw/main/" 2>/dev/null || true
fi
ln -sf /usr/lib/iortcw/renderer_mp_*.so "$HOME/.iortcw/" 2>/dev/null || true
ln -sf /usr/lib/iortcw/renderer_sp_*.so "$HOME/.iortcw/" 2>/dev/null || true

# 3. Launch the engine, explicitly setting the renamed user home directory as the system game assets basepath
exec /usr/lib/iortcw/iowolfsp.x86_64 +set fs_homepath "$HOME/.iortcw" +set fs_basepath "$HOME/.iortcw" "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/iowolfsp"

cat << 'EOF' > "$DIR_NAME/usr/games/iowolfmp"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for base game assets and custom mods
mkdir -p "$HOME/.iortcw/main"

# 2. Automatically link your system libraries and game binaries natively into your home folder context
if [ -d /usr/lib/iortcw/main ]; then
    ln -sf /usr/lib/iortcw/main/*.so "$HOME/.iortcw/main/" 2>/dev/null || true
fi
ln -sf /usr/lib/iortcw/renderer_mp_*.so "$HOME/.iortcw/" 2>/dev/null || true
ln -sf /usr/lib/iortcw/renderer_sp_*.so "$HOME/.iortcw/" 2>/dev/null || true

# 3. Launch the engine, explicitly setting the renamed user home directory as the system game assets basepath
exec /usr/lib/iortcw/iowolfmp.x86_64 +set fs_homepath "$HOME/.iortcw" +set fs_basepath "$HOME/.iortcw" "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/iowolfmp"

# 8. Create desktop application menu shortcuts dynamically
echo "-> Creating desktop shortcuts..."
cat << EOF > "$DIR_NAME/usr/share/applications/iowolfsp.desktop"
[Desktop Entry]
Name=iortcw Single Player
Comment=Return to Castle Wolfenstein Single Player Port
Exec=/usr/games/iowolfsp
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

cat << EOF > "$DIR_NAME/usr/share/applications/iowolfmp.desktop"
[Desktop Entry]
Name=iortcw Multiplayer
Comment=Return to Castle Wolfenstein Multiplayer Port
Exec=/usr/games/iowolfmp
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

# 9. Generate the Debian control file dynamically
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Provides: doom-engine
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libopenal1, libcurl4, libjpeg62-turbo, libpng16-16, libgl1
Description: iortcw engine port for Return to Castle Wolfenstein
 Merged ioquake3 features and fixes into Return to Castle Wolfenstein (RTCW).
 Includes both full Single Player campaign and Multiplayer engine components.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

