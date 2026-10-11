# Install Manifest — everything `install.sh` puts on the machine

Generated from `install.sh` + the shipped tree. No bootloader, filesystem,
or partition changes — btrfs + limine are never touched.

## 1. Official-repo packages (`sudo pacman -S --needed`)

| Package | Why |
|---|---|
| `base-devel`, `git` | AUR builds (paru bootstrap) |
| `fish` | Kept user shell |
| `ly` | Login manager (enabled, §4) |
| `hyprland` | Compositor (`start-hyprland` via Ly session) |
| `xdg-desktop-portal-hyprland`, `xdg-desktop-portal-gtk` | Screenshare, file picker, settings portals |
| `xdg-terminal-exec` | Terminal dispatch used by menu Update/Install rows |
| `qt6-base`, `qt6-declarative`, `qt6-wayland`, `qt6-svg`, `qt6-multimedia` | Quickshell runtime |
| `quickshell` | The `omarchy-shell` process itself |
| `kitty` | Default terminal |
| `zed` | Default editor (`zeditor`) |
| `jq`, `socat` | Menu/plugin/theme script plumbing, shell IPC |
| `wl-clipboard`, `grim`, `slurp` | Clipboard, screenshot region select |
| `hyprsunset`, `hyprpicker` | Night light service, color picker |
| `polkit` | Privilege auth backend (in-shell polkit agent) |
| `pipewire`, `wireplumber`, `pipewire-pulse`, `pipewire-alsa` | Audio stack |
| `networkmanager`, `bluez` | Network + Bluetooth bar widgets |
| `pamixer`, `brightnessctl`, `power-profiles-daemon` | Audio/brightness/power controls |
| `nautilus`, `sushi` | File manager + preview |
| `imv`, `mpv`, `evince` | Image viewer, video player, PDF reader |
| `btop`, `fastfetch` | System monitor, about screen |
| `gum` | All picker TUIs (package add/remove, theme/plugin prompts) |
| `gpu-screen-recorder` | Screen recording backend for Capture |
| `tesseract`, `tesseract-data-eng` | OCR backend for Extract-text keybind |
| `ttf-cascadia-mono-nerd`, `ttf-jetbrains-mono-nerd`, `noto-fonts`, `noto-fonts-emoji`, `woff2-font-awesome` | Terminal, UI, icon-glyph coverage |

## 2. AUR packages (`paru -S`; `paru-bin` bootstrapped via `makepkg` if absent)

| Package | Why |
|---|---|
| `helium-browser-bin` | Default + only browser |
| `omasnap-bin` (provides `omasnap`) | Screenshot engine behind Screenshot/Capture/Share |
| `cliamp` | Kept terminal music player (`Super+Shift+Alt+M`) |

## 3. System tree (`/usr/share/omarchy-standalone`, root-owned, `a+rX`)

`shell/` (Quickshell desktop minus `agents`/`dev-gallery` plugins,
`remote-session` service, `elsewhen` bar widget, and `speedtest`/
`disk-speedtest` panels; network-panel speed test neutered via
`canRunSpeedTest: false`), `bin/` (201 helpers — reachability-audited, no `omarchy` router:
every binary is called from the slim menu, shell QML, Hyprland bindings,
installer, or another kept helper; constructed names like `omarchy-launch-*`
and `omarchy-toggle-*` counted),
`themes/catppuccin/`, `default/{hypr,themed/×3,omarchy/slim-menu}`,
`config/` (source of user configs), `extras/` (Ly session, Fish env).

## 4. System service

- `systemctl enable ly` (only service change).

## 5. Per-user writes (existing files moved to `*.bak.<timestamp>` first)

- `~/.config/hypr/{hyprland,bindings,monitors,input,looknfeel,autostart}.lua`
  + `o.launch_on_start("omarchy-launch-shell")` appended to `autostart.lua`
- `~/.config/omarchy/shell.json` (minimal bar, no AI widgets)
- `~/.config/fish/conf.d/omarchy-standalone.fish`
  (`OMARCHY_PATH`, `PATH`, `EDITOR`)
- `~/.local/state/omarchy/defaults/{editor=zeditor,terminal=kitty}`
- `~/.config/xdg-terminals.list` (`kitty.desktop`)
- `~/.local/state/omarchy/preinstalls-removed` (disables removed-app keybind block)
- Default browser → `helium.desktop` (warns, doesn't fail, if unsettable)
- `/usr/share/wayland-sessions/omarchy-standalone.desktop` (Ly entry)
- `~/Applications/` created (AppImage home for `omarchy-appimage-install`)

## 6. Theme state (written by `omarchy-theme-set "Catppuccin"`)

`~/.local/state/omarchy/current/{theme,theme.name,next-theme}` —
rendered `kitty.conf`, `hyprland.lua`, `shell.toml` from Catppuccin
`colors.toml`; post-step reloads Kitty (`SIGUSR1`); Hyprland picks up its
config on next reload/login.
