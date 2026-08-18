/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "code/launcherfromdrop.js" as LauncherFromDrop

// Use Item instead of ToolTipArea to avoid internal hover handling that causes jitter
Item {
    id: taskItem

    // Tooltip handled separately
    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: taskName
        subText: isLauncher ? i18n("Click to launch") : ""
        icon: iconSource
        active: false  // Disable hover detection in tooltip
    }

    // Layout
    property bool vertical: false
    property int panelLocation: 4  // PlasmaCore.Types: LeftEdge=5, TopEdge=2, RightEdge=6, BottomEdge=4
    readonly property bool panelOnLeft: panelLocation === 5
    readonly property bool panelOnRight: panelLocation === 6
    readonly property bool panelOnTop: panelLocation === 2
    readonly property bool panelOnBottom: panelLocation === 4

    // Task properties
    property int taskIndex: 0
    property var iconSource: ""
    property string taskName: ""
    property bool isActive: false
    property bool isMinimized: false
    property bool isLauncher: false
    property bool isDemandingAttention: false
    property bool isGroupParent: false

    // Group properties
    property int groupChildCount: 0
    property int activeChildIndex: -1  // Which child in group is active (-1 = none)

    // Audio stream properties
    property var audioStreams: []
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    // PulseAudio volume constants (passed from TaskList)
    property int volumeStep: 3277  // ~5% of normalVolume (65536)
    property int maxVolume: 65536  // PulseAudio.NormalVolume (100%)

    // Audio display settings
    property bool showAudioIndicator: false
    property bool allowVolumeControl: false

    function toggleMuted() {
        if (muted) {
            audioStreams.forEach(item => item.unmute());
        } else {
            audioStreams.forEach(item => item.mute());
        }
    }

    signal volumeChanged(real percent)

    function changeVolume(angleDelta) {
        // 120 = one standard scroll notch. Scale proportionally.
        var step = (angleDelta / 120.0) * volumeStep;
        var lastNewVol = 0;
        audioStreams.forEach(function(stream) {
            var newVol = Math.round(stream.volume + step);
            newVol = Math.max(0, Math.min(newVol, maxVolume));
            stream.setVolume(newVol);
            lastNewVol = newVol;
        });
        // Emit new volume percent for popup
        if (audioStreams.length > 0) {
            volumeChanged(Math.round(lastNewVol / maxVolume * 100));
        }
    }

    // Icon size normalization (percentage 50-100)
    property int iconSizePercent: 100

    // Zoom properties
    property int baseSize: 48
    property bool zoomEnabled: true
    property real maxZoomFactor: 1.24  // Max 1.24 to avoid clipping on floating panels
    property real targetZoom: 1.0
    property int zoomDuration: 120
    property bool isTransitioning: false  // True when mouse is in task area (use faster animation)

    // Parabolic rise properties
    property bool parabolicEnabled: true
    property int maxParabolicRise: 12
    property real targetRise: 0

    // Frozen zoom/rise: tracks targetZoom while mouse is in area,
    // freezes at last value when mouse leaves (for smooth exit animation)
    property real activeZoom: 1.0
    property real activeRise: 0

    onTargetZoomChanged: {
        if (isTransitioning) activeZoom = targetZoom;
    }
    onTargetRiseChanged: {
        if (isTransitioning) activeRise = targetRise;
    }
    onIsTransitioningChanged: {
        if (isTransitioning) {
            // Reset frozen values at start of new hover
            activeZoom = targetZoom;
            activeRise = targetRise;
        }
    }

    // Zoom multiplier: animates 0→1 on enter, 1→0 on exit.
    property real zoomMultiplier: isTransitioning ? 1.0 : 0.0
    Behavior on zoomMultiplier {
        NumberAnimation { duration: taskItem.zoomDuration; easing.type: Easing.OutCubic }
    }

    // Computed display values: instant response via activeZoom, smooth enter/exit via multiplier
    readonly property real displayZoom: 1.0 + (activeZoom - 1.0) * zoomMultiplier
    readonly property real displayRise: activeRise * zoomMultiplier

    // Hover state
    property bool hovered: mouseArea.containsMouse

    // Drag state
    property bool isDragging: false

    // Drop state (for file drag and drop)
    property bool dropHovered: false

    // Signals
    signal clicked(int button, int modifiers)
    signal contextMenuRequested()
    signal mouseMoved(real localX, real localY)
    signal dragStarted()
    signal filesDropped(var urls)
    signal launcherDropped(var urls)
    signal hoverChanged(bool isHovered)
    signal dragHoverChanged(bool isDragHovered)

    onHoveredChanged: {
        hoverChanged(hovered);
    }

    // Fixed size for stable layout - zoom is purely visual (no layout shifts)
    width: baseSize
    height: baseSize

    // Clip disabled - allows zoomed icon to extend beyond bounds without affecting layout
    clip: false

    // Static z-index based on taskIndex - higher index = higher z
    // This avoids z-index changes on hover which cause rendering glitches
    z: taskIndex

    // Drop area for file drag and drop
    DropArea {
        id: dropArea
        anchors.fill: parent
        anchors.margins: -2  // Slight expansion to catch drops at edges
        z: 1001  // Above globalMouseArea (z: 1000)

        onEntered: function(drag) {
            if (drag.hasUrls) {
                taskItem.dropHovered = true;
                taskItem.dragHoverChanged(true);
                drag.accepted = true;
                // Start activation timer (activate window after hover delay)
                dropActivationTimer.start();
            }
        }

        onExited: {
            taskItem.dropHovered = false;
            taskItem.dragHoverChanged(false);
            dropActivationTimer.stop();
        }

        onDropped: function(drop) {
            taskItem.dropHovered = false;
            dropActivationTimer.stop();
            if (!drop.hasUrls) {
                return;
            }
            // Group dialog handles opening files on a group icon
            if (taskItem.isGroupParent) {
                drop.accepted = false;
                return;
            }

            const launchers = [];
            const documents = [];
            for (let i = 0; i < drop.urls.length; ++i) {
                if (LauncherFromDrop.isLauncherLike(drop.urls[i]))
                    launchers.push(drop.urls[i]);
                else
                    documents.push(drop.urls[i]);
            }
            if (launchers.length > 0)
                taskItem.launcherDropped(launchers);
            if (documents.length > 0)
                taskItem.filesDropped(documents);
            drop.accepted = true;
        }
    }

    // Timer to activate window when hovering with drag
    Timer {
        id: dropActivationTimer
        interval: 300
        onTriggered: {
            // Don't activate for group parents - they show dialog instead
            if (!taskItem.isGroupParent) {
                taskItem.filesDropped([]);  // Empty array signals "just activate"
            }
        }
    }

    // Main mouse area for hover, clicks, and drag
    // z: 100 ensures it's above all visual elements (iconContainer, indicators)
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        z: 100

        property bool dragActive: false
        property real pressX: 0
        property real pressY: 0
        readonly property int dragThreshold: 5

        onPressed: function(mouse) {
            pressX = mouse.x;
            pressY = mouse.y;
            dragActive = false;
        }

        onPositionChanged: function(mouse) {
            if (pressed && !dragActive) {
                var dx = mouse.x - pressX;
                var dy = mouse.y - pressY;
                if (Math.sqrt(dx * dx + dy * dy) > dragThreshold) {
                    dragActive = true;
                    taskItem.isDragging = true;
                    taskItem.dragStarted();
                }
            }
            taskItem.mouseMoved(mouse.x, mouse.y);
        }

        onReleased: function(mouse) {
            if (dragActive) {
                dragActive = false;
                taskItem.isDragging = false;
            }
        }

        onClicked: function(mouse) {
            console.log("Task clicked, button:", mouse.button, "dragActive:", dragActive);
            if (dragActive) return;
            if (mouse.button === Qt.RightButton) {
                console.log("Right click - emitting contextMenuRequested");
                taskItem.contextMenuRequested();
            } else {
                taskItem.clicked(mouse.button, mouse.modifiers);
            }
        }

        onWheel: function(wheel) {
            if (taskItem.allowVolumeControl && taskItem.hasAudioStream) {
                taskItem.changeVolume(wheel.angleDelta.y);
            }
        }
    }

    // Icon container - renders at max size, uses GPU-accelerated scale for smooth animation
    Item {
        id: iconContainer
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // Rise direction: away from the panel edge
        anchors.verticalCenterOffset: {
            if (taskItem.vertical) return 0;
            return taskItem.panelOnTop ? taskItem.displayRise : -taskItem.displayRise;
        }
        anchors.horizontalCenterOffset: {
            if (!taskItem.vertical) return 0;
            return taskItem.panelOnLeft ? taskItem.displayRise : -taskItem.displayRise;
        }
        opacity: taskItem.isDragging ? 0.4 : 1.0

        // Render icon at maximum possible size for crisp quality at any zoom level
        property int maxSize: Math.round(baseSize * maxZoomFactor)
        // Extra padding so layer FBO doesn't clip icons that have no built-in padding (e.g. PNGs)
        property int containerSize: maxSize + 8

        // Calculate scale relative to max size (GPU-accelerated, smooth 60fps)
        property real pressScale: mouseArea.pressed ? 0.9 : 1.0
        property real attentionScale: 1.0
        property real dropScale: 1.0
        property real animatedPressScale: pressScale

        Behavior on animatedPressScale {
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }

        property real targetScale: (displayZoom / maxZoomFactor) * (maxSize / containerSize) * animatedPressScale * attentionScale * dropScale

        // Gentle pulse only — large scale was clipped by the panel and the layer FBO
        SequentialAnimation {
            running: taskItem.dropHovered
            loops: Animation.Infinite
            NumberAnimation { target: iconContainer; property: "dropScale"; to: 1.06; duration: 400; easing.type: Easing.OutCubic }
            NumberAnimation { target: iconContainer; property: "dropScale"; to: 1.0; duration: 400; easing.type: Easing.InCubic }
            onStopped: iconContainer.dropScale = 1.0
        }

        width: containerSize
        height: containerSize
        scale: targetScale  // Animated via displayZoom Behavior

        // Cache rendered icon in a texture to eliminate pixel jitter during zoom animation
        layer.enabled: true
        layer.smooth: true

        Kirigami.Icon {
            id: icon
            anchors.centerIn: parent
            // 0.88 adds ~6% padding on each side to prevent clipping for icons
            // that have no built-in transparent padding (e.g. PNGs, some SVGs)
            width: Math.round(parent.width * taskItem.iconSizePercent / 100 * 0.88)
            height: Math.round(parent.height * taskItem.iconSizePercent / 100 * 0.88)
            source: taskItem.iconSource
            fallback: "application-x-executable"
        }

        // Attention animation
        SequentialAnimation {
            running: taskItem.isDemandingAttention && !taskItem.hovered
            loops: Animation.Infinite
            NumberAnimation { target: iconContainer; property: "attentionScale"; to: 1.1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: iconContainer; property: "attentionScale"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 500 }
        }
    }

    // Soft plate behind the icon — wider along the dock, not taller than the panel.
    Rectangle {
        id: dropPlate
        z: 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: iconContainer.anchors.verticalCenterOffset
        anchors.horizontalCenterOffset: iconContainer.anchors.horizontalCenterOffset
        readonly property real visualIconSize: {
            const extras = iconContainer.animatedPressScale * iconContainer.attentionScale * iconContainer.dropScale;
            return taskItem.baseSize * taskItem.displayZoom * (taskItem.iconSizePercent / 100.0) * 0.88 * extras;
        }
        readonly property real plateAlong: visualIconSize + Kirigami.Units.gridUnit
        readonly property real plateAcross: Math.min(taskItem.vertical ? taskItem.width : taskItem.height, visualIconSize) * 0.94
        width: taskItem.vertical ? plateAcross : plateAlong
        height: taskItem.vertical ? plateAlong : plateAcross
        radius: Math.min(width, height) * 0.38
        color: Kirigami.Theme.highlightColor
        opacity: taskItem.dropHovered ? 0.3 : 0
        visible: opacity > 0.01
        scale: taskItem.dropHovered ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation { duration: 140 }
        }
        Behavior on scale {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    // Audio stream indicator - shows speaker icon when app is playing audio
    Kirigami.Icon {
        id: audioIndicator
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 2
        anchors.topMargin: 2
        width: Math.round(baseSize * 0.35)
        height: width
        source: taskItem.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
        visible: taskItem.showAudioIndicator && (taskItem.playingAudio || taskItem.muted)
        z: 100

        // Background circle for better visibility
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 2
            height: width
            radius: width / 2
            color: Kirigami.Theme.backgroundColor
            opacity: 0.8
            z: -1
        }

        // Click to toggle mute
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onClicked: taskItem.toggleMuted()
            cursorShape: Qt.PointingHandCursor
            onWheel: function(wheel) { wheel.accepted = false; }
        }
    }

    // Running indicator - outside iconContainer so it doesn't scale
    // Positioned at the panel edge side
    Rectangle {
        id: runningIndicator
        anchors.horizontalCenter: taskItem.vertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: taskItem.vertical ? parent.verticalCenter : undefined
        anchors.bottom: (!taskItem.vertical && taskItem.panelOnBottom) ? parent.bottom : undefined
        anchors.top: (!taskItem.vertical && taskItem.panelOnTop) ? parent.top : undefined
        anchors.left: (taskItem.vertical && taskItem.panelOnLeft) ? parent.left : undefined
        anchors.right: (taskItem.vertical && taskItem.panelOnRight) ? parent.right : undefined
        anchors.bottomMargin: taskItem.panelOnBottom ? -5 : 0
        anchors.topMargin: taskItem.panelOnTop ? -5 : 0
        anchors.leftMargin: taskItem.panelOnLeft ? -5 : 0
        anchors.rightMargin: taskItem.panelOnRight ? -5 : 0
        width: 5
        height: width
        radius: width / 2
        visible: !taskItem.isLauncher && !taskItem.isGroupParent
        color: taskItem.isActive ? Kirigami.Theme.highlightColor :
               taskItem.isDemandingAttention ? Kirigami.Theme.negativeTextColor :
               Kirigami.Theme.textColor
        opacity: taskItem.isActive ? 1.0 : 0.5
    }

    // Group indicator - outside iconContainer so it doesn't scale
    Row {
        id: groupIndicator
        anchors.horizontalCenter: taskItem.vertical ? undefined : parent.horizontalCenter
        anchors.verticalCenter: taskItem.vertical ? parent.verticalCenter : undefined
        anchors.bottom: (!taskItem.vertical && taskItem.panelOnBottom) ? parent.bottom : undefined
        anchors.top: (!taskItem.vertical && taskItem.panelOnTop) ? parent.top : undefined
        anchors.left: (taskItem.vertical && taskItem.panelOnLeft) ? parent.left : undefined
        anchors.right: (taskItem.vertical && taskItem.panelOnRight) ? parent.right : undefined
        anchors.bottomMargin: taskItem.panelOnBottom ? -5 : 0
        anchors.topMargin: taskItem.panelOnTop ? -5 : 0
        anchors.leftMargin: taskItem.panelOnLeft ? -5 : 0
        anchors.rightMargin: taskItem.panelOnRight ? -5 : 0
        spacing: 3
        visible: taskItem.isGroupParent

        Repeater {
            model: Math.max(taskItem.isGroupParent ? 2 : 0, Math.min(taskItem.groupChildCount, 5))
            Rectangle {
                width: 4
                height: width
                radius: width / 2
                color: index === taskItem.activeChildIndex ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                opacity: index === taskItem.activeChildIndex ? 1.0 : 0.4
            }
        }
    }
}
