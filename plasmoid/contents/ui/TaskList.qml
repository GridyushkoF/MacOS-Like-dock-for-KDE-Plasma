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
    // Off: icons scale in place and the row keeps its resting length.
    property bool growingDock: true
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

    // Cursor in resting space, kept after leaving so the dock shrinks in place.
    // Magnification is the bell at this position. Mouse events only store
    // pointerTarget; the row copies it once a frame, which is not a follow delay.
    property real pointerTarget: 0
    property real pointerCursor: 0
    FrameAnimation {
        id: magnifyFrames
        running: taskListRoot.magnified || taskListRoot.zoomStrength > 0.001
        onTriggered: {
            if (Math.abs(taskListRoot.pointerTarget - taskListRoot.pointerCursor) > 0.01)
                taskListRoot.pointerCursor = taskListRoot.pointerTarget;
        }
    }
    property bool cursorKnown: false
    property bool mouseInArea: false
    // Latched separately from hover events. A one-frame hover drop must not
    // reverse zoomStrength, or the row grows and shrinks in place (the shake).
    property bool magnified: false
    // Screen position of the resting row, captured when magnification starts.
    // Re-reading it every move feeds the dock's own slide back into the cursor.
    property real frozenRestZero: 0
    property bool restFrozen: false
    property real lastPointerMs: 0
    // Resting row offset inside this item. Frozen while magnified so a 1px
    // panel resize cannot slide every icon.
    property real pinnedCenter: 0

    property real zoomStrength: magnified && cursorKnown ? 1 : 0
    Behavior on zoomStrength {
        NumberAnimation { duration: taskListRoot.zoomDuration; easing.type: Easing.OutCubic }
    }

    // 0 = rest length, 1 = hover length
    property real panelProgress: magnified && cursorKnown ? 1 : 0
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
        taskListRoot.magnified = false;
        taskListRoot.mouseMovedRecently = false;
        taskListRoot.restFrozen = false;
        taskListRoot.pinRowCenter();
    }

    function pinRowCenter() {
        var length = vertical ? height : width;
        pinnedCenter = (length - restLength) / 2;
    }

    // One frame, so a false leave during a fast swipe does not drop the zoom.
    // Long enough to notice was the old 140–350ms hold.
    function forceResetHover() {
        leaveTimer.restart();
    }

    Timer {
        id: leaveTimer
        interval: 16
        onTriggered: {
            if (!globalMouseArea.containsMouse) {
                taskListRoot.resetHoverState();
            }
        }
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
            if (!taskListRoot.mouseMovedRecently && !globalMouseArea.containsMouse) {
                taskListRoot.resetHoverState();
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

    // WaylandTasksModel ignores the QRect and also ignores item transforms.
    // It sends delegate.x/y/width/height mapped through the parent. The zoom
    // lives on a child scale, so the task slot is not the painted icon, and
    // the gap grows with the panel size on a scaled screen. This stand-in is
    // reparented to the panel scene root and sized to the icon's real bounds;
    // the model reads it synchronously, so one item can serve every task.
    Item {
        id: iconGeometryDelegate
        visible: false
        enabled: false
    }

    function sceneRoot() {
        const window = taskListRoot.Window.window;
        return window ? window.contentItem : null;
    }

    // Axis-aligned bounds of the painted icon, in `target`'s coordinates.
    // mapToItem includes the icon scale and the parabolic rise.
    function boundsIn(item, target) {
        if (!item || !target || item.width < 1 || item.height < 1) {
            return null;
        }
        if (typeof item.mapToItem !== "function") {
            return null;
        }
        const tl = item.mapToItem(target, 0, 0);
        const br = item.mapToItem(target, item.width, item.height);
        if (!tl || !br || tl.x === undefined || br.x === undefined) {
            return null;
        }
        const w = Math.abs(br.x - tl.x);
        const h = Math.abs(br.y - tl.y);
        if (w < 1 || h < 1) {
            return null;
        }
        return Qt.rect(Math.round(Math.min(tl.x, br.x)), Math.round(Math.min(tl.y, br.y)),
                       Math.round(w), Math.round(h));
    }

    // X11 uses this rect and multiplies it by the application scale.
    // mapToGlobal is logical pixels, which is what that multiplication expects.
    function globalRectOf(icon) {
        if (!icon || !icon.Window.window || icon.width < 1 || icon.height < 1) {
            return null;
        }
        const tl = icon.mapToGlobal(0, 0);
        const br = icon.mapToGlobal(icon.width, icon.height);
        if (!tl || !br || tl.x === undefined || br.x === undefined) {
            return null;
        }
        const x = Math.min(tl.x, br.x);
        const y = Math.min(tl.y, br.y);
        const w = Math.abs(br.x - tl.x);
        const h = Math.abs(br.y - tl.y);
        if (w < 1 || h < 1) {
            return null;
        }
        return Qt.rect(Math.round(x), Math.round(y), Math.round(w), Math.round(h));
    }

    function schedulePublishIconGeometries() {
        // While the row is following the pointer, x and zoom change every
        // frame. Publishing that asks KWin to update every minimized window
        // and drops frames on a fast swipe.
        if (magnified) {
            return;
        }
        iconGeometryTimer.restart();
    }

    onMagnifiedChanged: if (!magnified) iconGeometryTimer.restart()

    function publishIconGeometries() {
        if (!model) {
            return;
        }
        try {
            publishIconGeometriesNow();
        } catch (error) {
            console.warn("Icons-Only Task Manager 2: icon geometry skipped:", error);
        }
    }

    function publishIconGeometriesNow() {
        const count = taskRepeater.count;
        for (let i = 0; i < count; ++i) {
            const task = taskRepeater.itemAt(i);
            if (!task) {
                continue;
            }
            // Launchers and startups have no window yet. A group parent
            // publishes one rect; TasksModel copies it to every child.
            if (task.isLauncher || task.isStartup) {
                task.lastIconGeometry = Qt.rect(0, 0, -1, -1);
                continue;
            }
            const root = sceneRoot();
            const icon = task.iconItem;
            const local = boundsIn(icon, root);
            const rect = globalRectOf(icon);
            if (!root || !local || !rect) {
                continue;
            }
            const prev = task.lastIconGeometry;
            if (prev.width === rect.width && prev.height === rect.height
                    && prev.x === rect.x && prev.y === rect.y) {
                continue;
            }
            const modelIndex = model.makeModelIndex(i);
            if (!modelIndex || !modelIndex.valid) {
                continue;
            }
            if (iconGeometryDelegate.parent !== root) {
                iconGeometryDelegate.parent = root;
            }
            iconGeometryDelegate.x = local.x;
            iconGeometryDelegate.y = local.y;
            iconGeometryDelegate.width = local.width;
            iconGeometryDelegate.height = local.height;
            model.requestPublishDelegateGeometry(modelIndex, rect, iconGeometryDelegate);
            task.lastIconGeometry = rect;
        }
    }

    Timer {
        id: iconGeometryTimer
        interval: 50
        onTriggered: taskListRoot.publishIconGeometries()
    }

    // The panel window is often still at 0,0 when the first delegates appear.
    Timer {
        interval: 200
        running: true
        onTriggered: taskListRoot.publishIconGeometries()
    }

    Timer {
        interval: 800
        running: true
        onTriggered: taskListRoot.publishIconGeometries()
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: taskListRoot.publishIconGeometries()
    }

    Connections {
        target: taskListRoot.Window.window
        function onXChanged() { taskListRoot.schedulePublishIconGeometries(); }
        function onYChanged() { taskListRoot.schedulePublishIconGeometries(); }
        function onWidthChanged() { taskListRoot.schedulePublishIconGeometries(); }
        function onHeightChanged() { taskListRoot.schedulePublishIconGeometries(); }
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

    function targetZoomAt(index) {
        if (!cursorKnown) return 1.0;
        return zoomAtCursor(index, pointerCursor);
    }

    // Raised cosine. Slope is zero on the icon under the cursor, so the
    // peak does not pop, and the falloff is spread out instead of delayed.
    function magnificationRadius() {
        if (!zoomNeighbors)
            return 0.75;
        var span = zoomFactor - 1.0;
        if (span < 0.02)
            return 3.0;
        var ratio = (neighborZoomFactor - 1.0) / span;
        ratio = Math.max(0.08, Math.min(0.92, ratio));
        return Math.PI / Math.acos(2 * ratio - 1);
    }

    // One raised cosine across the whole influence, same shape as the macOS
    // dock. The old curve held the neighbor flat, then dropped to rest in
    // half an icon, which reads as a snap when the cursor is followed live.
    // Radius stops at 2 so the icon past the neighbor stays put.
    function influenceRadius() {
        if (!zoomNeighbors)
            return 0.75;
        return Math.min(magnificationRadius(), 2);
    }

    function magnificationBell(normalizedDistance) {
        var maxDist = influenceRadius();
        if (normalizedDistance >= maxDist)
            return 0;
        return 0.5 * (1 + Math.cos(Math.PI * normalizedDistance / maxDist));
    }

    function zoomAtCursor(index, cursor) {
        if (!zoomEnabled) return 1.0;

        var normalizedDistance = Math.abs(cursor - (index + 0.5) * cellSize) / cellSize;
        var bell = magnificationBell(normalizedDistance);
        if (bell > 0)
            return 1.0 + (zoomFactor - 1.0) * bell;
        if (!shrinkDistant)
            return 1.0;
        var far = magnificationRadius() + 2.0;
        if (normalizedDistance >= far)
            return distantShrinkFactor;
        var edge = 0.5 * (1 + Math.cos(Math.PI * (normalizedDistance - magnificationRadius()) / 2.0));
        return distantShrinkFactor + (1.0 - distantShrinkFactor) * edge;
    }

    function targetRiseAt(index) {
        if (!parabolicEnabled || !cursorKnown) return 0;
        var normalizedDistance = Math.abs(pointerCursor - (index + 0.5) * cellSize) / cellSize;
        return maxParabolicRise * magnificationBell(normalizedDistance);
    }

    // Neighbors ease aside across the same hump as the zoom. The icon under
    // the cursor and anything past the hump stay on their resting slot.
    function localShiftOf(index, visualZoom, cursor) {
        if (!growingDock)
            return 0;
        var center = (index + 0.5) * cellSize;
        var delta = center - cursor;
        var nd = Math.abs(delta) / cellSize;
        var maxDist = influenceRadius();
        if (nd >= maxDist || nd < 0.001)
            return 0;
        var window = Math.sin(Math.PI * nd / maxDist);
        var extra = cellSize * (visualZoom - 1);
        return (delta >= 0 ? 1 : -1) * extra * 0.5 * window;
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
        var shifts = [];
        var rises = [];
        var count = taskRepeater.count;
        var cursor = pointerCursor;
        for (var index = 0; index < count; index++) {
            var zoom = 1.0 + (zoomAtCursor(index, cursor) - 1.0) * zoomStrength;
            zooms.push(zoom);
            var normalizedDistance = Math.abs(cursor - (index + 0.5) * cellSize) / cellSize;
            rises.push((parabolicEnabled ? maxParabolicRise * magnificationBell(normalizedDistance) : 0) * zoomStrength);
        }
        for (var shiftIndex = 0; shiftIndex < count; shiftIndex++) {
            shifts.push(localShiftOf(shiftIndex, zooms[shiftIndex], cursor));
        }
        return {
            zooms: zooms,
            shifts: shifts,
            rises: rises,
            length: restLength,
            leadingGrowth: 0,
            trailingGrowth: 0
        };
    }

    // Most the magnified row can grow to either side
    readonly property real maximumSideGrowth: {
        if (!growingDock)
            return 0;
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

    onWidthChanged: if (!magnified) pinRowCenter()
    onHeightChanged: if (!magnified) pinRowCenter()
    onRestLengthChanged: if (!magnified) pinRowCenter()
    Component.onCompleted: pinRowCenter()

    // Screen cursor minus the resting row's screen position at the moment
    // magnification started. The origin stays put, so the dock sliding under
    // a still pointer cannot change the cursor and shake the row.
    function notePointer(screenAlong) {
        if (screenAlong === undefined || screenAlong === null) {
            return;
        }
        lastPointerMs = Date.now();
        if (!restFrozen) {
            var origin = null;
            try {
                origin = mapToGlobal(0, 0);
            } catch (error) {
                return;
            }
            if (!origin || origin.x === undefined) {
                return;
            }
            pinRowCenter();
            frozenRestZero = (vertical ? origin.y : origin.x) + pinnedCenter;
            restFrozen = true;
        }
        pointerTarget = screenAlong - frozenRestZero;
        magnified = true;
        mouseInArea = true;
        if (!cursorKnown) {
            pointerCursor = pointerTarget;
            cursorKnown = true;
        }
    }

    function restIndexAtCursor() {
        return Math.floor(pointerTarget / cellSize);
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

                // Resting slot. Far icons do not read the cursor, so they cannot drift.
                readonly property real rowShift: taskListRoot.pinnedCenter
                readonly property real slotStart: rowShift + index * taskListRoot.cellSize + (taskListRoot.zoomLayout.shifts[index] || 0)
                readonly property real slotLength: taskListRoot.cellSize

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
                isStartup: (model && model.IsStartup) ? true : false
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
                displayRise: taskListRoot.zoomLayout.rises[index] || 0

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
                    // Hover zoom is tracked by the stable area below. This
                    // delegate moves with the magnification, so feeding its
                    // local point back into the cursor makes the row shake.
                    if (!(isDragging && taskListRoot.dragInProgress)) {
                        return;
                    }
                    var screen = taskDelegate.mapToGlobal(localX, localY);
                    if (screen) {
                        taskListRoot.notePointer(vertical ? screen.y : screen.x);
                    }
                    var targetIdx = Math.max(0, Math.min(taskListRoot.restIndexAtCursor(), taskRepeater.count - 1));
                    if (targetIdx !== taskListRoot.dragSourceIndex) {
                        taskListRoot.model.move(taskListRoot.dragSourceIndex, targetIdx);
                        taskListRoot.dragSourceIndex = targetIdx;
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

                onXChanged: taskListRoot.schedulePublishIconGeometries()
                onYChanged: taskListRoot.schedulePublishIconGeometries()
                onWidthChanged: taskListRoot.schedulePublishIconGeometries()
                onHeightChanged: taskListRoot.schedulePublishIconGeometries()
                onIsLauncherChanged: taskListRoot.schedulePublishIconGeometries()
                onIsStartupChanged: taskListRoot.schedulePublishIconGeometries()
                onDisplayZoomChanged: taskListRoot.schedulePublishIconGeometries()
                onDisplayRiseChanged: taskListRoot.schedulePublishIconGeometries()
            }

            onItemAdded: taskListRoot.schedulePublishIconGeometries()
            onItemRemoved: taskListRoot.schedulePublishIconGeometries()
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
                leaveTimer.stop();
                taskListRoot.mouseInArea = true;
                var screen = mapToGlobal(mouse.x, mouse.y);
                if (screen) {
                    taskListRoot.notePointer(vertical ? screen.y : screen.x);
                }

                var hoveredRestIndex = taskListRoot.restIndexAtCursor();
                var isOverTask = hoveredRestIndex >= 0 && hoveredRestIndex < taskRepeater.count;
                if (isOverTask) {
                    taskListRoot.hoveredIndex = hoveredRestIndex;
                }
            }

            onExited: leaveTimer.restart()
        }
    }
}
