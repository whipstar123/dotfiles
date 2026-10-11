# Omarchy Shell Standalone

A stripped-down, distro-agnostic desktop shell extracted from
[Omarchy](https://github.com/omacom/omarchy) (Quattro): the Quickshell shell,
Catppuccin theme system, and Hyprland layer — without the OS.

- **Browser:** Helium · **Terminal:** Kitty · **Editor:** Zed
- **Theme:** Catppuccin (more via `omarchy-theme-install <git-url>`)
- **Login:** Ly → `start-hyprland` · **Shell:** Fish · **AUR:** paru
- No AI, no Windows VM, no gaming/services/dev preinstalls, no SDDM,
  no bootloader or filesystem provisioning (your btrfs + limine stay untouched).

## Install (from a TTY on any Arch-based system)

```bash
sudo ./install.sh
# reboot, pick "Omarchy Standalone" in Ly, log in
```

See [RUNBOOK.md](RUNBOOK.md) for transfer, first checks, troubleshooting,
and rollback. See [docs/PLAN.md](docs/PLAN.md) for the full build plan.

## Layout

| Path | Installed to | Purpose |
|---|---|---|
| `bin/` | `/usr/share/omarchy-standalone/bin` (`OMARCHY_PATH`) | 202 reachability-audited helpers, invoked directly (no `omarchy` router) |
| `shell/` | `$OMARCHY_PATH/shell` | Quickshell desktop (bar, menu, notifications, OSD, lock, polkit) |
| `themes/catppuccin/` | `$OMARCHY_PATH/themes/` | Bundled theme (`colors.toml` + backgrounds) |
| `default/` | `$OMARCHY_PATH/default` | Slim menu base, Hyprland defaults, Kitty/Hyprland/shell templates |
| `config/` | `~/.config/` (backed up first) | Hyprland user config, `shell.json` (no AI widgets) |
| `extras/` | system + home | Ly session entry, Fish `conf.d` env |
| `install.sh` | — | TTY bootstrap: packages → paru → Helium → tree → configs → theme → Ly |

## Notes

- Third-party shell plugins work: `omarchy-plugin-add <git-url>`
  (they land in `~/.config/omarchy/plugins/`). Plugins assuming the full
  Omarchy OS may degrade — see docs/PLAN.md §1.
- Extra themes work: `omarchy-theme-install <git-url>` (see
  https://omarchy.org/themes/). Downloaded themes recolor Kitty, Hyprland,
  and the shell through their `colors.toml`.
- AppImages never appear in Apps search on their own — run
  `omarchy-appimage-install <file.AppImage>` to register one.
- Origin: frozen Quattro snapshot, trimmed per docs/PLAN.md. Shell and theme
  systems retain the upstream MIT license (see LICENSE).
