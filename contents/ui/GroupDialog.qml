/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import org.kde.taskmanager as TaskManager

PlasmaCore.Dialog {
    id: groupDialog

    property var tasksModel
    property int groupIndex: -1

    visible: true
    type: PlasmaCore.Dialog.PopupMenu
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: true
    location: Plasmoid.location

    mainItem: ListView {
        id: listView

        width: Math.max(Kirigami.Units.gridUnit * 14, contentItem.childrenRect.width)
        height: Math.min(Kirigami.Units.gridUnit * 20, contentHeight)

        model: {
            if (!groupDialog.tasksModel || groupDialog.groupIndex < 0) return 0;
            var parentIdx = groupDialog.tasksModel.makeModelIndex(groupDialog.groupIndex);
            return groupDialog.tasksModel.rowCount(parentIdx);
        }

        delegate: PlasmaComponents3.ItemDelegate {
            id: windowDelegate
            width: listView.width
            height: Kirigami.Units.gridUnit * 2.5

            property var childModelIndex: {
                var parentIdx = groupDialog.tasksModel.makeModelIndex(groupDialog.groupIndex);
                return groupDialog.tasksModel.index(index, 0, parentIdx);
            }

            property string windowTitle: groupDialog.tasksModel.data(childModelIndex, Qt.DisplayRole) || ""
            property var windowIcon: groupDialog.tasksModel.data(childModelIndex, Qt.DecorationRole)
            property bool isActive: groupDialog.tasksModel.data(childModelIndex, TaskManager.AbstractTasksModel.IsActive) || false
            property bool isMinimized: groupDialog.tasksModel.data(childModelIndex, TaskManager.AbstractTasksModel.IsMinimized) || false

            highlighted: isActive

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    source: windowDelegate.windowIcon
                }

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    text: windowDelegate.windowTitle
                    elide: Text.ElideRight
                    opacity: windowDelegate.isMinimized ? 0.6 : 1.0
                }
            }

            onClicked: {
                groupDialog.tasksModel.requestActivate(childModelIndex);
                groupDialog.visible = false;
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            groupDialog.requestActivate();
        } else {
            destroy();
        }
    }
}
