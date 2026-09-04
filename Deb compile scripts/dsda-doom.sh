#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="dsda-doom-git"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/kraflab/dsda-doom.git"
SOURCE_DIR="dsda-doom"

echo "=== Starting packaging process for dsda doom git on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning dsda doom git source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR/prboom2"
else
    echo "-> Repository directory exists. Pulling latest commits..."
    cd "$SOURCE_DIR"
    git pull
    cd prboom2
fi

# 3. Configure and compile via CMake within the prboom2 folder
echo "-> Formatting build configuration via CMake..."
cmake ./
echo "-> Compiling engine targets with $(nproc) threads..."
make -j$(nproc)
cd ../.. # Return back to the script execution root directory

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/dsda-doom-git"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binary and core engine .wad file into staging layouts
echo "-> Staging executable binaries and verified .wad resource assets..."
if [ -f "$SOURCE_DIR/prboom2/dsda-doom" ]; then
    # Install main client binary to architecture-specific triplet library path
    cp "$SOURCE_DIR/prboom2/dsda-doom" "$DIR_NAME/usr/lib/${TRIPLET}/dsda-doom-git/dsda-doom-bin"
    
    # Copy the core data wad asset right next to the binary layout inside the triplet path
    if [ -f "$SOURCE_DIR/prboom2/dsda-doom.wad" ]; then
        cp "$SOURCE_DIR/prboom2/dsda-doom.wad" "$DIR_NAME/usr/lib/${TRIPLET}/dsda-doom-git/"
    fi
else
    echo "Error: Compiled binary 'dsda-doom' not detected inside the prboom2/ layout root."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles multiarch paths dynamically
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/dsda-doom-git"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for saves, demos, and configs
mkdir -p "$HOME/.dsda-doom"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Export the official environment variable so the engine searches your home folder for IWADs
export DOOMWADDIR="$HOME/.dsda-doom"

# 4. Launch the engine, hopping inside your home directory so all saves/configs generate there natively
cd "$HOME/.dsda-doom"
exec /usr/lib/${TRIPLET}/dsda-doom-git/dsda-doom-bin -file /usr/lib/${TRIPLET}/dsda-doom-git/dsda-doom.wad "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/dsda-doom-git"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/dsda-doom-git.desktop"
[Desktop Entry]
Name=dsda doom git
Comment=Successor of prboom+ focusing on speedrunning and TAS tooling - Development Build
Exec=/usr/games/dsda-doom-git
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

# 8. Generate the Debian control file dynamically with the live version, architecture, and Multi-Arch fields
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Multi-Arch: same
License: GPL-2.0-or-later
Provides: doom-engine
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libsdl2-image-2.0-0, libsdl2-mixer-2.0-0, libgl1, libfluidsynth3, libportmidi0, libmad0
Description: dsda doom git advanced engine port for Doom, Heretic, and Hexen (Development Build)
 This is an advanced successor of prboom+ featuring extra tooling for 
 demo recording, in-game console scripting, full controller tracking, 
 and high-accuracy speedrunning features.
 Built and packaged straight from master source.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv2 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: dsda-doom
Source: ${REPO_URL}

Files: *
Copyright: 1993-1997 id Software, Inc.
           1999-2008 Raven Software
           1998-2026 the Boom/PrBoom+ teams
           2019-2026 kraflab and the dsda-doom contributors
License: GPL-2.0-or-later
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2 of the License.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 2 can be found in "/usr/share/common-licenses/GPL-2".
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

