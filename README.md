# Icons-Only Task Manager 2

macOS-like icon dock for Plasma 6: zoom on hover, parabolic rise, pin launchers.

https://store.kde.org/p/2352806/

## 1.3

- Works on Plasma 6.7 / CachyOS / Arch **without** the Fedora `arch-patch` binary.
  The widget no longer imports `org.kde.plasma.private.taskmanager`.
- Drop a `.desktop` onto the dock to pin that app.
- Drop a regular file onto the empty strip after the last icon to pin the
  default application for that file type.
- Drop a file onto an existing icon to open it with that app.
- Drop highlight no longer clips against the panel.

Context menu no longer has Jump Lists / Recent Files / Places (those needed
the private C++ plugin). Mute, MPRIS, pin/unpin, desktops still work.

## Building

The optional C++ plugin in `dockregion` is for pairing the dock with a
compositor effect such as KDE-Blur. With `Keep the panel background and shadow`
unticked, it masks the panel to the dock's region and hides Plasma's own
background, so the effect can draw the dock's background instead. Without the
plugin, the dock uses the regular panel background. Installing the plugin also
installs the plasmoid.

    cmake -B dockregion/build -S dockregion -DCMAKE_INSTALL_PREFIX=/usr
    cmake --build dockregion/build
    sudo cmake --install dockregion/build
    systemctl --user restart plasma-plasmashell
