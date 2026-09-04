#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="ecwolf"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/ECWolfEngine/ECWolf.git"
SOURCE_DIR="ECWolf"

echo "=== Starting packaging process for ${PKG_NAME} on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the source code repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning ECWolf source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest commits..."
    cd "$SOURCE_DIR"
    git pull
fi

# 3. Configure and compile via CMake utilizing all CPU threads
echo "-> Formatting build configuration via CMake..."
cmake ./
echo "-> Compiling engine binaries and data assets with $(nproc) threads..."
make -j$(nproc)
cd .. # Return back to script execution root

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/ecwolf"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled application binary and core engine .pk3 archive file into the triplet library path
echo "-> Staging executable binaries and engine runtime data structures..."
if [ -f "$SOURCE_DIR/ecwolf" ]; then
    # Isolating the raw engine targets inside architecture-specific system library folders
    cp "$SOURCE_DIR/ecwolf" "$DIR_NAME/usr/lib/${TRIPLET}/ecwolf/ecwolf-bin"
    cp "$SOURCE_DIR/ecwolf.pk3" "$DIR_NAME/usr/lib/${TRIPLET}/ecwolf/"
else
    echo "Error: Compiled binary files not detected in core repository folder root."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles multiarch paths dynamically
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/ecwolf"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for mods and saves
mkdir -p "$HOME/.ecwolf"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Jump directly into your home folder context so the scanner reads your game data files natively
cd "$HOME/.ecwolf"

# 4. Launch the primary engine binary context safely mapping the global engine asset location
exec /usr/lib/${TRIPLET}/ecwolf/ecwolf-bin --ecwolf-pk3=/usr/lib/${TRIPLET}/ecwolf/ecwolf.pk3 "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/ecwolf"

# 7. Create the desktop shortcut launcher file dynamically
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/ecwolf.desktop"
[Desktop Entry]
Name=ECWolf
Comment=Advanced Wolfenstein 3D engine source port based on ZDoom features
Exec=/usr/games/ecwolf
Terminal=false
Type=Application
Icon=applications-games
Categories=Game;ActionGame;
EOF

# 8. Generate the Debian control file dynamically with the live version, detected architecture, and Multi-Arch flags
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Multi-Arch: same
License: GPL-2.0-or-later AND Doom-Source-License
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libsdl2-net-2.0-0, libjpeg62-turbo, libpng16-16, zlib1g, libgl1
Description: ECWolf advanced engine port for Wolfenstein 3D (Multiarch Build)
 ECWolf is an evolutionary port of Wolfenstein 3D extending modern 
 widescreen setups, flexible WASD inputs, and advanced ZDoom data scripting features.
 Automatically detected, compiled, and packaged for ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the split license split precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: ecwolf
Source: ${REPO_URL}

Files: *
Copyright: 1992-1995 id Software, Inc.
           2012-2026 Braden Obrzut (Bl分散) and the ECWolf contributors
License: GPL-2.0-or-later

Files: src/wl_sound.cpp src/id_sd.*
Copyright: 1993-1997 id Software, Inc.
License: Doom-Source-License

License: Doom-Source-License
 id Software open-source fallback engine exception terms:
 .
 Limited, non-exclusive license to use, copy, modify, and distribute
 this software for non-commercial purposes only. Redistribution of 
 binary modules derived from this subsystem requires that no financial
 profit or transaction fee changes hands.
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

