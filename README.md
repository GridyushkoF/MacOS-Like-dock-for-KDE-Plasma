# Icons-Only Task Manager 2

macOS-like icon dock for Plasma 6: zoom on hover, parabolic rise, pin launchers.

https://store.kde.org/p/2352806/

## 1.5.0

- Hover magnification follows the pointer directly. Only the icon under
  the cursor and its two neighbours change; the rest of the row stays put.
- Those neighbours can nudge aside. Turn this off under Appearance,
  Dock growth, to zoom in place as in 1.4.1. The panel keeps its length.
- Animation duration is how fast the effect appears and disappears.
  Tracking the pointer does not wait on it.
- The running-window and group dots track the icon center.
- Optional `dockregion` plugin masks the panel to the dock shape when
  "Keep the panel background and shadow" is off. See Building.

## 1.4.1

- Magic Lamp follows the painted icon, including on a scaled screen.
- Clicking a dock icon still launches or minimizes if icon geometry cannot be published.

## 1.4

- Magic Lamp and the normal minimize animation target the dock icon.
  The dock publishes each icon's screen rectangle to KWin.
- Meta+1 through Meta+9 activates the matching dock entry (launch, focus,
  or minimize), same as the standard task manager. If the default
  Icons-Only Task Manager is still on the panel, Plasma gives the
  shortcut to that one.

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

## Contributors

- [PKMNPlatin](https://github.com/PKMNPlatin) — growing dock and the optional
  `dockregion` plugin.
