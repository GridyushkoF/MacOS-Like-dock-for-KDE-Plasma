# Patch for Arch-based Systems (CachyOS, EndeavourOS, Manjaro)

## Problem

In Plasma 6.6.3+ on Arch-based systems, the QML module `org.kde.plasma.private.taskmanager` is missing, which is required for the Icons-Only Task Manager 2 widget to work.

Error:
```
module "org.kde.plasma.private.taskmanager" is not installed
```

## Solution

This patch installs the missing module.

### Installation

```bash
cd arch-patch
sudo ./install-taskmanager-module.sh
```

After installation, restart Plasma:
```bash
kquitapp6 plasmashell && kstart plasmashell
```

### Uninstallation

```bash
sudo ./uninstall-taskmanager-module.sh
```

## Important

- Module files are taken from Fedora with Plasma 6.6.1
- If the widget still doesn't work or crashes, the library may be incompatible with your KDE/Qt version
- In that case, you need to either rebuild plasma-desktop from source or wait for a fix from KDE/Arch developers

## Alternative Solutions

1. **Bug report to Arch**: Report the issue at bugs.archlinux.org
2. **Bug report to KDE**: Report at bugs.kde.org
3. **Build plasma-desktop from AUR**: `yay -S plasma-desktop-git`

## Module Contents

- `libtaskmanagerplugin.so` - native plugin
- `qmldir` - module description
- `taskmanagerplugin.qmltypes` - QML types
- `kde-qmlmodule.version` - module version
