/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

Item {
    id: taskListRoot

    property var model
    property bool vertical: false
    property int panelLocation: 4  // PlasmaCore.Types.BottomEdge default
    property int panelThickness: 48
    property bool zoomEnabled: true
    property real zoomFactor: 1.5
    property int zoomDuration: 150
    property bool zoomNeighbors: true
    property bool growOnMagnifiedSide: true
    property real neighborZoomFactor: 1.2
    property int iconSpacing: 1
    property bool widgetHovered: false
    property bool parabolicEnabled: true
    property int maxParabolicRise: 12
    property bool shrinkDistant: false
    property real distantShrinkFactor: 0.8
    property bool antiClip: false
    property int iconSizePercent: 100

    // Auto-shrink properties
    property bool autoShrink: true
    property int minIconSize: 24
    property int availableSpace: 0  // Available space for icons (width for horizontal, height for vertical)

    // Audio
    property var pulseAudio: null
    property bool showAudioIndicator: false
    property bool allowVolumeControl: false

    property int hoveredIndex: -1

    // Cursor in resting space, kept after leaving so the dock shrinks in place
    property real pointerCursor: 0
    property bool cursorKnown: false
    property bool mouseInArea: false

    property real zoomStrength: mouseInArea && cursorKnown ? 1 : 0
    Behavior on zoomStrength {
        NumberAnimation { duration: taskListRoot.zoomDuration; easing.type: Easing.OutCubic }
    }

    // 0 = rest length, 1 = hover length
    property real panelProgress: mouseInArea && cursorKnown ? 1 : 0
    Behavior on panelProgress {
        NumberAnimation { duration: taskListRoot.zoomDuration; easing.type: Easing.InOutCubic }
    }

    // Tracks whether mouse has moved recently (to distinguish "left" from "stationary")
    property bool mouseMovedRecently: false

    // Drag state
    property int dragSourceIndex: -1
    property bool dragInProgress: false

    // Helper to get audio streams for a task
    function audioStreamsForTask(modelIndex) {
        if (!pulseAudio) return [];

        const start = modelIndex;
        const start_row = model.index(modelIndex, 0);

        const start_pid = model.data(start_row, TaskManager.AbstractTasksModel.AppPid) || 0;
        const start_appName = model.data(start_row, TaskManager.AbstractTasksModel.AppName) || "";

        let start_streams = [];

        if (start_pid > 0) {
            start_streams = pulseAudio.streamsForPid(start_pid);
            if (start_streams.length === 0 && start_appName.length > 0) {
                start_streams = pulseAudio.streamsForAppName(start_appName);
            }
        }

        return start_streams;
    }

    // Reset hover state
    function resetHoverState() {
        taskListRoot.hoveredIndex = -1;
        taskListRoot.mouseInArea = false;
        taskListRoot.mouseMovedRecently = false;
    }

    // Force reset from parent (called by HoverHandler in main.qml)
    function forceResetHover() {
        activityTimer.stop();
        resetHoverState();
    }

    // Two-phase exit detection that doesn't rely on onExited or containsMouse:
    //
    // Phase 1: activityTimer fires 250ms after last mouse movement.
    //          Sets mouseMovedRecently=false and starts confirmTimer.
    //
    // Phase 2: confirmTimer fires 100ms later. If mouseMovedRecently
    //          is still false (no new movement), reset hover state.
    //          If mouse moved in between, it was just a pause — keep zoom.

    Timer {
        id: activityTimer
        interval: 250
        onTriggered: {
            taskListRoot.mouseMovedRecently = false;
            confirmTimer.start();
        }
    }

    Timer {
        id: confirmTimer
        interval: 100
        onTriggered: {
            if (!taskListRoot.mouseMovedRecently && !taskListRoot.widgetHovered) {
                resetHoverState();
            }
        }
    }

    // Update audio streams when PulseAudio streams change
    Connections {
        target: pulseAudio
        function onStreamsChanged() {
            // Force re-evaluation of audioStreams for all tasks
            for (let i = 0; i < taskRepeater.count; i++) {
                const task = taskRepeater.itemAt(i);
                if (task) {
                    task.audioStreams = taskListRoot.audioStreamsForTask(i);
                }
            }
        }
    }

    signal taskClicked(int index, int button, int modifiers)
    signal taskContextMenu(int index)
    signal taskFilesDropped(int index, var urls)
    signal taskLauncherDropped(var urls)
    signal taskDragHover(int index, bool isDragHovered)

    function getTaskAt(index) {
        return taskRepeater.itemAt(index);
    }

    // Counter that increments on model changes to force rebinding
    property int modelUpdateCounter: 0

    function getGroupChildCount(taskIndex) {
        // Reference counter to trigger updates
        var _ = modelUpdateCounter;
        var idx = model.makeModelIndex(taskIndex);
        return model.rowCount(idx);
    }

    function getActiveChildIndex(taskIndex) {
        // Reference counter to trigger updates
        var _ = modelUpdateCounter;
        var parentIdx = model.makeModelIndex(taskIndex);
        var count = model.rowCount(parentIdx);
        for (var i = 0; i < count; i++) {
            var childIdx = model.index(i, 0, parentIdx);
            if (model.data(childIdx, TaskManager.AbstractTasksModel.IsActive)) {
                return i;
            }
        }
        return -1;
    }

    // Update counter when model data changes
    Connections {
        target: taskListRoot.model
        function onDataChanged() {
            taskListRoot.modelUpdateCounter++;
        }
    }

    readonly property int baseIconSize: Math.max(panelThickness - Kirigami.Units.smallSpacing * 4, Kirigami.Units.iconSizes.medium)
    readonly property int preAntiClipSize: antiClip ? Math.round(baseIconSize * 0.9) : baseIconSize
    readonly property int itemSpacing: Kirigami.Units.smallSpacing * iconSpacing

    // Auto-shrink calculation
    readonly property int effectiveIconSize: {
        // Skip auto-shrink if disabled or invalid state
        if (!autoShrink || taskRepeater.count === 0) {
            return preAntiClipSize;
        }

        // Need reasonable available space (at least space for one icon at min size)
        if (availableSpace < minIconSize) {
            return preAntiClipSize;
        }

        // Calculate how much space icons would take at base size
        var totalSpacing = Math.max(0, taskRepeater.count - 1) * itemSpacing;
        var neededSpace = taskRepeater.count * preAntiClipSize + totalSpacing;

        // If they fit, use normal size
        if (neededSpace <= availableSpace) {
            return preAntiClipSize;
        }

        // Calculate shrunk size
        var shrunkSize = Math.floor((availableSpace - totalSpacing) / taskRepeater.count);

        // Clamp to minimum
        return Math.max(minIconSize, shrunkSize);
    }

    // Half the spacing on each side keeps the row centered
    readonly property real cellSize: effectiveIconSize + itemSpacing
    readonly property real restLength: taskRepeater.count * cellSize

    function smoothstep(edge0, edge1, x) {
        var t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
        return t * t * (3 - 2 * t);
    }

    function targetZoomAt(index) {
        if (!cursorKnown) return 1.0;
        return zoomAtCursor(index, pointerCursor);
    }

    function zoomAtCursor(index, cursor) {
        if (!zoomEnabled) return 1.0;

        // In cells from this icon's center
        var normalizedDistance = Math.abs(cursor - (index + 0.5) * cellSize) / cellSize;

        var maxZoom = zoomFactor;
        var borderZoom = zoomNeighbors ? neighborZoomFactor : 1.0;
        var maxDist = zoomNeighbors ? 2.5 : 0.5;
        var minZoom = shrinkDistant ? distantShrinkFactor : 1.0;
        var farDist = maxDist + 2.0;  // Distance at which icons reach minimum size

        if (normalizedDistance <= 0.5) {
            return maxZoom + (borderZoom - maxZoom) * smoothstep(0, 0.5, normalizedDistance);
        } else if (normalizedDistance <= maxDist) {
            return borderZoom + (1.0 - borderZoom) * smoothstep(0.5, maxDist, normalizedDistance);
        } else if (shrinkDistant && normalizedDistance <= farDist) {
            return 1.0 + (minZoom - 1.0) * smoothstep(maxDist, farDist, normalizedDistance);
        }
        return minZoom;
    }

    function targetRiseAt(index) {
        if (!parabolicEnabled || !cursorKnown) return 0;

        var normalizedDistance = Math.abs(pointerCursor - (index + 0.5) * cellSize) / cellSize;
        var maxDist = 2.5;
        if (normalizedDistance <= maxDist) {
            return maxParabolicRise * (1 - smoothstep(0, maxDist, normalizedDistance));
        }
        return 0;
    }

    // Growth before the cursor, so the icon under it stays put
    function leadingGrowthOf(zooms, cursor) {
        if (!growOnMagnifiedSide) {
            return cellSize * zooms.reduce((sum, zoom) => sum + zoom - 1, 0) / 2;
        }
        var growth = 0;
        for (var index = 0; index < zooms.length; index++) {
            var coveredFraction = Math.max(0, Math.min(1, cursor / cellSize - index));
            growth += cellSize * (zooms[index] - 1) * coveredFraction;
        }
        return growth;
    }

    readonly property var zoomLayout: {
        var zooms = [];
        var starts = [];
        var length = 0;
        for (var index = 0; index < taskRepeater.count; index++) {
            var zoom = 1.0 + (targetZoomAt(index) - 1.0) * zoomStrength;
            zooms.push(zoom);
            starts.push(length);
            length += cellSize * zoom;
        }
        var leadingGrowth = leadingGrowthOf(zooms, pointerCursor);
        return {
            zooms: zooms,
            starts: starts,
            length: length,
            leadingGrowth: leadingGrowth,
            trailingGrowth: length - restLength - leadingGrowth
        };
    }

    // Most the magnified row can grow to either side
    readonly property real maximumSideGrowth: {
        var widest = 0;
        var samplesPerCell = 8;
        for (var sample = 0; sample <= taskRepeater.count * samplesPerCell; sample++) {
            var cursor = sample * cellSize / samplesPerCell;
            var zooms = [];
            var growth = 0;
            for (var index = 0; index < taskRepeater.count; index++) {
                zooms.push(zoomAtCursor(index, cursor));
                growth += cellSize * (zooms[index] - 1);
            }
            var leadingGrowth = leadingGrowthOf(zooms, cursor);
            widest = Math.max(widest, leadingGrowth, growth - leadingGrowth);
        }
        return widest;
    }

    // Fixed so hovering never resizes the panel; even to stay centered
    readonly property int reservedSize: 2 * Math.ceil(restLength / 2 + maximumSideGrowth)

    // Centered growth holds the mask at its widest while hovering
    readonly property real maskLeadingGrowth: growOnMagnifiedSide ? zoomLayout.leadingGrowth : maximumSideGrowth * panelProgress
    readonly property real maskTrailingGrowth: growOnMagnifiedSide ? zoomLayout.trailingGrowth : maximumSideGrowth * panelProgress

    implicitWidth: vertical ? panelThickness : reservedSize
    implicitHeight: vertical ? reservedSize : panelThickness

    // Pins the row to the window center while a resize lands
    property real windowCenterOffset: 0
    property bool isCenteredInWindow: false

    function updateWindowAlignment() {
        var window = Window.window;
        if (!window) return;
        var origin = mapToItem(null, 0, 0);
        var offset = vertical ? window.height / 2 - origin.y - height / 2
                              : window.width / 2 - origin.x - width / 2;
        var isResizing = (zoomStrength > 0 && zoomStrength < 1) || (panelProgress > 0 && panelProgress < 1);
        if (!isResizing) {
            isCenteredInWindow = Math.abs(offset) < 1;
        }
        windowCenterOffset = isCenteredInWindow ? offset : 0;
    }

    FrameAnimation {
        running: taskListRoot.zoomStrength > 0 || taskListRoot.panelProgress > 0
        onTriggered: taskListRoot.updateWindowAlignment()
        onRunningChanged: taskListRoot.updateWindowAlignment()
    }
    onMouseInAreaChanged: updateWindowAlignment()

    // Measured from the row center, which doesn't move with the magnification
    function updateCursor(along) {
        var length = vertical ? height : width;
        pointerCursor = along - length / 2 - windowCenterOffset + restLength / 2;
        cursorKnown = true;
    }

    function restIndexAtCursor() {
        return Math.floor(pointerCursor / cellSize);
    }

    // Volume popup dialog
    property var volumeDialog: null
    readonly property Component volumePopupComponent: Qt.createComponent("VolumePopup.qml")

    function showVolumePopup(taskIndex, percent) {
        var task = taskRepeater.itemAt(taskIndex);
        if (!task) return;

        if (volumeDialog) {
            volumeDialog.volumePercent = percent;
            volumeDialog.restartHideTimer();
            return;
        }

        if (volumePopupComponent.status !== Component.Ready) {
            console.log("VolumePopup component error:", volumePopupComponent.errorString());
            return;
        }

        volumeDialog = volumePopupComponent.createObject(taskListRoot, {
            visualParent: task,
            volumePercent: percent,
        });

        if (!volumeDialog) {
            console.log("VolumePopup creation failed");
            return;
        }

        volumeDialog.onVisibleChanged.connect(function() {
            if (volumeDialog && !volumeDialog.visible) {
                volumeDialog.destroy();
                volumeDialog = null;
            }
        });
    }

    // Container for manually positioned tasks - no layout recalculations
    Item {
        id: taskContainer
        anchors.fill: parent

        Repeater {
            id: taskRepeater
            model: taskListRoot.model

            delegate: Task {
                id: taskDelegate

                required property var model
                required property int index

                readonly property real slotStart: ((vertical ? taskListRoot.height : taskListRoot.width) - taskListRoot.restLength) / 2
                    + taskListRoot.windowCenterOffset
                    - taskListRoot.zoomLayout.leadingGrowth
                    + (taskListRoot.zoomLayout.starts[index] || 0)
                readonly property real slotLength: taskListRoot.cellSize * (taskListRoot.zoomLayout.zooms[index] || 1)

                x: vertical ? (taskListRoot.width - width) / 2 : slotStart
                y: vertical ? slotStart : (taskListRoot.height - height) / 2
                width: vertical ? taskListRoot.effectiveIconSize : slotLength
                height: vertical ? slotLength : taskListRoot.effectiveIconSize

                vertical: taskListRoot.vertical
                panelLocation: taskListRoot.panelLocation
                taskIndex: index
                iconSource: model.decoration
                taskName: model.display || ""
                isActive: model.IsActive || false
                isMinimized: model.IsMinimized || false
                isLauncher: model.IsLauncher || false
                isDemandingAttention: model.IsDemandingAttention || false
                isGroupParent: model.IsGroupParent || false

                // Group properties - use function to force recalculation (depend on modelUpdateCounter)
                groupChildCount: {
                    var _ = taskListRoot.modelUpdateCounter;
                    return isGroupParent ? taskListRoot.getGroupChildCount(index) : 0;
                }
                activeChildIndex: {
                    var _ = taskListRoot.modelUpdateCounter;
                    return isGroupParent ? taskListRoot.getActiveChildIndex(index) : -1;
                }

                // Audio properties
                maxVolume: taskListRoot.pulseAudio ? taskListRoot.pulseAudio.normalVolume : 65536
                volumeStep: Math.round(maxVolume * 0.05)  // 5% per scroll step
                showAudioIndicator: taskListRoot.showAudioIndicator
                allowVolumeControl: taskListRoot.allowVolumeControl

                // Audio streams for this task
                audioStreams: taskListRoot.audioStreamsForTask(index)

                baseSize: taskListRoot.effectiveIconSize
                iconSizePercent: taskListRoot.iconSizePercent
                zoomEnabled: taskListRoot.zoomEnabled
                maxZoomFactor: taskListRoot.zoomFactor
                zoomDuration: taskListRoot.zoomDuration
                parabolicEnabled: taskListRoot.parabolicEnabled
                maxParabolicRise: taskListRoot.maxParabolicRise

                displayZoom: taskListRoot.zoomLayout.zooms[index] || 1.0
                displayRise: taskListRoot.targetRiseAt(index) * taskListRoot.zoomStrength

                onHoverChanged: function(isHovered) {
                    if (isHovered) {
                        taskListRoot.mouseMovedRecently = true;
                        activityTimer.restart();
                        taskListRoot.hoveredIndex = index;
                        taskListRoot.mouseInArea = true;
                    } else if (taskListRoot.hoveredIndex === index) {
                        activityTimer.restart();
                    }
                }

                onMouseMoved: function(localX, localY) {
                    var position = taskDelegate.mapToItem(taskListRoot, localX, localY);
                    taskListRoot.updateCursor(vertical ? position.y : position.x);

                    // Handle drag reordering
                    if (isDragging && taskListRoot.dragInProgress) {
                        var targetIdx = Math.max(0, Math.min(taskListRoot.restIndexAtCursor(), taskRepeater.count - 1));
                        if (targetIdx !== taskListRoot.dragSourceIndex) {
                            taskListRoot.model.move(taskListRoot.dragSourceIndex, targetIdx);
                            taskListRoot.dragSourceIndex = targetIdx;
                        }
                    }
                }

                onClicked: function(button, modifiers) {
                    taskListRoot.taskClicked(index, button, modifiers);
                }

                onContextMenuRequested: {
                    taskListRoot.taskContextMenu(index);
                }

                onVolumeChanged: function(percent) {
                    taskListRoot.showVolumePopup(index, percent);
                }

                onDragStarted: {
                    taskListRoot.dragSourceIndex = index;
                    taskListRoot.dragInProgress = true;
                }

                onIsDraggingChanged: {
                    if (!isDragging && taskListRoot.dragInProgress) {
                        taskListRoot.dragInProgress = false;
                        taskListRoot.dragSourceIndex = -1;
                        // Sync launchers to persist the new order
                        taskListRoot.model.syncLaunchers();
                    }
                }

                onFilesDropped: function(urls) {
                    taskListRoot.taskFilesDropped(index, urls);
                }

                onLauncherDropped: function(urls) {
                    taskListRoot.taskLauncherDropped(urls);
                }

                onDragHoverChanged: function(isDragHovered) {
                    taskListRoot.taskDragHover(index, isDragHovered);
                }
            }
        }

        // Global mouse area to track position across all icons
        MouseArea {
            id: globalMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            propagateComposedEvents: true
            z: 1000

            onPressed: function(mouse) { mouse.accepted = false; }
            onReleased: function(mouse) { mouse.accepted = false; }
            onClicked: function(mouse) { mouse.accepted = false; }

            onPositionChanged: function(mouse) {
                taskListRoot.mouseMovedRecently = true;
                activityTimer.restart();
                taskListRoot.mouseInArea = true;
                taskListRoot.updateCursor(vertical ? mouse.y : mouse.x);

                var hoveredRestIndex = taskListRoot.restIndexAtCursor();
                var isOverTask = hoveredRestIndex >= 0 && hoveredRestIndex < taskRepeater.count;
                if (isOverTask) {
                    taskListRoot.hoveredIndex = hoveredRestIndex;
                }
            }

            onExited: {
                activityTimer.stop();
                confirmTimer.stop();
                resetHoverState();
            }
        }
    }
}
