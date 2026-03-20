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
    property alias cfg_showOnlyCurrentScreen: showOnlyCurrentScreenCheck.checked
    property alias cfg_showOnlyCurrentDesktop: showOnlyCurrentDesktopCheck.checked
    property alias cfg_showOnlyCurrentActivity: showOnlyCurrentActivityCheck.checked
    property alias cfg_showOnlyMinimized: showOnlyMinimizedCheck.checked
    property alias cfg_groupingStrategy: groupingStrategyCombo.currentIndex
    property alias cfg_sortingStrategy: sortingStrategyCombo.currentIndex
    property alias cfg_separateLaunchers: separateLaunchersCheck.checked
    property alias cfg_middleClickAction: middleClickActionCombo.currentIndex

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Filtering")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentScreenCheck
            Kirigami.FormData.label: i18n("Show only tasks:")
            text: i18n("From current screen")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentDesktopCheck
            text: i18n("From current desktop")
        }

        QQC2.CheckBox {
            id: showOnlyCurrentActivityCheck
            text: i18n("From current activity")
        }

        QQC2.CheckBox {
            id: showOnlyMinimizedCheck
            text: i18n("Only minimized")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Grouping and Sorting")
        }

        QQC2.ComboBox {
            id: groupingStrategyCombo
            Kirigami.FormData.label: i18n("Grouping:")
            model: [i18n("Do not group"), i18n("By program name")]
        }

        QQC2.ComboBox {
            id: sortingStrategyCombo
            Kirigami.FormData.label: i18n("Sorting:")
            model: [
                i18n("Do not sort"),
                i18n("Manually"),
                i18n("Alphabetically"),
                i18n("By desktop"),
                i18n("By activity")
            ]
        }

        QQC2.CheckBox {
            id: separateLaunchersCheck
            Kirigami.FormData.label: i18n("Launchers:")
            text: i18n("Keep launchers separate")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Actions")
        }

        QQC2.ComboBox {
            id: middleClickActionCombo
            Kirigami.FormData.label: i18n("Middle click:")
            model: [
                i18n("None"),
                i18n("Close"),
                i18n("New instance"),
                i18n("Toggle minimized"),
                i18n("Toggle grouping"),
                i18n("Bring to current desktop")
            ]
        }

    }
}
