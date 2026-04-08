Download plasmoid on https://store.kde.org/p/2352806!

## Arch-based Systems (CachyOS, EndeavourOS, Manjaro)

If you get the error:
```
module "org.kde.plasma.private.taskmanager" is not installed
```

Check the `arch-patch` folder for the fix. Run:
```bash
cd arch-patch
sudo ./install-taskmanager-module.sh
kquitapp6 plasmashell && kstart plasmashell
```

## Debian-based Systems (Debian, Ubuntu, Kali, Deepin, Elementary, Mint etc. )

If you get the error:
```
module "org.kde.plasma.private.taskmanager" is not installed
```

Check the `arch-patch` folder for the fix. Run:
```bash
cd arch-patch
sudo ./install-taskmanager-module_deb.sh
killall plasmashell && kstart plasmashell
```
