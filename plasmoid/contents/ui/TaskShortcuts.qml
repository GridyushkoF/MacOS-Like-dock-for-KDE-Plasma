/*
    SPDX-FileCopyrightText: 2024 Custom Developer
    SPDX-License-Identifier: GPL-2.0-or-later

    Meta+1..Meta+9 for this dock.

    On Plasma 6.6 plasmashell already owns those keys and calls
    activateTaskAtIndex() on the applet. Registering here as well covers
    Plasma 6.7+, where plasmashell no longer does that and the stock
    task manager only installs the keys when its own applet is loaded.

    The deprecated setShortcut(as, ai, u) is used on purpose. Its key list
    is a plain array of ints. The newer setShortcutKeys wants a(ai), and a
    short array in that struct is what crashes kglobalacceld.
*/

import QtQuick
import org.kde.plasma.workspace.dbus as DBus

Item {
    id: shortcuts

    // Output this dock is on. Empty means "don't filter".
    property string outputName: ""

    signal entryActivated(int index)

    readonly property string componentUnique: "org.kde.plasma.icontasks2"
    property bool loggedError: false

    // DBus STRING / OBJECTPATH values arrive as gadgets, not JS strings.
    function asString(value) {
        if (value === undefined || value === null) {
            return "";
        }
        if (typeof value === "string") {
            return value;
        }
        if (typeof value.path === "string" && value.path.length > 0) {
            return value.path;
        }
        if (value.value !== undefined && value.value !== value) {
            const inner = asString(value.value);
            if (inner.length > 0) {
                return inner;
            }
        }
        if (typeof value.toString === "function") {
            const text = String(value.toString());
            if (text.length > 0 && text.indexOf("object Object") === -1) {
                return text;
            }
        }
        return "";
    }

    function metaKey(entryNumber) {
        // Qt::MetaModifier (0x10000000) | Qt::Key_1..Key_9 (0x31..0x39).
        return 0x10000030 + entryNumber;
    }

    function logError(reply) {
        if (loggedError) {
            return;
        }
        loggedError = true;
        const message = (reply && reply.error && reply.error.message) ? reply.error.message : "unknown DBus error";
        console.warn("Icons-Only Task Manager 2: Meta+number registration failed:", message);
    }

    function registerEntry(entryNumber, done) {
        const actionId = [
            componentUnique,
            "activate entry " + entryNumber,
            "Icons-Only Task Manager 2",
            i18n("Activate Dock Entry %1", entryNumber),
        ];
        // Plasma's encoder treats a parenthesized signature as one struct
        // and turns its fields into the DBus arguments.
        const present = {
            service: "org.kde.kglobalaccel",
            path: "/kglobalaccel",
            iface: "org.kde.KGlobalAccel",
            member: "setShortcut",
            arguments: [actionId, [shortcuts.metaKey(entryNumber)], 2], // SetPresent, keep a saved shortcut
            signature: "(asaiu)",
        };
        const asDefault = {
            service: "org.kde.kglobalaccel",
            path: "/kglobalaccel",
            iface: "org.kde.KGlobalAccel",
            member: "setShortcut",
            arguments: [actionId, [shortcuts.metaKey(entryNumber)], 8], // IsDefault
            signature: "(asaiu)",
        };
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/kglobalaccel",
            iface: "org.kde.KGlobalAccel",
            member: "doRegister",
            arguments: [actionId],
            signature: "(as)",
        }, function() {
            DBus.SessionBus.asyncCall(asDefault, function() {}, shortcuts.logError);
            DBus.SessionBus.asyncCall(present, function() {
                if (done) {
                    done();
                }
            }, function(reply) {
                shortcuts.logError(reply);
                if (done) {
                    done();
                }
            });
        }, function(reply) {
            shortcuts.logError(reply);
            if (done) {
                done();
            }
        });
    }

    function handleAction(actionUnique) {
        const match = /^activate entry (\d+)$/.exec(String(actionUnique));
        if (!match) {
            return;
        }
        const entry = Number(match[1]);
        if (entry < 1) {
            return;
        }
        shortcuts.activateIfOnActiveOutput(entry - 1);
    }

    function activateIfOnActiveOutput(index) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: "/KWin",
            iface: "org.kde.KWin",
            member: "activeOutputName",
        }, function(reply) {
            const active = shortcuts.asString(reply ? reply.value : "");
            if (!shortcuts.outputName || !active || active === shortcuts.outputName) {
                shortcuts.entryActivated(index);
            }
        }, function() {
            shortcuts.entryActivated(index);
        });
    }

    DBus.SignalWatcher {
        id: ownWatcher
        busType: DBus.BusType.Session
        service: "org.kde.kglobalaccel"
        // Dots in the component id are underscores in the object path.
        // getComponent() below replaces this if the daemon disagrees.
        path: "/component/org_kde_plasma_icontasks2"
        iface: "org.kde.kglobalaccel.Component"

        function dbusglobalShortcutPressed(componentUnique, actionUnique, timestamp) {
            shortcuts.handleAction(actionUnique);
        }
        function dbusglobalShortcutReleased(componentUnique, actionUnique, timestamp) {}
        function dbusglobalShortcutRepeated(componentUnique, actionUnique, timestamp) {}
    }

    function refreshComponentPath() {
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/kglobalaccel",
            iface: "org.kde.KGlobalAccel",
            member: "getComponent",
            arguments: [componentUnique],
            signature: "(s)",
        }, function(reply) {
            const path = shortcuts.asString(reply ? reply.value : "");
            if (path.length > 0) {
                ownWatcher.path = path;
            }
        }, function() {});
    }

    Component.onCompleted: {
        let pending = 9;
        function finishedOne() {
            pending -= 1;
            if (pending <= 0) {
                shortcuts.refreshComponentPath();
            }
        }
        for (let entry = 1; entry <= 9; ++entry) {
            registerEntry(entry, finishedOne);
        }
    }
}
