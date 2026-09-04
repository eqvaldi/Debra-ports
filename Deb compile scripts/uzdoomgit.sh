set -e

# 1. DYNAMIC ARCHITECTURE & MULTIARCH SYSTEM TRIPLET DETECTION
# Automatically extracts standard Debian tokens (e.g., amd64, arm64, i386)
ARCH=$(dpkg-architecture -qDEB_HOST_ARCH)

# Automatically extracts system library folder triplets (e.g., x86_64-linux-gnu, aarch64-linux-gnu)
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

VERSION=$(date +%Y.%m.%d)
PKG_NAME="uzdoom-git"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/UZDoom/UZDoom.git"
SOURCE_DIR="UZDoom-git"

echo "=== Starting packaging process for ${PKG_NAME} (Git Master) on Architecture: ${ARCH} (Triplet: ${TRIPLET}) ==="

# 2. Clone or update the repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning live UZDoom source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest development commits..."
    cd "$SOURCE_DIR"
    git pull
    cd ..
fi

# 3. Configure and compile using Ninja in an out-of-source build folder
echo "-> Creating build workspace folder and configuring via CMake..."
mkdir -p "$SOURCE_DIR/build"
cd "$SOURCE_DIR/build"

cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -G Ninja ..
echo "-> Compiling development UZDoom engine assets utilizing Ninja..."
cmake --build .
cd ../.. # Return back to the script execution root directory

# 4. Create the clean staging directory structure targeting Multiarch pathways
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/${TRIPLET}/uzdoom-git"
mkdir -p "$DIR_NAME/usr/share/games/uzdoom-git"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binaries, script libraries, and sound assets into correct system paths
echo "-> Staging executable binaries and core engine .pk3 resource assets..."
if [ -f "$SOURCE_DIR/build/uzdoom" ]; then
    # Install main binary engine path into architecture-specific triplet folder
    cp "$SOURCE_DIR/build/uzdoom" "$DIR_NAME/usr/lib/${TRIPLET}/uzdoom-git/uzdoom-bin"
    
    # Stash mandatory system script package frameworks (.pk3 targets) into global shared space
    cp "$SOURCE_DIR/build/uzdoom.pk3" "$DIR_NAME/usr/share/games/uzdoom-git/"
    cp "$SOURCE_DIR/build/brightmaps.pk3" "$DIR_NAME/usr/share/games/uzdoom-git/"
    cp "$SOURCE_DIR/build/lights.pk3" "$DIR_NAME/usr/share/games/uzdoom-git/"
    cp "$SOURCE_DIR/build/game_widescreen_gfx.pk3" "$DIR_NAME/usr/share/games/uzdoom-git/"
    cp "$SOURCE_DIR/build/game_support.pk3" "$DIR_NAME/usr/share/games/uzdoom-git/"
    
    # Mirror sound fonts asset directories completely into the global share path
    if [ -d "$SOURCE_DIR/build/soundfonts" ]; then
        cp -r "$SOURCE_DIR/build/soundfonts" "$DIR_NAME/usr/share/games/uzdoom-git/"
    fi
else
    echo "Error: Compiled development engine binaries not detected inside the build/ directory layout."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles multiarch paths dynamically
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/uzdoom-git"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for mods and configurations
mkdir -p "$HOME/.uzdoom"

# 2. Dynamically determine the machine's active multiarch triplet path at runtime
TRIPLET=$(dpkg-architecture -qDEB_HOST_MULTIARCH)

# 3. Hop inside your personal directory context so all generated files land safely inside it
cd "$HOME/.uzdoom"

# 4. Launch the engine binary context natively mapping global engine assets
exec /usr/lib/${TRIPLET}/uzdoom-git/uzdoom-bin "$@"
EOF
chmod 755 "$DIR_NAME/usr/games/uzdoom-git"

# 7. Create the desktop shortcut launcher file dynamically pointing straight to your wrapper tool
echo "-> Creating desktop shortcut..."
cat << EOF > "$DIR_NAME/usr/share/applications/uzdoom-git.desktop"
[Desktop Entry]
Name=UZDoom (Git Master)
Comment=Advanced development engine port for Doom based on GZDoom
Exec=/usr/games/uzdoom-git
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
Provides: doom-engine
License: GPL-3.0-or-later
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libgl1, libopenal1, libsndfile1, libmpg123-0, libvpx9, zlib1g, libfluidsynth3, libvulkan1
Description: UZDoom advanced feature-rich source port based on GZDoom (Development Build)
 UZDoom is a modern continuation of ZDoom and GZDoom adding enhanced 
 high-resolution hardware scripting capabilities, dynamic lighting systems, 
 full Vulkan/OpenGL acceleration, and 3D floor maps support.
 Automatically detected, compiled, and packaged for development ${ARCH} architectures.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Generate the official system copyright metadata file tracking the GPLv3 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: uzdoom-git
Source: ${REPO_URL}

Files: *
Copyright: 1993-1996 id Software
           1999-2016 Marisa Heit
           2002-2016 Christoph Oelckers
           2017-2025 GZDoom Maintainers and Contributors
           2025-2026 UZDoom Maintainers and Contributors
License: GPL-3.0-or-later
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 3 can be found in "/usr/share/common-licenses/GPL-3".
EOF

# 10. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 11. Clean up the temporary staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Git development package built: ${DIR_NAME}.deb ==="
