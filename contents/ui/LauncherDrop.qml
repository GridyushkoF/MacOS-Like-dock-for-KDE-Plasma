/*
    Resolve dropped files to dock launchers without the private taskmanager Backend.
    .desktop / applications: → pin that app (prefer a system applications: id).
    Other files → pin the default handler for their MIME type.
*/

import QtQuick
import QtCore

import org.kde.plasma.plasma5support as Plasma5Support

import "code/launcherfromdrop.js" as Drop

Item {
    id: root

    required property var tasksModel
    width: 0
    height: 0
    visible: false

    readonly property var ctx: ({
        configDir: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation),
        appDirs: StandardPaths.standardLocations(StandardPaths.ApplicationsLocation),
        dataDirs: StandardPaths.standardLocations(StandardPaths.GenericDataLocation),
        homeDir: StandardPaths.writableLocation(StandardPaths.HomeLocation),
    })

    property var pendingMime: ({})

    function isLauncherLike(url) {
        return Drop.isLauncherLike(url);
    }

    function addFromUrls(urls) {
        if (!tasksModel || !urls || urls.length === 0)
            return;

        const result = Drop.resolveUrls(urls, ctx);
        for (let i = 0; i < result.launchers.length; ++i)
            pin(result.launchers[i]);

        for (let j = 0; j < result.needsProbe.length; ++j)
            probeDefaultApp(result.needsProbe[j]);
    }

    function pin(launcherUrl) {
        if (!tasksModel || !launcherUrl)
            return false;

        if (tasksModel.requestAddLauncher(launcherUrl))
            return true;

        const fallback = Drop.fileUrlForApplications(launcherUrl, ctx);
        if (fallback && fallback !== launcherUrl)
            return tasksModel.requestAddLauncher(fallback);

        return false;
    }

    function probeDefaultApp(localPath) {
        if (!localPath)
            return;
        const cmd = "xdg-mime query filetype " + Drop.shellQuote(localPath);
        pendingMime[cmd] = localPath;
        mimeExec.connectSource(cmd);
    }

    Plasma5Support.DataSource {
        id: mimeExec
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            const stdout = String((data && data.stdout) || "").trim();
            const path = root.pendingMime[sourceName];
            delete root.pendingMime[sourceName];

            if (sourceName.indexOf("xdg-mime query filetype ") === 0) {
                if (!stdout)
                    return;
                const cmd = "xdg-mime query default " + Drop.shellQuote(stdout);
                root.pendingMime[cmd] = path || stdout;
                connectSource(cmd);
                return;
            }

            if (sourceName.indexOf("xdg-mime query default ") === 0 && stdout)
                root.pin(Drop.applicationsUrl(stdout));
        }
    }
}
