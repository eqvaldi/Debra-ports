#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="quakespasm-librequake"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/sezero/quakespasm.git"
SOURCE_DIR="quakespasm"
# Updated to your explicit LibreQuake full release asset path
LQ_URL="https://github.com/lavenderdotpet/LibreQuake/releases/download/v0.09-beta/full.zip"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the source code
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning QuakeSpasm source code..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR/Quake"
else
    echo "-> Repository directory exists. Pulling latest updates..."
    cd "$SOURCE_DIR"
    git pull
    cd Quake
fi

# 3. Compile the SDL2 target using all available CPU threads
echo "-> Compiling QuakeSpasm Engine with $(nproc) threads..."
make clean
make USE_SDL2=1 DO_USERDIRS=1 -j$(nproc)
cd ../.. # Return back to script execution root

# 4. Fetch and handle LibreQuake open-source data files
if [ ! -f "librequake_full.zip" ]; then
    echo "-> Downloading LibreQuake open-source data pack from corrected link..."
    wget -O librequake_full.zip "$LQ_URL"
fi
echo "-> Extracting LibreQuake assets..."
rm -rf lq_temp
mkdir -p lq_temp
unzip -q librequake_full.zip -d lq_temp

# 5. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/share/games/quakespasm/id1"
mkdir -p "$DIR_NAME/usr/share/applications"

# 6. Copy the compiled binary, core engine pak, and LibreQuake data layers
echo "-> Copying executable engine binaries and mapping asset directories..."
if [ -f "$SOURCE_DIR/Quake/quakespasm" ]; then
    # Install main player binary target
    cp "$SOURCE_DIR/Quake/quakespasm" "$DIR_NAME/usr/games/"
    
    # Install engine-specific custom data assets
    cp "$SOURCE_DIR/Quake/quakespasm.pak" "$DIR_NAME/usr/share/games/quakespasm/"
    
    # Copy extracted open-source game definitions (.pak files) into target layout id1 tree
    find lq_temp -type f -name "*.pak" -exec cp {} "$DIR_NAME/usr/share/games/quakespasm/id1/" \;
    
    # Cleanup temporary local uncompressed archive workspace
    rm -rf lq_temp
else
    echo "Error: Compiled binary 'quakespasm' not found."
    exit 1
fi

# 7. Create the desktop shortcut launcher file dynamically pointing to safe user home paths
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/quakespasm-librequake.desktop"
[Desktop Entry]
Name=LibreQuake (QuakeSpasm)
Comment=Fully free and open-source retro FPS powered by QuakeSpasm engine
Exec=/usr/games/quakespasm -userdir ~/.quakespasm -basedir /usr/share/games/quakespasm
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
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libvorbisfile3, libmad0, libogg0, libgl1
Description: LibreQuake standalone game built on QuakeSpasm
 This package provides a 100% free and open-source gaming configuration
 bundling the high-fidelity QuakeSpasm source port alongside the community 
 LibreQuake content database maps, textures, and entities.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# Generate a pre-removal script to force-clear the system launcher cache
cat << 'EOF' > "$DIR_NAME/DEBIAN/prerm"
#!/bin/bash
set -e
# Force delete the desktop file if it gets unlinked or orphaned
rm -f /usr/share/applications/quakespasm-librequake.desktop
# Update the system menu icon cache
if [ -x "$(command -v update-desktop-database)" ]; then
    update-desktop-database -q
fi
EOF

# Give the maintainer script proper execution rights (Mandatory for Debian)
chmod 755 "$DIR_NAME/DEBIAN/prerm"

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

