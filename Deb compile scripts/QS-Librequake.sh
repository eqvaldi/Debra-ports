#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="quakespasm-librequake"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/sezero/quakespasm.git"
SOURCE_DIR="quakespasm"
# Updated to your explicit LibreQuake full release asset path
LQ_URL="https://github.com/lavenderdotpet/LibreQuake/releases/download/v0.09-beta/full.zip"

echo "=== Starting packaging process for ${PKG_NAME} on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

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

# 5. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/quakespasm-librequake"
mkdir -p "$DIR_NAME/usr/share/games/quakespasm-librequake/id1"
mkdir -p "$DIR_NAME/usr/share/applications"

# 6. Copy the compiled binary, core engine pak, and LibreQuake data layers into staging paths
echo "-> Copying executable engine binaries and mapping asset directories..."
if [ -f "$SOURCE_DIR/Quake/quakespasm" ]; then
    # Install main client binary to architecture-specific triplet library path context
    cp "$SOURCE_DIR/Quake/quakespasm" "$DIR_NAME/usr/lib/${TRIPLET}/quakespasm-librequake/quakespasm-bin"
    
    # Install engine-specific custom data assets
    cp "$SOURCE_DIR/Quake/quakespasm.pak" "$DIR_NAME/usr/lib/${TRIPLET}/quakespasm-librequake/"
    
    # Copy extracted open-source game definitions (.pak files) into target layout share id1 tree
    find lq_temp -type f -name "*.pak" -exec cp {} "$DIR_NAME/usr/share/games/quakespasm-librequake/id1/" \;
    
    # Cleanup temporary local uncompressed archive workspace
    rm -rf lq_temp
else
    echo "Error: Compiled binary 'quakespasm' not found."
    exit 1
fi

# 7. Create a smart multiarch startup script wrapper that handles home data folder setup safely
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/quakespasm-librequake"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for saves, configs, and mods
mkdir -p "$HOME/.quakespasm/id1"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Launch the engine, explicitly setting the base data directory from system share paths
exec /usr/lib/${TRIPLET}/quakespasm-librequake/quakespasm-bin -userdir "$HOME/.quakespasm" -basedir /usr/share/games/quakespasm-librequake "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/quakespasm-librequake"

# 8. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/quakespasm-librequake.desktop"
[Desktop Entry]
Name=LibreQuake (QuakeSpasm)
Comment=Fully free and open-source retro FPS powered by QuakeSpasm engine
Exec=/usr/games/quakespasm-librequake
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

# 9. Generate the Debian control file dynamically with the version, detected architecture, and Multi-Arch fields
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Multi-Arch: same
License: GPL-2.0-or-later AND BSD-3-Clause
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libvorbisfile3, libmad0, libogg0, libgl1
Description: LibreQuake standalone game built on QuakeSpasm (Multiarch Build)
 This package provides a 100% free and open-source gaming configuration
 bundling the high-fidelity QuakeSpasm source port alongside the community 
 LibreQuake content database maps, textures, and entities featuring BSD art.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 10. Generate the official system copyright metadata file tracking the split license split precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: quakespasm-librequake
Source: ${REPO_URL}
        https://github.com/lavenderdotpet/LibreQuake

Files: *
Copyright: 1999-2005 id Software, Inc.
           2010-2026 Anssi Hannula, Ozkan Sezer, Eric Wasylishen, and the QuakeSpasm contributors
License: GPL-2.0-or-later

Files: usr/share/games/quakespasm-librequake/id1/*
Copyright: 2018-2026 The LibreQuake Project and contributors
License: BSD-3-Clause
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
chmod 755 "$DIR_NAME/DEBIAN/prerm"

# 11. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 12. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
