.pragma library

var _globs = null;
var _defaults = null;

function isLauncherLike(url) {
    const s = normalizeUrl(url);
    if (!s)
        return false;
    if (s.startsWith("applications:") || s.startsWith("preferred:"))
        return true;
    return desktopFileName(s).length > 0;
}

function normalizeUrl(url) {
    let s = String(url || "").trim();
    if (!s)
        return "";
    const hash = s.indexOf("#");
    if (hash >= 0)
        s = s.slice(0, hash);
    const q = s.indexOf("?");
    if (q >= 0 && (s.startsWith("file:") || s.startsWith("/")))
        s = s.slice(0, q);
    return s;
}

function toLocalPath(url) {
    let s = normalizeUrl(url);
    if (!s)
        return "";
    if (s.startsWith("file://")) {
        let rest = s.slice(7);
        if (rest.startsWith("localhost/"))
            rest = rest.slice(9);
        else if (rest.startsWith("localhost"))
            rest = rest.slice(9);
        try {
            return decodeURIComponent(rest);
        } catch (e) {
            return rest;
        }
    }
    if (s.startsWith("/"))
        return s;
    return "";
}

function pathToFileUrl(path) {
    if (!path)
        return "";
    if (path.startsWith("file:"))
        return path;
    const parts = String(path).split("/");
    for (let i = 0; i < parts.length; ++i)
        parts[i] = encodeURIComponent(parts[i]).replace(/%3A/gi, ":");
    // encodeURIComponent encodes empty first segment of absolute path as ""
    return "file://" + parts.join("/");
}

function basename(path) {
    const s = String(path || "").replace(/\/+$/, "");
    const i = s.lastIndexOf("/");
    return i >= 0 ? s.slice(i + 1) : s;
}

function dirname(path) {
    const s = String(path || "").replace(/\/+$/, "");
    const i = s.lastIndexOf("/");
    return i > 0 ? s.slice(0, i) : "/";
}

function desktopFileName(urlOrPath) {
    const s = normalizeUrl(urlOrPath);
    if (s.startsWith("applications:")) {
        const id = s.slice("applications:".length);
        return id.endsWith(".desktop") ? id : (id ? id + ".desktop" : "");
    }
    const path = toLocalPath(s) || s;
    const name = basename(path).split("?")[0];
    if (name.toLowerCase().endsWith(".desktop"))
        return name;
    return "";
}

function stripFilePrefix(loc) {
    let s = String(loc || "");
    if (s.startsWith("file://")) {
        try {
            s = decodeURIComponent(s.slice(7));
        } catch (e) {
            s = s.slice(7);
        }
    }
    return s;
}

function readTextFile(path) {
    const local = stripFilePrefix(path);
    if (!local)
        return "";
    const url = local.startsWith("file:") ? local : pathToFileUrl(local);
    try {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url, false);
        xhr.send();
        if (xhr.status === 200 || xhr.status === 0)
            return xhr.responseText || "";
    } catch (e) {
        console.log("launcherfromdrop: cannot read", url, e);
    }
    return "";
}

function desktopExists(path) {
    const text = readTextFile(path);
    return text.indexOf("[Desktop Entry]") >= 0 || text.indexOf("Exec=") >= 0 || text.indexOf("Type=") >= 0;
}

function parseDesktop(text) {
    const out = {};
    if (!text)
        return out;
    const lines = String(text).split(/\r?\n/);
    let inEntry = false;
    for (let i = 0; i < lines.length; ++i) {
        const raw = lines[i];
        const line = raw.trim();
        if (!line || line.startsWith("#"))
            continue;
        if (line.startsWith("[")) {
            inEntry = (line === "[Desktop Entry]");
            continue;
        }
        if (!inEntry)
            continue;
        const eq = line.indexOf("=");
        if (eq <= 0)
            continue;
        const key = line.slice(0, eq).trim();
        if (key.indexOf("[") >= 0)
            continue;
        if (out[key] === undefined)
            out[key] = line.slice(eq + 1);
    }
    return out;
}

