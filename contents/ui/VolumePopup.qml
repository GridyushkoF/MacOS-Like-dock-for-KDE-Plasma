/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmaCore.Dialog {
    id: volumePopup

    visible: true

    property int volumePercent: 0

    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false
    location: Plasmoid.location

    function restartHideTimer() {
        hideTimer.restart();
    }

    mainItem: RowLayout {
        width: Kirigami.Units.gridUnit * 12
        height: Kirigami.Units.gridUnit * 2
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: volumePopup.volumePercent === 0 ? "audio-volume-muted-symbolic"
                  : volumePopup.volumePercent < 33 ? "audio-volume-low-symbolic"
                  : volumePopup.volumePercent < 66 ? "audio-volume-medium-symbolic"
                  : "audio-volume-high-symbolic"
        }

        QQC2.ProgressBar {
            Layout.fillWidth: true
            from: 0
            to: 100
            value: volumePopup.volumePercent
        }

        PlasmaComponents3.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2
            text: volumePopup.volumePercent + "%"
            horizontalAlignment: Text.AlignRight
        }

        Timer {
            id: hideTimer
            interval: 1500
            running: true
            onTriggered: volumePopup.visible = false;
        }
    }

    onVisibleChanged: {
        if (!visible) {
            destroy();
        }
    }
}
