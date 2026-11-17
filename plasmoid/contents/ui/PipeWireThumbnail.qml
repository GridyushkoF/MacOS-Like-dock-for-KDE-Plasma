/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.pipewire as PipeWire
import org.kde.taskmanager as TaskManager

Item {
    id: pipeWireThumbnail

    property string visibleUuid: ""
    readonly property bool hasThumbnail: pipeWireSourceItem.nodeId > 0

    PipeWire.PipeWireSourceItem {
        id: pipeWireSourceItem
        anchors.fill: parent
        nodeId: waylandItem.nodeId
    }

    TaskManager.ScreencastingRequest {
        id: waylandItem
        uuid: pipeWireThumbnail.visibleUuid
    }
}
