/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_zoomEnabled: zoomEnabledCheck.checked
    property real cfg_zoomFactor: 1.5
    property alias cfg_zoomDuration: zoomDurationSlider.value
    property alias cfg_zoomNeighbors: zoomNeighborsCheck.checked
    property real cfg_neighborZoomFactor: 1.2
    property alias cfg_parabolicEnabled: parabolicEnabledCheck.checked
    property alias cfg_maxParabolicRise: parabolicRiseSlider.value
    property alias cfg_iconSpacing: iconSpacingSlider.value
    property alias cfg_fill: fillCheck.checked

    // Convert between UI scale (1-10) and real zoom factor (1.0-1.24)
    // UI 1 = 1.0x (no zoom), UI 10 = 1.24x (max zoom without clipping)
    function uiToReal(uiValue) {
        return 1.0 + (uiValue - 1) * 0.24 / 9;
    }
    function realToUi(realValue) {
        return 1 + (realValue - 1.0) * 9 / 0.24;
    }
    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Zoom Animation")
        }

        QQC2.CheckBox {
            id: zoomEnabledCheck
            Kirigami.FormData.label: i18n("Enable zoom on hover:")
            text: i18n("Zoom icons when mouse hovers over them")
        }

        QQC2.Slider {
            id: zoomFactorSlider
            Kirigami.FormData.label: i18n("Zoom factor:")
            from: 1
            to: 10
            stepSize: 1
            enabled: zoomEnabledCheck.checked
            value: realToUi(cfg_zoomFactor)
            onMoved: cfg_zoomFactor = uiToReal(value)

            QQC2.ToolTip {
                text: i18n("Level %1 (%2x)", Math.round(zoomFactorSlider.value), uiToReal(zoomFactorSlider.value).toFixed(2))
                visible: zoomFactorSlider.hovered || zoomFactorSlider.pressed
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Current zoom:")
            QQC2.Label {
                text: i18n("Level %1 (%2x)", Math.round(zoomFactorSlider.value), uiToReal(zoomFactorSlider.value).toFixed(2))
            }
        }

        QQC2.Slider {
            id: zoomDurationSlider
            Kirigami.FormData.label: i18n("Animation duration:")
            from: 50
            to: 500
            stepSize: 25
            enabled: zoomEnabledCheck.checked
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Duration:")
            QQC2.Label {
                text: zoomDurationSlider.value + " ms"
            }
        }

        QQC2.CheckBox {
            id: zoomNeighborsCheck
            Kirigami.FormData.label: i18n("Dock-like effect:")
            text: i18n("Also zoom neighboring icons")
            enabled: zoomEnabledCheck.checked
        }

        QQC2.Slider {
            id: neighborZoomFactorSlider
            Kirigami.FormData.label: i18n("Neighbor scale:")
            from: 1
            to: 10
            stepSize: 1
            enabled: zoomEnabledCheck.checked && zoomNeighborsCheck.checked
            value: realToUi(cfg_neighborZoomFactor)
            onMoved: cfg_neighborZoomFactor = uiToReal(value)

            QQC2.ToolTip {
                text: i18n("Level %1 (%2x)", Math.round(neighborZoomFactorSlider.value), uiToReal(neighborZoomFactorSlider.value).toFixed(2))
                visible: neighborZoomFactorSlider.hovered || neighborZoomFactorSlider.pressed
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Neighbor scale:")
            QQC2.Label {
                text: i18n("Level %1 (%2x)", Math.round(neighborZoomFactorSlider.value), uiToReal(neighborZoomFactorSlider.value).toFixed(2))
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Parabolic Effect (macOS Style)")
        }

        QQC2.CheckBox {
            id: parabolicEnabledCheck
            Kirigami.FormData.label: i18n("Enable parabolic rise:")
            text: i18n("Icons rise up when hovered (like macOS Dock)")
            enabled: zoomEnabledCheck.checked
        }

        QQC2.Slider {
            id: parabolicRiseSlider
            Kirigami.FormData.label: i18n("Rise height:")
            from: 0
            to: 12
            stepSize: 1
            enabled: zoomEnabledCheck.checked && parabolicEnabledCheck.checked
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Rise height:")
            QQC2.Label {
                text: parabolicRiseSlider.value + " px"
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Layout")
        }

        QQC2.Slider {
            id: iconSpacingSlider
            Kirigami.FormData.label: i18n("Icon spacing:")
            from: 0
            to: 15
            stepSize: 1
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Spacing:")
            QQC2.Label {
                text: iconSpacingSlider.value + " units"
            }
        }

        QQC2.CheckBox {
            id: fillCheck
            Kirigami.FormData.label: i18n("Fill available space:")
            text: i18n("Task manager occupies all available space")
        }
    }
}