function execBinary(execLine) {
    if (!execLine)
        return "";
    let s = String(execLine).replace(/%[fFuUdDnNickvm]/g, " ").trim();
    const parts = splitExec(s);
    if (parts.length === 0)
        return "";
    let i = 0;
    if (parts[0] === "env") {
        i = 1;
        while (i < parts.length && parts[i].indexOf("=") >= 0)
            ++i;
    }
    if (parts[i] === "flatpak") {
        const run = parts.indexOf("run");
        const start = run >= 0 ? run + 1 : i + 1;
        for (let j = start; j < parts.length; ++j) {
            if (parts[j].startsWith("-"))
                continue;
            return parts[j];
        }
    }
    return parts[i] || "";
}

function splitExec(s) {
    const out = [];
    let cur = "";
    let quote = "";
    for (let i = 0; i < s.length; ++i) {
        const ch = s[i];
        if (quote) {
            if (ch === quote)
                quote = "";
            else
                cur += ch;
            continue;
        }
        if (ch === "\"" || ch === "'") {
            quote = ch;
            continue;
        }
        if (ch === "\\" && i + 1 < s.length) {
            cur += s[++i];
            continue;
        }
        if (ch === " " || ch === "\t") {
            if (cur) {
                out.push(cur);
                cur = "";
            }
            continue;
        }
        cur += ch;
    }
    if (cur)
        out.push(cur);
    return out;
}

function joinPath(dir, name) {
    if (!dir)
        return name;
    return String(dir).replace(/\/+$/, "") + "/" + name;
}

function findDesktopInAppDirs(desktopId, ctx) {
    if (!desktopId)
        return "";
    const id = desktopId.endsWith(".desktop") ? desktopId : desktopId + ".desktop";
    const dirs = (ctx && ctx.appDirs) ? ctx.appDirs : [];
    for (let i = 0; i < dirs.length; ++i) {
        const dir = stripFilePrefix(dirs[i]);
        const path = joinPath(dir, id);
        if (desktopExists(path))
            return path;
    }
    return "";
}

function isInsideAppDir(path, ctx) {
    const local = stripFilePrefix(path);
    const dirs = (ctx && ctx.appDirs) ? ctx.appDirs : [];
    for (let i = 0; i < dirs.length; ++i) {
        const dir = stripFilePrefix(dirs[i]).replace(/\/+$/, "");
        if (local === joinPath(dir, basename(local)) && local.indexOf(dir + "/") === 0)
            return true;
    }
    return false;
}

function applicationsUrl(desktopId) {
    const id = String(desktopId || "");
    if (!id)
        return "";
    if (id.startsWith("applications:") || id.startsWith("preferred:") || id.startsWith("file:"))
        return id;
    return "applications:" + (id.endsWith(".desktop") ? id : id + ".desktop");
}

function fileUrlForApplications(launcherUrl, ctx) {
    const s = normalizeUrl(launcherUrl);
    if (!s.startsWith("applications:"))
        return "";
    const path = findDesktopInAppDirs(s.slice("applications:".length), ctx);
    return path ? pathToFileUrl(path) : "";
}

function desktopIdCandidates(entry, fileName) {
    const ids = [];
    function add(id) {
        if (!id)
            return;
        let s = String(id).trim();
        if (!s)
            return;
        if (!s.endsWith(".desktop"))
            s += ".desktop";
        if (ids.indexOf(s) < 0)
            ids.push(s);
    }
    add(entry["X-KDE-AliasFor"]);
    add(entry["X-Flatpak"]);
    add(fileName);
    const bin = basename(execBinary(entry["Exec"] || entry["TryExec"] || ""));
    if (bin) {
        add(bin);
        add(bin.replace(/-stable$/, ""));
        add(bin.replace(/-bin$/, ""));
        add("org.kde." + bin);
        add("org.gnome." + bin);
        add("org.mozilla." + bin);
        add("org.freedesktop." + bin);
    }
    const wm = entry["StartupWMClass"];
    if (wm)
        add(String(wm).toLowerCase());
    return ids;
}

