#!/bin/bash
#
# Remove module org.kde.plasma.private.taskmanager
#

set -e

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

echo "=== Removing module org.kde.plasma.private.taskmanager ==="

if [ ! -d "$TARGET_DIR" ]; then
    echo "Module is not installed."
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    echo "Root privileges required. Run: sudo $0"
    exit 1
fi

rm -rf "$TARGET_DIR"

echo "Module removed."
echo ""
echo "Restart Plasma: kquitapp6 plasmashell && kstart plasmashell"
