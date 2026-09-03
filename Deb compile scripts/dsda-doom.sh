#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and dynamic rolling date-based version
VERSION=$(date +%Y.%m.%d)
ARCH="amd64"
PKG_NAME="dsda-doom-git"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/kraflab/dsda-doom.git"
SOURCE_DIR="dsda-doom"

echo "=== Starting packaging process for dsda doom git version ${VERSION} ==="

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

# 4. Create the clean staging directory structure
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/games"
mkdir -p "$DIR_NAME/usr/lib/dsda-doom-git"
mkdir -p "$DIR_NAME/usr/share/applications"

# 5. Copy the compiled binary and core engine .wad file into staging layouts
echo "-> Staging executable binaries and verified .wad resource assets..."
if [ -f "$SOURCE_DIR/prboom2/dsda-doom" ]; then
    # Install main client binary to isolated application library tree context
    cp "$SOURCE_DIR/prboom2/dsda-doom" "$DIR_NAME/usr/lib/dsda-doom-git/dsda-doom-bin"
    
    # Copy the core data wad asset right next to the binary layout
    if [ -f "$SOURCE_DIR/prboom2/dsda-doom.wad" ]; then
        cp "$SOURCE_DIR/prboom2/dsda-doom.wad" "$DIR_NAME/usr/lib/dsda-doom-git/"
    fi
else
    echo "Error: Compiled binary 'dsda-doom' not detected inside the prboom2/ layout root."
    exit 1
fi

# 6. Create a smart startup script wrapper that handles your home data folder setup safely
echo "-> Creating application launcher wrapper with home directory mapping..."
cat << 'EOF' > "$DIR_NAME/usr/games/dsda-doom-git"
#!/bin/bash
# 1. Ensure the user's custom home folder layout exists for saves, demos, and configs
mkdir -p "$HOME/.dsda-doom"

# 2. Export the official environment variable so the engine searches your home folder for IWADs
export DOOMWADDIR="$HOME/.dsda-doom"

# 3. Launch the engine, hopping inside your home directory so all saves/configs generate there natively
cd "$HOME/.dsda-doom"
exec /usr/lib/dsda-doom-git/dsda-doom-bin -file /usr/lib/dsda-doom-git/dsda-doom.wad "$@"
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

# 8. Generate the Debian control file dynamically with the live version stamp
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
License: GPL-2.0-or-later
Provides: doom-engine
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: libsdl2-2.0-0, libsdl2-image-2.0-0, libsdl2-mixer-2.0-0, libgl1, libfluidsynth3, libportmidi0, libmad0
Description: dsda doom git advanced engine port for Doom, Heretic, and Hexen (Development Build)
 This is an advanced successor of prboom+ featuring extra tooling for 
 demo recording, in-game console scripting, full controller tracking, 
 and high-accuracy speedrunning features.
 Built and packaged straight from master source.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="

