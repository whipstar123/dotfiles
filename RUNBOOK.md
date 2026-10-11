# Omarchy Shell Standalone — TTY Runbook

Target: any Arch-based system at a TTY prompt (btrfs + limine stay untouched).
You need: a sudo-capable user, network access, this directory on the machine.

## 1. Transfer

USB stick, `scp -r standalone-src <user>@<host>:~/`, or from the repo checkout:

```bash
tar -czf omarchy-standalone.tar.gz standalone-src
# on target:
tar -xzf omarchy-standalone.tar.gz && cd standalone-src
```

## 2. Run

```bash
sudo ./install.sh
```

Order inside: preflight → pacman set (~1GB, takes a while) → paru bootstrap
(skipped if paru exists) → Helium → copy to `/usr/share/omarchy-standalone`
→ user configs (existing files → `*.bak.<timestamp>`) → Ly session →
Catppuccin apply → Ly on tty2 (getty there disabled). Then `reboot`, pick
`Omarchy Standalone` in Ly, log in.

## 3. First checks (in the session, Fish or Kitty)

```bash
echo $OMARCHY_PATH            # /usr/share/omarchy-standalone
which omarchy-shell           # $OMARCHY_PATH/bin/omarchy-shell
omarchy-default-terminal      # kitty
omarchy-default-editor        # zeditor
omarchy-default-browser       # helium
omarchy-theme-set "Catppuccin"  # recolors Kitty + Hyprland + shell
journalctl -t omarchy-shell --since "10 min ago"  # no agents errors
```

Menu search must show ZERO rows for: ai, windows, spotify, steam, docker,
chromium, nvim, foot, tailscale. Apps must show Helium, Kitty, Zed.

## 4. Known verify-on-install items

- **Helium `.desktop` id:** installer assumes `helium.desktop`. If
  `omarchy-default-browser` reports something else, check
  `ls /usr/share/applications ~/.local/share/applications | grep -i helium`
  and patch `bin/omarchy-default-browser` (getter + setter lines), reinstall.
- **Zed binary:** `default-editor` expects `zeditor`. If `which zeditor` fails but
  `zed` exists, `sudo ln -s $(which zed) /usr/local/bin/zeditor`.
- **Ly session missing:** confirm
  `/usr/share/wayland-sessions/omarchy-standalone.desktop` exists and
  `systemctl is-enabled ly` prints `enabled`.
- **No bar:** `journalctl -t omarchy-shell` tells why; most likely
  `OMARCHY_PATH` unset in the session — check `hyprctl getoption` env or
  `~/.config/hypr/autostart.lua` contains the `omarchy-launch-shell` line.
- **Theme errors about jq/flock:** both ship with the pacman set (`jq`,
  `util-linux`). Re-run `omarchy-theme-set "Catppuccin"` after install finishes.

## 5. Rollback

User configs were backed up as `*.bak.<timestamp>` next to the originals
(`~/.config/hypr/`, `~/.config/omarchy/shell.json`). System tree removes with
`sudo rm -rf /usr/share/omarchy-standalone`; session entry with
`sudo rm /usr/share/wayland-sessions/omarchy-standalone.desktop`.
Packages are stock Arch packages — remove with `pacman -Rns` if desired.