function resolveDesktopFile(path, ctx) {
    const text = readTextFile(path);
    const entry = parseDesktop(text);
    const fileName = desktopFileName(path);

    const candidates = desktopIdCandidates(entry, fileName);
    for (let i = 0; i < candidates.length; ++i) {
        if (findDesktopInAppDirs(candidates[i], ctx))
            return applicationsUrl(candidates[i]);
    }

    if (isInsideAppDir(path, ctx) && fileName)
        return applicationsUrl(fileName);

    const type = String(entry["Type"] || "Application").toLowerCase();
    if (type === "link" && entry["URL"])
        return resolveOne(entry["URL"], ctx).launcher;

    // User-made shortcut (Wine, custom Exec) — pin the file itself.
    return pathToFileUrl(path);
}

function parseKeyValuesSection(text, section) {
    const map = {};
    if (!text)
        return map;
    const lines = String(text).split(/\r?\n/);
    let inSection = false;
    for (let i = 0; i < lines.length; ++i) {
        const line = lines[i].trim();
        if (!line || line.startsWith("#"))
            continue;
        if (line.startsWith("[")) {
            inSection = (line === "[" + section + "]");
            continue;
        }
        if (!inSection)
            continue;
        const eq = line.indexOf("=");
        if (eq <= 0)
            continue;
        const key = line.slice(0, eq).trim();
        const value = line.slice(eq + 1).trim();
        if (value && map[key] === undefined)
            map[key] = value;
    }
    return map;
}

function firstExistingDesktop(value, ctx) {
    if (!value)
        return "";
    const parts = String(value).split(";");
    let fallback = "";
    for (let i = 0; i < parts.length; ++i) {
        let id = parts[i].trim();
        if (!id)
            continue;
        if (!id.endsWith(".desktop"))
            id += ".desktop";
        if (!fallback)
            fallback = id;
        if (findDesktopInAppDirs(id, ctx))
            return id;
    }
    return fallback;
}

function collectMimeappsFiles(ctx) {
    // Later files override earlier ones. KDE lists win over generic, user over system.
    const files = [];
    const appDirs = (ctx && ctx.appDirs) ? ctx.appDirs : [];
    // appDirs is user-first; walk system → user so user wins
    for (let i = appDirs.length - 1; i >= 0; --i) {
        const dir = stripFilePrefix(appDirs[i]);
        files.push(joinPath(dir, "mimeapps.list"));
        files.push(joinPath(dir, "kde-mimeapps.list"));
    }
    files.push("/etc/xdg/mimeapps.list");
    files.push("/etc/xdg/kde-mimeapps.list");
    const configDir = stripFilePrefix((ctx && ctx.configDir) || "");
    if (configDir) {
        files.push(joinPath(configDir, "mimeapps.list"));
        files.push(joinPath(configDir, "kde-mimeapps.list"));
    }
    return files;
}

function mergeMimeMap(target, incoming) {
    for (const key in incoming) {
        if (incoming[key])
            target[key] = incoming[key];
    }
}

function ensureCaches(ctx) {
    if (_defaults && _globs)
        return;
    _defaults = {};
    _globs = [];

    const dataDirs = (ctx && ctx.dataDirs) ? ctx.dataDirs : [];
    for (let i = dataDirs.length - 1; i >= 0; --i) {
        const dir = stripFilePrefix(dataDirs[i]);
        loadGlobs(joinPath(dir, "mime/globs2"));
        loadGlobs(joinPath(dir, "mime/globs"));
    }

    const appDirs = (ctx && ctx.appDirs) ? ctx.appDirs : [];
    for (let i = appDirs.length - 1; i >= 0; --i) {
        const cache = parseKeyValuesSection(readTextFile(joinPath(stripFilePrefix(appDirs[i]), "mimeinfo.cache")), "MIME Cache");
        mergeMimeMap(_defaults, cache);
    }

    const mimeappsFiles = collectMimeappsFiles(ctx);
    for (let i = 0; i < mimeappsFiles.length; ++i) {
        const text = readTextFile(mimeappsFiles[i]);
        if (!text)
            continue;
        mergeMimeMap(_defaults, parseKeyValuesSection(text, "Added Associations"));
        mergeMimeMap(_defaults, parseKeyValuesSection(text, "Default Applications"));
    }
}

