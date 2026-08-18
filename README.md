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
