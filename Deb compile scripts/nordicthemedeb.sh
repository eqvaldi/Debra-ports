# Exit immediately if a command exits with a non-zero status
set -e

# 1. Define variables and rolling version track matching
VERSION="2026.09.04"
ARCH="all" # Standard specification for architecture-independent asset files
PKG_NAME="nordic-gtk-theme"
DIR_NAME="${PKG_NAME}_${VERSION}_${ARCH}"
REPO_URL="https://github.com/EliverLara/Nordic"
SOURCE_DIR="Nordic"

echo "=== Starting packaging process for ${PKG_NAME} version ${VERSION} ==="

# 2. Clone or update the master theme repository from GitHub
if [ ! -d "$SOURCE_DIR" ]; then
    echo "-> Cloning live Nordic GTK theme source repository..."
    git clone "$REPO_URL" "$SOURCE_DIR"
    cd "$SOURCE_DIR"
else
    echo "-> Repository directory exists. Pulling latest theme updates..."
    cd "$SOURCE_DIR"
    git pull
fi
cd .. # Return back to the script execution root directory

# 3. Create the clean staging directory structure (Targeting universal theme folder trees)
echo "-> Creating staging directory structure..."
rm -rf "$DIR_NAME"
mkdir -p "$DIR_NAME/DEBIAN"
mkdir -p "$DIR_NAME/usr/share/themes/Nordic"

# 4. Filter and copy theme directories into the standard system path
echo "-> Staging core theme asset components..."
# We filter out GitHub infrastructure files and copy only active theme layer targets
cp -r "$SOURCE_DIR"/assets "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp -r "$SOURCE_DIR"/cinnamon "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp -r "$SOURCE_DIR"/gnome-shell "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp -r "$SOURCE_DIR"/gtk-2.0 "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp -r "$SOURCE_DIR"/gtk-3.0 "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp -r "$SOURCE_DIR"/gtk-4.0 "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp -r "$SOURCE_DIR"/xfwm4 "$DIR_NAME/usr/share/themes/Nordic/" 2>/dev/null || true
cp "$SOURCE_DIR"/index.theme "$DIR_NAME/usr/share/themes/Nordic/"

# 5. Generate the Debian control file dynamically with the GPLv3 license tracking code
echo "-> Generating metadata control file..."
cat << EOF > "$DIR_NAME/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: misc
Priority: optional
Architecture: ${ARCH}
License: GPL-3.0-only
Maintainer: EQLinux <https://github.com/eqvaldi>
Depends: gnome-themes-extra | mate-themes | xfce4-theme-layout
Description: Nordic GTK theme created using the Nord color palette
 Nordic is a polished, flat dark Gtk3.20+ and Gtk4 framework theme 
 built using the awesome, frosty Nord color scheme palette.
 Automatically packaged on $(date +%Y-%m-%d).
EOF

# 6. Generate the official system copyright metadata file tracking the GPLv3 license precisely
echo "-> Generating system copyright tracking documentation..."
mkdir -p "$DIR_NAME/usr/share/doc/${PKG_NAME}"
cat << EOF > "$DIR_NAME/usr/share/doc/${PKG_NAME}/copyright"
Format: https://debian.org
Upstream-Name: nordic-gtk-theme
Source: ${REPO_URL}

Files: *
Copyright: 2018-2026 Eliver Lara <https://github.com/EliverLara>
License: GPL-3.0-only
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 3 can be found in "/usr/share/common-licenses/GPL-3".
EOF

# 7. Build the final .deb package safely ensuring root ownership
echo "-> Building the Debian package..."
dpkg-deb --root-owner-group --build "$DIR_NAME"

# 8. Clean up the staging directory structure
rm -rf "$DIR_NAME"

echo "=== Success! Package built: ${DIR_NAME}.deb ==="
