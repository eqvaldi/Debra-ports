#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and rolling version track matching
VERSION="2026.09.04"
ARCH="all"
PKG_NAME="colloid-icon-theme"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/vinceliuice/Colloid-icon-theme.git"
SOURCE_DIR="Colloid-icon-theme"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the master theme repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning live Colloid icon theme source repository..."
    git clone --depth 1 "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest theme updates..."
    cd "$SOURCE_DIR"
    git pull
fi
cd .. # Return back to the script execution root directory

# 3. Create the clean staging directory structure targeting universal system paths
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/share/colloid-source"

# 4. Copy the raw builder files into the safe tracking path
echo "-> Staging core builder templates..."
cp -r "$SOURCE_DIR"/* "$DIR_NAME/usr/share/colloid-source/"

# 5. Create a dynamic Post-Installation script to trigger compilation upon deployment
echo "-> Generating automated postinst trigger hook..."
cat << 'EOF' > "$DIR_NAME/DEBIAN/postinst"
#!/bin/bash
set -e
echo "-> Packaging deployed. Triggering Colloid Theme generator..."
cd /usr/share/colloid-source

# Run the official installer locally into the root icon system folder
# This bypasses all relative path problems and builds your icon assets natively!
./install.sh -d "/usr/share/icons" -s all -t all

echo "-> Core icon themes generated successfully!"
EOF
chmod 755 "$DIR_NAME/DEBIAN/postinst"

# 6. Create an automated Prerm script to clean up system folders if uninstalled
cat << 'EOF' > "$DIR_NAME/DEBIAN/prerm"
#!/bin/bash
set -e
if [ "$1" = "remove" ]; then
    echo "-> Removing Colloid icon sets from global cache..."
    rm -rf /usr/share/icons/Colloid*
fi
EOF
chmod 755 "$DIR_NAME/DEBIAN/prerm"

# 7. Generate the Debian control file dynamically
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: misc
Priority: optional
Architecture: ${ARCH}
License: GPL-3.0-only
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: hicolor-icon-theme
Description: Colloid icon theme for linux desktops
 Colloid is a clean, modern, flat vector icon theme for Linux desktops.
 This package compiles all core variations including default and Nord 
 folder sets natively upon deployment.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 8. Generate the official system copyright metadata file tracking the GPLv3 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: colloid-icon-theme
Source: ${REPO_URL}

Files: *
Copyright: 2021-2026 Vince Liuice <https://github.com>
License: GPL-3.0-only
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 3 can be found in "/usr/share/common-licenses/GPL-3".
EOF

# 9. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 10. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