function loadGlobs(path) {
    const text = readTextFile(path);
    if (!text)
        return;
    const lines = String(text).split(/\r?\n/);
    const isGlobs2 = path.endsWith("globs2");
    for (let i = 0; i < lines.length; ++i) {
        const line = lines[i].trim();
        if (!line || line.startsWith("#"))
            continue;
        let weight = 50;
        let mime = "";
        let glob = "";
        if (isGlobs2) {
            const first = line.indexOf(":");
            const second = first >= 0 ? line.indexOf(":", first + 1) : -1;
            if (second < 0)
                continue;
            weight = parseInt(line.slice(0, first), 10) || 50;
            mime = line.slice(first + 1, second);
            glob = line.slice(second + 1);
        } else {
            const colon = line.indexOf(":");
            if (colon < 0)
                continue;
            mime = line.slice(0, colon);
            glob = line.slice(colon + 1);
        }
        if (!mime || !glob)
            continue;
        _globs.push({
            weight: weight,
            mime: mime,
            glob: glob,
            globLower: glob.toLowerCase(),
        });
    }
}

function matchGlob(name, globLower) {
    const file = name.toLowerCase();
    if (globLower.startsWith("*.")) {
        const suffix = globLower.slice(1); // ".html" or ".tar.gz"
        return file.endsWith(suffix);
    }
    if (globLower.indexOf("*") < 0 && globLower.indexOf("?") < 0 && globLower.indexOf("[") < 0)
        return file === globLower;
    return false;
}

function mimeForFileName(name) {
    if (!_globs)
        return "";
    let best = null;
    for (let i = 0; i < _globs.length; ++i) {
        const g = _globs[i];
        if (!matchGlob(name, g.globLower))
            continue;
        if (!best
            || g.weight > best.weight
            || (g.weight === best.weight && g.glob.length > best.glob.length)) {
            best = g;
        }
    }
    return best ? best.mime : "";
}

function defaultDesktopForMime(mime, ctx) {
    if (!mime || !_defaults)
        return "";
    return firstExistingDesktop(_defaults[mime] || "", ctx);
}

function schemeOf(url) {
    const s = normalizeUrl(url);
    const i = s.indexOf(":");
    if (i <= 0)
        return "";
    return s.slice(0, i).toLowerCase();
}

function resolveOne(url, ctx) {
    const s = normalizeUrl(url);
    const result = { launcher: "", needsProbe: "" };

    if (!s)
        return result;

    if (s.startsWith("applications:") || s.startsWith("preferred:")) {
        result.launcher = s;
        return result;
    }

    const local = toLocalPath(s);
    const desk = desktopFileName(s);
    if (desk) {
        if (local)
            result.launcher = resolveDesktopFile(local, ctx);
        else
            result.launcher = applicationsUrl(desk);
        return result;
    }

    ensureCaches(ctx);

    const scheme = schemeOf(s);
    if (scheme && scheme !== "file") {
        const desktop = defaultDesktopForMime("x-scheme-handler/" + scheme, ctx);
        if (desktop)
            result.launcher = applicationsUrl(desktop);
        return result;
    }

    if (!local)
        return result;

    const mime = mimeForFileName(basename(local));
    const desktop = mime ? defaultDesktopForMime(mime, ctx) : "";
    if (desktop) {
        result.launcher = applicationsUrl(desktop);
        return result;
    }

    result.needsProbe = local;
    return result;
}

function resolveUrls(urls, ctx) {
    const launchers = [];
    const needsProbe = [];
    const seen = {};

    function addLauncher(u) {
        if (!u || seen[u])
            return;
        seen[u] = true;
        launchers.push(u);
    }

    const list = urls || [];
    for (let i = 0; i < list.length; ++i) {
        const one = resolveOne(list[i], ctx);
        if (one.launcher)
            addLauncher(one.launcher);
        else if (one.needsProbe && needsProbe.indexOf(one.needsProbe) < 0)
            needsProbe.push(one.needsProbe);
    }
    return { launchers: launchers, needsProbe: needsProbe };
}

function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}
