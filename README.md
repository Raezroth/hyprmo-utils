# sxmo-utils-hyprland
---

## Setup

This is a WIP and is recommended for experienced user. 

It is also being developed on Arch Linux Arm, for the PinePhone Pro.

### Install

Install hyprland and other recommended packages: `doas pacman -S hyprland hyprpaper kitty wofi waybar xdg-desktop-portal-hyprland`

Compile [sxmo-utils-hyprland](https://github.com/Raezroth/Pine64-Arch/tree/master/PKGBUILDS/sxmo/sxmo-utils-hyprland) with `makepkg`

```
git clone https://github.com/Raezroth/Pine64-Arch.git $HOME/Pine64-Arch-Fork
cd $HOME/Pine64-Arch-Fork/PKGBUILDS/sxmo/sxmo-utils-hyprland
makepkg --syncdeps -i
```

If it fails to install run `sudo pacman -U ./sxmo-utils-1.15.2-1-aarch64.pkg.tar.xz ./sxmo-utils-hyprland-1.15.2-1-any.pkg.tar.xz --overwrite='*'`

## Make sure to run `sxmo_migrate.sh` to update & resolve configuration conflicts

---

### Tasks
- [x] Initial Hyprland startup
- [X] WVKBD for non-pinephone keyboard users
- [X] PinePhone Keyboard configuration in hyprland.conf
- [ ] Gesture support (Currently Working: brightness, volume, keyboard toggle)
- [ ] Volume Rockers Configured
- [ ] Power Button Configured

Feel free to add to the list.

---

This repository contains scripts and C programs to support Sxmo.

Note all scripts pass shellcheck and are tab-idented.

    <Various scripts and small C programs that glue the Sxmo environment together>
    Copyright (C) <2022>  <Sxmo Contributors>
    Copyright (C) <2024>  <Hyprmo Contributors>
    
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, version 3 of the License only.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.

