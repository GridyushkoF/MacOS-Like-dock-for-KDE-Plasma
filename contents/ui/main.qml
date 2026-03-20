/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    Based on KDE Plasma Task Manager by Eike Hein
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

import org.kde.taskmanager as TaskManager
import org.kde.plasma.private.taskmanager as TaskManagerApplet
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property int location: Plasmoid.location
    readonly property bool iconsOnly: true  // Always icons only for this widget

    // Zoom properties from config
    readonly property bool zoomEnabled: Plasmoid.configuration.zoomEnabled
    readonly property real zoomFactor: Plasmoid.configuration.zoomFactor
    readonly property int zoomDuration: Plasmoid.configuration.zoomDuration
    readonly property bool zoomNeighbors: Plasmoid.configuration.zoomNeighbors
    readonly property real neighborZoomFactor: Plasmoid.configuration.neighborZoomFactor
    readonly property bool parabolicEnabled: Plasmoid.configuration.parabolicEnabled
    readonly property int maxParabolicRise: Plasmoid.configuration.maxParabolicRise

    preferredRepresentation: fullRepresentation

    Plasmoid.constraintHints: Plasmoid.CanFillArea

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill

    Layout.minimumWidth: {
        if (tasksModel.count === 0) {
            return Kirigami.Units.gridUnit;
        }
        return taskList.implicitWidth;
    }
    Layout.minimumHeight: {
        if (tasksModel.count === 0) {
            return Kirigami.Units.gridUnit;
        }
        return taskList.implicitHeight;
    }

    Layout.preferredWidth: {
        if (tasksModel.count === 0) {
            return 0.01;
        }
        if (vertical) {
            return Kirigami.Units.gridUnit * 3;
        }
        return taskList.implicitWidth;
    }
    Layout.preferredHeight: {
        if (tasksModel.count === 0) {
            return 0.01;
        }
        if (vertical) {
            return taskList.implicitHeight;
        }
        return Kirigami.Units.gridUnit * 3;
    }

    property Item dragSource

    // Context menu component
    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")

    // Group dialog component
    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property var activeGroupDialog: null

    // MPRIS source for media controls in context menu
    Mpris.Mpris2Model {
        id: mpris2Source
    }

    // PulseAudio for volume control
    PulseAudio {
        id: pulseAudio
    }

    // TaskManager Model
    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized

        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        separateLaunchers: Plasmoid.configuration.separateLaunchers
        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: false
        hideActivatedLaunchers: true
        launchInPlace: Plasmoid.configuration.sortingStrategy === 1

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index) {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.SortDisabled;
            case 1:
                return TaskManager.TasksModel.SortManual;
            case 2:
                return TaskManager.TasksModel.SortAlpha;
            case 3:
                return TaskManager.TasksModel.SortVirtualDesktop;
            case 4:
                return TaskManager.TasksModel.SortActivity;
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index) {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            default:
                return TaskManager.TasksModel.GroupDisabled;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
        }
    }

    TaskManagerApplet.Backend {
        id: backend

        onAddLauncher: url => {
            tasksModel.requestAddLauncher(url);
        }
    }

    TaskManager.VirtualDesktopInfo {
        id: virtualDesktopInfo
    }

    TaskManager.ActivityInfo {
        id: activityInfo
    }

    // Main content
    Item {
        anchors.fill: parent

        // Reliable hover tracking for the entire widget area
        HoverHandler {
            id: widgetHoverHandler
            onHoveredChanged: {
                if (!hovered) {
                    taskList.forceResetHover();
                }
            }
        }

        TaskList {
            id: taskList
            // Fixed positioning - no centerIn to avoid recalculation on hover
            anchors.left: root.vertical ? undefined : parent.left
            anchors.top: root.vertical ? parent.top : undefined
            anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
            anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined

            // Pass the actual panel size to TaskList
            width: root.vertical ? parent.width : implicitWidth
            height: root.vertical ? implicitHeight : parent.height

            model: tasksModel
            vertical: root.vertical
            panelLocation: root.location
            panelThickness: root.vertical ? root.width : root.height
            zoomEnabled: root.zoomEnabled
            zoomFactor: root.zoomFactor
            zoomDuration: root.zoomDuration
            pulseAudio: pulseAudio
            zoomNeighbors: root.zoomNeighbors
            neighborZoomFactor: root.neighborZoomFactor
            iconSpacing: Plasmoid.configuration.iconSpacing
            widgetHovered: widgetHoverHandler.hovered
            parabolicEnabled: root.parabolicEnabled
            maxParabolicRise: root.maxParabolicRise

            onTaskClicked: function(index, button, modifiers) {
                var modelIndex = tasksModel.makeModelIndex(index);
                var isActive = tasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsActive);
                var isLauncher = tasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsLauncher);
                var isMinimized = tasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsMinimized);
                var isGroupParent = tasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsGroupParent);

                if (button === Qt.LeftButton) {
                    if (modifiers & Qt.ShiftModifier) {
                        tasksModel.requestNewInstance(modelIndex);
                    } else if (isGroupParent) {
                        // Show group popup with list of windows
                        root.showGroupDialog(index);
                    } else if (isLauncher) {
                        tasksModel.requestActivate(modelIndex);
                    } else if (isActive) {
                        tasksModel.requestToggleMinimized(modelIndex);
                    } else {
                        tasksModel.requestActivate(modelIndex);
                    }
                } else if (button === Qt.MiddleButton) {
                    handleMiddleClick(modelIndex);
                }
            }

            onTaskContextMenu: function(index) {
                console.log("TaskContextMenu called for index:", index);
                var modelIndex = tasksModel.makeModelIndex(index);
                var task = taskList.getTaskAt(index);
                console.log("Task:", task, "ModelIndex:", modelIndex);
                if (task) {
                    var menu = root.createContextMenu(task, modelIndex);
                    console.log("Menu created:", menu);
                    if (menu) {
                        menu.show();
                        console.log("Menu.show() called");
                    }
                }
            }

            onTaskFilesDropped: function(index, urls) {
                var modelIndex = tasksModel.makeModelIndex(index);
                var isLauncher = tasksModel.data(modelIndex, TaskManager.AbstractTasksModel.IsLauncher);

                if (urls.length === 0) {
                    // Empty urls = just activate the window (hover activation during drag)
                    if (!isLauncher) {
                        tasksModel.requestActivate(modelIndex);
                    }
                } else {
                    // Files were dropped - open them with this app
                    if (isLauncher) {
                        // For launchers, open the app with the files
                        tasksModel.requestOpenUrls(modelIndex, urls);
                    } else {
                        // For running apps, also use requestOpenUrls
                        tasksModel.requestOpenUrls(modelIndex, urls);
                    }
                }
            }
        }
    }

    function showGroupDialog(index) {
        if (activeGroupDialog) {
            activeGroupDialog.visible = false;
            activeGroupDialog = null;
        }
        var task = taskList.getTaskAt(index);
        if (task) {
            activeGroupDialog = groupDialogComponent.createObject(root, {
                visualParent: task,
                tasksModel: tasksModel,
                groupIndex: index,
            });
        }
    }

    function createContextMenu(task, modelIndex, args = {}) {
        if (contextMenuComponent.status !== Component.Ready) {
            console.log("ContextMenu component error:", contextMenuComponent.errorString());
            return null;
        }
        const initialArgs = Object.assign(args, {
            visualParent: task,
            modelIndex: modelIndex,
            mpris2Source: mpris2Source,
            backend: backend,
            tasksModel: tasksModel,
            virtualDesktopInfo: virtualDesktopInfo,
            activityInfo: activityInfo,
        });
        var menu = contextMenuComponent.createObject(task, initialArgs);
        if (!menu) {
            console.log("Failed to create context menu, component error:", contextMenuComponent.errorString());
        }
        return menu;
    }

    function handleMiddleClick(modelIndex) {
        switch (Plasmoid.configuration.middleClickAction) {
        case 0: // None
            break;
        case 1: // Close
            tasksModel.requestClose(modelIndex);
            break;
        case 2: // New Instance
            tasksModel.requestNewInstance(modelIndex);
            break;
        case 3: // Toggle Minimized
            tasksModel.requestToggleMinimized(modelIndex);
            break;
        case 4: // Toggle Grouping
            tasksModel.requestToggleGrouping(modelIndex);
            break;
        case 5: // Bring to Current Desktop
            tasksModel.requestVirtualDesktops(modelIndex, [virtualDesktopInfo.currentDesktop]);
            break;
        }
    }

    Connections {
        target: Plasmoid.configuration

        function onLaunchersChanged() {
            tasksModel.launcherList = Plasmoid.configuration.launchers;
        }
        function onGroupingAppIdBlacklistChanged() {
            tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
        }
        function onGroupingLauncherUrlBlacklistChanged() {
            tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
        }
    }
}
