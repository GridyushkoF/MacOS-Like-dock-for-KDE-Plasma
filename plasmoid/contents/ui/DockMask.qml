/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

// Masks the panel to the dock, needs the dockregion plugin
Item {
    id: dockMask

    property Item dock
    property real rowLength: 0
    property real leadingGrowth: 0
    property real trailingGrowth: 0
    property bool vertical: false
    property bool keepBackground: true

    readonly property bool isAvailable: regionBuilder !== null && nativeBackground !== null
    // A kept background covers the whole window
    readonly property bool isActive: isAvailable && !keepBackground

    property var regionBuilder: null

    // Panel.qml, which owns panelMask
    readonly property Item panelElement: {
        var candidate = dock ? dock.parent : null;
        while (candidate) {
            if (candidate.hasOwnProperty("floatingTranslucentItemOffset")) {
                return candidate;
            }
            candidate = candidate.parent;
        }
        return null;
    }

    // The others anchor-fill it; matching by position lags while floating animates
    readonly property Item nativeBackground: {
        if (!panelElement) return null;
        for (var index = 0; index < panelElement.children.length; index++) {
            var child = panelElement.children[index];
            var isPanelBackground = child.imagePath && child.imagePath.toString().includes("panel-background");
            if (isPanelBackground && child.anchors.fill) {
                return child.anchors.fill;
            }
        }
        return null;
    }

    // From the applet's edge, the background can lag behind a shrinking panel
    readonly property real padding: {
        if (!nativeBackground || !dock || !panelElement) return 0;
        var appletStart = 0;
        for (var item = dock.parent; item && item !== panelElement; item = item.parent) {
            appletStart += vertical ? item.y : item.x;
        }
        return appletStart - (vertical ? nativeBackground.y : nativeBackground.x);
    }

    // Even to stay centered at rest
    readonly property int restRegionLength: 2 * Math.round((rowLength + 2 * padding) / 2)

    // Plasma offsets the mask by the background's position
    readonly property rect regionRect: {
        if (!nativeBackground) return Qt.rect(0, 0, 0, 0);
        var backgroundLength = vertical ? nativeBackground.height : nativeBackground.width;
        var restStart = Math.round((backgroundLength - restRegionLength) / 2);
        var start = restStart - Math.round(leadingGrowth);
        var length = restRegionLength + Math.round(leadingGrowth) + Math.round(trailingGrowth);
        return vertical ? Qt.rect(0, start, nativeBackground.width, length)
                        : Qt.rect(start, 0, length, nativeBackground.height);
    }

    Binding {
        target: dockMask.regionBuilder
        property: "rect"
        value: dockMask.regionRect
        when: dockMask.regionBuilder !== null
    }

    Binding {
        target: dockMask.panelElement
        property: "panelMask"
        value: dockMask.regionBuilder ? dockMask.regionBuilder.region : null
        when: dockMask.isActive
    }

    // Huge margins make Plasma drop the shadow but keep the blur
    readonly property real offscreenShadowMargin: 1000000

    Instantiator {
        model: ["topShadowMargin", "leftShadowMargin", "rightShadowMargin", "bottomShadowMargin"]
        delegate: Binding {
            required property string modelData
            target: dockMask.panelElement
            property: modelData
            value: dockMask.offscreenShadowMargin
            when: dockMask.isActive
        }
    }

    onIsActiveChanged: setNativeBackgroundsHidden(isActive)

    function setNativeBackgroundsHidden(hidden) {
        if (!panelElement) return;
        for (var index = 0; index < panelElement.children.length; index++) {
            var child = panelElement.children[index];
            var isPanelBackground = child.imagePath && child.imagePath.toString().includes("panel-background");
            if (isPanelBackground) {
                child.opacity = hidden ? 0 : 1;
            }
        }
    }

    onPanelElementChanged: setNativeBackgroundsHidden(isActive)
    Component.onCompleted: {
        // Matches the compositor effect's corners
        try {
            regionBuilder = Qt.createQmlObject("import org.kde.plasma.icontasks2; DockRegion { radius: 24 }", dockMask);
        } catch (error) {
            console.warn("Dock: plugin not installed, resizing the panel instead");
        }
        setNativeBackgroundsHidden(isActive);
    }
    Component.onDestruction: setNativeBackgroundsHidden(false)
}
