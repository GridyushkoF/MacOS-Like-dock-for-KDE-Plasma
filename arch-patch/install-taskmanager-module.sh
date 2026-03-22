#!/bin/bash
#
# Install missing QML module org.kde.plasma.private.taskmanager
# for Arch-based systems (CachyOS, EndeavourOS, Manjaro, etc.) with Plasma 6.6.3+
#
# This module was removed from plasma-desktop in some versions,
# but is still required for third-party taskmanager widgets.
#

set -e

MODULE_NAME="org.kde.plasma.private.taskmanager"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/org.kde.plasma.private.taskmanager"

# Determine Qt6 QML modules path
if [ -d "/usr/lib/qt6/qml" ]; then
    QML_PATH="/usr/lib/qt6/qml"
elif [ -d "/usr/lib64/qt6/qml" ]; then
    QML_PATH="/usr/lib64/qt6/qml"
else
    echo "Error: Qt6 QML modules path not found"
    exit 1
fi

TARGET_DIR="$QML_PATH/org/kde/plasma/private/taskmanager"

echo "=== Installing module $MODULE_NAME ==="
echo ""
echo "Installation path: $TARGET_DIR"
echo ""

# Check if module already exists
if [ -d "$TARGET_DIR" ] && [ -f "$TARGET_DIR/libtaskmanagerplugin.so" ]; then
    echo "Module is already installed. Skipping."
    exit 0
fi

# Check if source files exist
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Module source directory not found: $SOURCE_DIR"
    exit 1
fi

# Check permissions
if [ "$EUID" -ne 0 ]; then
    echo "Root privileges required. Run: sudo $0"
    exit 1
fi

# Create directory
echo "Creating directory..."
mkdir -p "$TARGET_DIR"

# Copy files
echo "Copying files..."
cp "$SOURCE_DIR/libtaskmanagerplugin.so" "$TARGET_DIR/"
cp "$SOURCE_DIR/qmldir" "$TARGET_DIR/"
cp "$SOURCE_DIR/taskmanagerplugin.qmltypes" "$TARGET_DIR/"
cp "$SOURCE_DIR/kde-qmlmodule.version" "$TARGET_DIR/" 2>/dev/null || true

# Set permissions
chmod 755 "$TARGET_DIR"
chmod 755 "$TARGET_DIR/libtaskmanagerplugin.so"
chmod 644 "$TARGET_DIR/qmldir"
chmod 644 "$TARGET_DIR/taskmanagerplugin.qmltypes"

echo ""
echo "=== Installation complete! ==="
echo ""
echo "NOTE: This module was taken from Fedora with Plasma 6.6.1."
echo "If the widget doesn't work, the library may be incompatible"
echo "with your Plasma version. In that case, you need to rebuild"
echo "plasma-desktop from source or wait for a fix from KDE."
echo ""
echo "After installation, restart Plasma:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
echo ""
