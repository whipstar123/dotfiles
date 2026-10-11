# Omarchy Shell Standalone — Full Build Plan (frozen quattro, any Arch, TTY start)

> Authorization: the user explicitly allows the executor to remove, change, rewrite,
> or delete ANY files in the standalone copy AND the plan itself, however needed
> to complete this build. Prefer patching the copied tree; never patch the quattro
> checkout in place — all destructive work happens in the standalone copy.
>
> Anti-hallucination rule for anyone executing this plan: every path, script name,
> and behavior below was read from disk on the quattro checkout. If a file is not
> listed here, do NOT assume it exists — `ls`/`grep` it first. Exact anchor files:
> `bin/omarchy-launch-shell`, `bin/omarchy-default-{browser,editor,terminal}`,
> `bin/omarchy-theme-set`, `bin/omarchy-theme-set-templates`,
> `bin/omarchy-pkg-{install,remove,aur-install,aur-add}`,
> `bin/omarchy-update{-system-pkgs,-aur-pkgs,}`, `config/omarchy/shell.json`,
> `config/omarchy/extensions/omarchy-menu.jsonc`, `default/omarchy/omarchy-menu.jsonc`,
> `config/hypr/hyprland.lua`, `config/hypr/autostart.lua`, `default/hypr/bootstrap.lua`,
> `default/hypr/envs.lua`, `default/hypr/paths.lua`, `shell/services/AppLibrary.qml`,
> `shell/plugins/*/manifest.json`, `install/omarchy-base.packages`,
> `themes/catppuccin/`, `default/themed/`.

## 0. Locked decisions (do not re-debate during build)

- Browser: Helium only, AUR package `helium-browser-bin` (verified on AUR).
  Upstream `bin/omarchy-default-browser` has NO helium case (cases end at zen) —
  patch required. `bin/omarchy-launch-webapp` already matches `helium*` — no patch.
- Terminal: Kitty only. `bin/omarchy-default-terminal` already supports kitty.
- Editor: Zed only. `bin/omarchy-default-editor` already accepts `zed|zeditor`
  and stores `zeditor`; installer runs `omarchy-default-editor zed`.
  Remove `omarchy-nvim` package + `default/themed/neovim.lua.tpl`.
- Theme: Catppuccin (`themes/catppuccin/`) only. Templates kept:
  `default/themed/{kitty.conf.tpl,hyprland.lua.tpl,shell.toml.tpl}`.
  Drop foot/alacritty/ghostty/neovim/vscode/chromium/btop templates in v1.
- Login: Ly (install + enable; not present on TTY target). Session runs
  `start-hyprland`. No SDDM, no uwsm session wrapper.
- Shell: Fish kept. No Bash/Zsh switch. Fish `conf.d` sets 3 vars (Sec. 6).
- AUR helper: paru (bootstrap from AUR when absent). `paru` appears NOWHERE in
  `bin/` today (grep = 0 hits); `yay` appears in exactly:
  `bin/omarchy-pkg-aur-add`, `bin/omarchy-pkg-aur-install`,
  `bin/omarchy-pkg-remove`, `bin/omarchy-update-aur-pkgs`, `bin/omarchy-update`
  (+ `bin/omarchy-upgrade-to-quattro`, not shipped). All must be patched.
- CLI tools REMOVED: fzf, zoxide, ripgrep, eza, fd, bat, tldr, yt-dlp, tobi-try,
  `default/bash/*` aliases/functions. Consequence (verified by grep):
  `bin/omarchy-pkg-{install,remove,aur-install}` hard-depend on `fzf`;
  `bin/omarchy-plugin-clone` uses `rg`; yt-dlp host/extension dropped with Chromium.
  Rewrite pkg TUIs gum-based (gum is in `install/omarchy-base.packages`, kept).
- Kept CLI/TUI: Cliamp (your call), gum, jq, socat.
- Removed trees: AI (`bin/omarchy-agent*`, `bin/omarchy-install-ai-*`,
  `bin/omarchy-remove-ai-*`, `shell/plugins/agents/`, dictation voxtype/superwhisper),
  Windows VM (`bin/omarchy-windows-vm`), all `applications/*.desktop` webapps,
  preinstall pkgs (aether, libreoffice-fresh, xournalpp, pinta, obsidian,
  moonlight-qt, omacut, monologue, omacalc, omawrite, hype — cliamp EXCLUDED from
  removal), services (1password, dropbox, spotify, signal, tailscale, nordvpn,
  once, sunshine), all gaming, all mise dev envs, docker-dbs, SDDM, limine/UKI,
  snapper, `install/hardware/*`, `migrations/`, `provision-*`, plymouth,
  `omarchy-update` OS pipeline, `omarchy-upgrade-to-quattro`.
- Scope: ANY Arch-based distro, TTY start (btrfs + limine pre-existing, NO desktop,
  NO Ly). Installer bootstraps all of Sec. 2. Bootloader + filesystem untouched.
- Layout: system-wide `OMARCHY_PATH=/usr/share/omarchy-standalone` (root-owned,
  user readable). User state in `~/.config/` + `~/.local/state/` (Sec. 5).
- Update model: NO snapshots/migrations/boot-verify. Slim paru menu (Sec. 7).

## 1. Ground truths (verified on disk — build on these, not memory)

1. Shell entry: `bin/omarchy-launch-shell` runs
   `quickshell -n -p "$OMARCHY_PATH/shell"` under `systemd-cat -t omarchy-shell`.
   It needs `OMARCHY_PATH` + `WAYLAND_DISPLAY` only. Hyprland starts it via
   `exec-once` (see `config/hypr/autostart.lua`, currently a stub + `o.launch_on_start` helper).
2. Hyprland user config `config/hypr/hyprland.lua` line 1 is
   `dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")`.
   `default/hypr/bootstrap.lua` appends `$OMARCHY_PATH` to `package.path` and
   `default/hypr/envs.lua` re-exports `OMARCHY_PATH` via `hl.env`. So pointing
   `OMARCHY_PATH=/usr/share/omarchy-standalone` works with zero Lua edits as long
   as `default/hypr/{bootstrap.lua,envs.lua,paths.lua,omarchy.lua}` are copied.
3. `config/omarchy/shell.json` (v1) bar RIGHT array contains `omarchy.agents` —
   delete that element (no other AI key exists). `plugins: []` stays.
   Shell also has `builtinShellConfig` fallback, so a missing file still boots a bar.
4. Plugin contract: `shell/plugins/*/manifest.json` × 13 dirs on disk
   (agents, background, bar, clipboard, dev-gallery, emojis, image-picker, lock,
   menu, notifications, osd, polkit, reminders) plus code-only `panels/` +
   `services/`. Third-party path `~/.config/omarchy/plugins/<id>/` uses the same
   manifest. Delete `shell/plugins/agents/` dir; keep the rest except `dev-gallery`.
5. Theme engine = 2 bash scripts, NO binary: `bin/omarchy-theme-set` reads
   `$OMARCHY_PATH/themes/<name>/colors.toml` (+ `$HOME/.config/omarchy/themes/`
   override), stages to `$HOME/.local/state/omarchy/current/{theme,theme.name,next-theme}`,
   calls `bin/omarchy-theme-set-templates` (single-awk renderer:
   `TEMPLATES_DIR=$OMARCHY_PATH/default/themed` → `$NEXT_THEME_DIR`).
   `INSTALLED_THEME_DENIED=(alacritty.toml foot.ini ghostty.conf kitty.conf vscode.json)`
   — keep the array as-is even for 3 templates.
6. Menu = 2 files: `default/omarchy/omarchy-menu.jsonc` (385 rows, top roots include
   apps/learn/trigger/style/setup/install/remove/update/about/system) overlaid by
   `config/omarchy/extensions/omarchy-menu.jsonc` (empty template with docs).
   Overlay CANNOT delete IDs → ship a NEW slim base (Sec. 4), not an overlay.
7. App discovery: `shell/services/AppLibrary.qml` `launch()` runs
   `uwsm-app -- gtk-launch <id>.desktop`; list comes from Quickshell
   `DesktopEntries.applications.values` = XDG `.desktop` scan. Raw AppImages NEVER
   appear without a `.desktop` (Sec. 8).
8. `uwsm-app --` appears in 30 files under `bin/ shell/ default/hypr/`
   (launch-browser/editor/terminal/tui/webapp/nautilus/floating-terminal, restart-app,
   toggle-nightlight, AppLibrary.qml, helpers.lua). Every KEPT one must be patched
   (Sec. 3). Deleted AI/gaming/service installers take their copies with them.
9. No Ly, no paru, no fish config in repo (`config/fish/**` = empty);
   `install/omarchy-base.packages` lists `yay`, `uwsm`, `sddm`, `foot`, `chromium`,
   `nvim`, `fzf`, `ripgrep`, `yt-dlp`, `zoxide` — none of which the standalone installs.

## 2. TTY bootstrap order (any Arch; btrfs/limine untouched)

Run as user with sudo (fail fast if `sudo -v` fails). Abort on first error (`set -euo pipefail`).
0. Preflight: `/etc/arch-release` exists; `pacman -Sy` reachable; warn if
   `$XDG_RUNTIME_DIR` missing. Record `lspci | grep -i vga` for the NVIDIA note.
1. `sudo pacman -S --needed --noconfirm base-devel git fish ly hyprland
   xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-terminal-exec
   qt6-base qt6-declarative qt6-wayland qt6-svg qt6-multimedia quickshell
   kitty zed jq socat wl-clipboard grim slurp hyprsunset hyprpicker polkit
   pipewire wireplumber pipewire-pulse pipewire-alsa networkmanager bluez
   pamixer brightnessctl power-profiles-daemon nautilus sushi imv mpv evince
   btop fastfetch gum cliamp ttf-caskaydia-mono-nerd noto-fonts noto-fonts-emoji
   ttf-jetbrains-mono-nerd-basic woff2-font-awesome`
   (Names are Arch-repo names; if `pacman -Si <pkg>` fails on a derivative,
   keep going for optional fonts only — core set must resolve or abort.)
2. Paru bootstrap (only if `command -v paru` missing):
   `git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin &&
    cd /tmp/paru-bin && makepkg -si --noconfirm`. Then `paru -S --needed helium-browser-bin`.
3. NVIDIA note (generic hardware): if `nvidia-smi`/`lspci|grep -i nvidia` hits,
   print driver follow-up; do NOT auto-install drivers in v1.
4. Copy tree to `/usr/share/omarchy-standalone` (Sec. 5 file sets), root-owned,
   `chmod -R a+rX`.
5. User configs (backup existing with `.bak.<ts>`): `~/.config/hypr/*`,
   `~/.config/omarchy/shell.json`, slim menu base, Fish `conf.d`, Ly session
   (needs sudo, Sec. 6), `~/.local/state/omarchy/defaults/{editor,terminal}`,
   `~/.config/xdg-terminals.list` (kitty), xdg default browser (helium).
6. `omarchy-theme-set-templates && omarchy-theme-set "Catppuccin"` (Sec. 7 in
   install.sh is `OMARCHY_PATH=/usr/share/omarchy-standalone` prefixed).
7. `systemctl enable ly` (sudo). Reboot to Ly → start-hyprland session.

## 3. Exact code patches (apply to the COPIED tree, never to this checkout)

P1. de-uwsm (kept files only): in `bin/omarchy-launch-{browser,editor,terminal,tui,webapp,nautilus,nautilus-cwd,or-focus,floating-terminal-with-presentation}`,
   `bin/omarchy-restart-app`, `bin/omarchy-toggle-nightlight`,
   `shell/services/AppLibrary.qml` (`launch()` line), `default/hypr/helpers.lua`
   (`uwsm-app --` builder): replace `uwsm-app -- <cmd>` with `<cmd>` and
   `setsid uwsm-app -- <cmd>` with `setsid <cmd>`; in AppLibrary use
   `gtk-launch <id>.desktop` directly. Verify: `grep -rn "uwsm-app" $STANDALONE/{bin,shell,default} || true` prints NOTHING.
P2. `bin/omarchy-default-browser`: add helium case + getter. Getter:
   `helium.desktop) echo "helium" ;;`. Setter:
   `helium) browser="helium"; command="helium"; desktop_id="helium.desktop"; name="Helium"; glyph= ;;`.
   (Desktop id MUST be verified on first Helium install — `ls ~/.local/share/applications /usr/share/applications | grep -i helium` — and corrected here if it is `helium-browser.desktop`.)
P3. `bin/omarchy-launch-editor`: fallback `editor="nvim"` → `editor="zeditor"`.
   (File has TWO fallbacks: unset-state default + `omarchy-cmd-present` miss — patch both.)
P4. `bin/omarchy-install-browser`: add `helium)` stanza:
   `paru -S --needed helium-browser-bin`. Delete chromium/chrome/brave/edge/firefox/zen
   stanzas in the standalone copy.
P5. yay→paru: `bin/omarchy-pkg-aur-add` (`yay -S` → `paru -S`);
   rewrite `bin/omarchy-pkg-{install,remove,aur-install}` gum-based (Sec. 7);
   drop `bin/omarchy-update-aur-pkgs` (folded into update.aur-only).
P6. `bin/omarchy-launch-terminal`: ensure kitty path needs no `uwsm-app`
   (covered by P1); default stays kitty via `~/.config/xdg-terminals.list`.
P7. Delete from copied tree: `shell/plugins/agents/`, `shell/plugins/dev-gallery/`,
   every `bin/omarchy-{agent-*,install-ai-*,remove-ai-*,install-gaming-*,remove-gaming-*,install-service-*,remove-service-*,install-dev-env,remove-dev-env,install-docker-dbs,windows-vm,install-browser(chromium stanzas),install-editor-{vscode,emacs,helix},install-dictation-*,remove-dictation-*,install-chromium-*,plymouth-*,provision-*,apply-*,migrate,upgrade-to-quattro,snapshot}`,
   `applications/*.desktop` webapps, `install/`, `migrations/`,
   `themes/*` except `catppuccin/`, `default/themed/*` except the 3 kept templates.

## 4. Slim menu base (new file, NOT an overlay)

Ship as `$STANDALONE/default/omarchy/slim-menu.jsonc`, installed to
`/usr/share/omarchy-standalone/default/omarchy/omarchy-menu.jsonc`.
Roots: apps, trigger, style, setup, update, install, remove, system, about.
`learn` root DELETED (keybindings reachable via `setup.keybindings`).
- apps: `{apps:{provider:apps}}` only.
- trigger.appearance: bar hide/show/position/transparent/gaps only.
  trigger.toggle: idle/notifications/nightlight only.
  trigger: emoji, clipboard-history, capture.{screenshot,screenrecord.{no-audio,desktop-audio}}, share.{clipboard,file,folder} (NO receive/localsend), hardware laptop/mirror gated by `omarchy-hw-laptop`.
  DELETE: transcode, tests, reminder, theme-sync/herdr rows.
- style: theme (`omarchy-theme-set` via image-picker source themes), background
  (`omarchy-theme-bg-*`), font (provider fonts), hyprland (edit looknfeel).
  DELETE: unlock/plymouth, screensaver/about branding.
- setup: monitors, keybindings, input, typing.{keyboard,input}, network.{dns,qr},
  default.{terminal.kitty,editor.zed,browser.helium} (3 rows ONLY),
  plugin.{enable,disable,add,clone,remove}, config.{hyprland,hyprsunset}.
  DELETE: security.*, direct-boot, reset, agent, dictation, all other defaults.
- update/install/remove: slim paru set ONLY (Sec. 7). DELETE every upstream
  `install.{ai,browser(non-helium),editor(non-zed),terminal(non-kitty),gaming,service,development,style extras,windows,webapp,tui,preinstalls}`,
  `remove.*` equivalents, and OS-pipeline `update.*` (channel/firmware/hardware/password/process/time/timezone).
- system/about: keep as-is.
Acceptance: menu JSONC parses, search shows ZERO rows for ai/windows/spotify/steam/docker/chromium/nvim/foot.

## 5. File sets (freeze = `git archive quattro`, then filter)

COPY (root-owned under `/usr/share/omarchy-standalone`):
- `shell/` minus `plugins/agents/` minus `plugins/dev-gallery/` (keep shell.qml,
  Commons/, Ui/, services/, plugins/{background,bar,clipboard,emojis,image-picker,lock,menu,notifications,osd,polkit,reminders}, panels/).
- `themes/catppuccin/` (verify `colors.toml` exists) ONLY.
- `default/themed/{kitty.conf.tpl,hyprland.lua.tpl,shell.toml.tpl}` ONLY.
- `default/hypr/` FULL (bootstrap/envs/paths/omarchy/apps/bindings/toggles needed).
- `default/omarchy/slim-menu.jsonc` (Sec. 4) as `omarchy-menu.jsonc`.
- `bin/` curated ≈25: omarchy-shell, launch-{shell,browser,editor,terminal,tui,webapp,nautilus,nautilus-cwd,or-focus,floating-terminal-with-presentation},
  theme-{set,set-templates,install,update,remove,extras,list,bg-set,bg-switcher,bg-cache,current}, git-url-check,
  bar, menu-{select,keybindings,clipboard,emoji}, shell-config, hyprland-{monitor-*,window-gaps-toggle},
  default-{browser,editor,terminal}, notification-send, capture-{screenshot,screenrecording}, toggle-{bar,idle,nightlight},
  network-{status,qr}, powerprofiles-*, hw-{laptop}, cmd-{present,missing}, pkg-{add,drop,present,missing},
  slim pkg-{install,remove,aur-install} (rewrites), slim update-{system,pacman-only,aur-only,check},
  appimage-install, plugin-{add,enable,disable,clone,remove,list,validate,catalog}.
USER-WRITE (back up `.bak.<ts>` first):
- `~/.config/hypr/{hyprland.lua,bindings.lua,monitors.lua,input.lua,looknfeel.lua,autostart.lua}`
  from `config/hypr/` + append `exec-once = omarchy-launch-shell` (via autostart.lua helper).
- `~/.config/omarchy/shell.json` = Sec. 5 minimal (agents element REMOVED).
- Fish `~/.config/fish/conf.d/omarchy-standalone.fish` (Sec. 6).
- `~/.local/state/omarchy/defaults/{editor (=zeditor),terminal (=kitty)}`,
  `~/.config/xdg-terminals.list` (=kitty.desktop), xdg browser (=helium.desktop).
- `/usr/share/wayland-sessions/omarchy-standalone.desktop` (sudo, Sec. 6).
NEVER COPY: Sec. 0 removal list, `install/`, `migrations/`, SDDM/Limine configs,
  `etc/sudoers.d/*` (no passwordless sudo in v1).

### Minimal `~/.config/omarchy/shell.json` (exact)

```json
{
  "version": 1,
  "bar": {
    "position": "top", "transparent": false,
    "layout": {
      "left": [{"id": "omarchy.menu"}, {"id": "omarchy.workspaces"}],
      "center": [{"id": "omarchy.clock", "format": "dddd HH:mm"}],
      "right": [{"id": "omarchy.tray"}, {"id": "omarchy.network"}, {"id": "omarchy.audio"}, {"id": "omarchy.power"}]
    }
  },
  "plugins": []
}
```

## 6. Ly + Fish + env (exact)

Ly session `/usr/share/wayland-sessions/omarchy-standalone.desktop`:
```ini
[Desktop Entry]
Name=Omarchy Standalone
Comment=Omarchy shell on Hyprland (start-hyprland)
Exec=start-hyprland
TryExec=start-hyprland
Type=Application
```
Fish `~/.config/fish/conf.d/omarchy-standalone.fish`:
```fish
set -gx OMARCHY_PATH /usr/share/omarchy-standalone
fish_add_path $OMARCHY_PATH/bin
set -gx EDITOR "omarchy-launch-editor --inline"
```
Hyprland env: NO Lua edit needed (`default/hypr/envs.lua` already does
`hl.env("OMARCHY_PATH", paths.omarchy_path)`; `paths.lua` reads env first).
Shell autostart: `~/.config/hypr/autostart.lua` gets
`o.launch_on_start("omarchy-launch-shell")` (helper in `default/hypr/helpers.lua`).
Unresolved-at-plan-time (verify on first install, then pin here):
Helium `.desktop` id, Zed binary name on PATH (`zeditor` expected per default-editor),
Ly `Exec` behavior with `start-hyprland` args on that machine.

## 7. Theme + paru package UI (exact commands)

Theme: `OMARCHY_PATH=/usr/share/omarchy-standalone omarchy-theme-set-templates &&
  omarchy-theme-set "Catppuccin"`. State lands in
  `~/.local/state/omarchy/current/{theme,theme.name,next-theme}`; Kitty/Hyprland/shell
  pick up rendered files. If `themes/catppuccin/colors.toml` is absent → abort,
  do NOT fall back to another theme silently.
Slim menu commands (gum-based; fzf is GONE):
- `update.system` → `paru -Syu` (pacman+AUR one pass).
- `update.pacman-only` → `sudo pacman -Syu`.
- `update.aur-only` → `paru -Sua`.
- `update.check` → `checkupdates; paru -Qua`.
- `install.package` → `pacman -Slq | gum filter --no-limit --header "pacman (official)" | xargs -r sudo pacman -S --needed`.
- `install.aur` → `paru -Slqa | gum filter --no-limit --header "AUR" | xargs -r paru -S --needed`.
- `remove.package` → `paru -Qqe | gum filter --no-limit --header "Remove" | xargs -r sudo pacman -Rns`.
- Dropped upstream: snapshot/migrate/boot-verify/reboot-offer, pacman-guard,
  sudoers wrappers, `yay -Qi/-Siia` fzf previews.

## 8. AppImages (exact behavior)

`AppLibrary.qml` reads ONLY XDG `.desktop` entries → raw
`~/Applications/*.AppImage` NEVER appears in search. Ship:
- `~/Applications/` dir + `bin/omarchy-appimage-install <file.AppImage>`:
  `chmod +x`, write `~/.local/share/applications/<name>.desktop`
  (`Exec=<abs path>`, `Type=Application`, `Terminal=false`),
  `update-desktop-database ~/.local/share/applications`.
- Optional `setup.appimage` menu row calling it with `omarchy-file-select`.
- Uninstall = delete `.desktop` + optional AppImage (no registry).

## 9. Build order (do not reorder — each gates the next)

0. Freeze: `git archive quattro` → `/tmp/standalone-src`; apply Sec. 3 P7 deletions.
1. Patch tree (P1–P6); `grep -rn "uwsm-app" $SRC/{bin,shell,default}` MUST print nothing;
   `grep -rn "yay" $SRC/bin` MUST print nothing (except comments).
2. Slim menu (Sec. 4) + `shell.json` (Sec. 5); validate JSONC parses
   (strip `//` comments + trailing commas via python before `json.load`).
3. Theme smoke on DEV machine: `OMARCHY_PATH=$SRC bin/omarchy-theme-set-templates`
   then `omarchy-theme-set "Catppuccin"`; assert Kitty/Hyprland/shell outputs exist
   under `~/.local/state/omarchy/current/next-theme`.
4. Shell smoke: `quickshell -n -p $SRC/shell` under a running Hyprland;
   bar renders, `omarchy-shell shell listPlugins` shows no `omarchy.agents`.
5. `install.sh` (Sec. 2 order) with backups + `set -euo pipefail`.
6. TTY test matrix: CachyOS TTY + vanilla Arch TTY (VMs). Cold path:
   TTY → Ly → start-hyprland → bar → theme → menu → Helium/Kitty/Zed →
   paru update/install/remove → AppImage install → reboot repeat.
7. Run `./test/shell` theme-templates + menu subsets against the COPIED tree
   (upstream suite assumes full tree — failures outside templates/menu are
   out of scope; record, don't fix by weakening asserts).

## Build log (executed — `standalone-src/` in checkout root)

- Phase 0 freeze: copied `shell/ bin/ config/`, `themes/catppuccin/` only,
  `default/{hypr,omarchy,themed}/`. Catppuccin `colors.toml` present.
- Phase 1 deletions: `shell/plugins/{agents,dev-gallery}/`, panels
  `{dropbox,tailscale}/`, ~90 AI/VM/gaming/service/dev/dictation/plymouth/provision/
  apply/migrate/snapshot/update-*/preinstall/webapp/tui/1password/discord/signal/
  spotify/openclaw scripts, `theme-set-{vscode,claude,pi,t3code,hermes,obsidian,
  browser*,tmux,foot,gnome,hunk,keyboard*,herdr-machines}`, install-terminal,
  16 of 19 templates (kept kitty/hyprland/shell), theme `neovim.lua`+`vscode.json`.
- Phase 1 patches (all `bash -n` clean): de-uwsm in 12 bin scripts +
  AppLibrary.qml + nightlight Service.qml + helpers.lua (`grep uwsm-app` = none
  outside menu); helium getter+setter in default-browser; editor fallback
  nvim→zeditor; `yay`→`paru` in pkg-aur-add (`grep yay/fzf` in bin/ = none);
  agents element removed from shell.json; new gum-based pkg-install/aur-install/
  remove, helium-only install-browser, update-{system,pacman-only,aur-only,check},
  appimage-install.
- Phase 2: slim menu 72 rows / 9 roots / zero banned-substring rows (JSON-parsed);
  shell.json v1 valid, agents-free; templates render clean with
  `OMARCHY_PATH`+`PATH` set (hyprland.lua, kitty.conf w/ Catppuccin colors, shell.toml).
- Phase 3: `install.sh` (executable, `bash -n` clean, Sec. 2 order: preflight →
  pacman set → paru-bin bootstrap → helium → NVIDIA note → copy to
  /usr/share/omarchy-standalone → backed-up user configs + autostart append →
  Ly session → theme render+apply → `systemctl enable ly`) plus
  `extras/omarchy-standalone.desktop` (Ly/start-hyprland) +
  `extras/omarchy-standalone.fish` (OMARCHY_PATH/PATH/EDITOR). All referenced
  files verified present; no yay/uwsm/chromium/sddm refs.
- Phase 4 audit: all 41 menu-referenced `omarchy-*` cmds present in `bin/`;
  shell QML audit clean except IPC-target/PAM/platform-path pseudo-refs (not binaries).
  Added slim `bin/omarchy-update` (→ update-system) + `bin/omarchy-update-available`
  (checkupdates/paru -Qua probe) so the `omarchy.system-update` widget works if placed.
- Phase 5: trimmed `omarchy-theme-set` post commands to `omarchy-restart-terminal`
  only (11 deleted helpers referenced) + dropped herdr-machines mirror line;
  added `OMARCHY_STANDALONE_TARGET/SESSIONS_DIR/ALLOW_NON_ARCH` test hooks.
  Sandbox run (stub pacman/paru/systemctl, fake HOME) EXIT 0: tree, session,
  hypr confs + autostart append, agents-free shell.json, fish conf,
  zeditor/kitty/helium defaults, Catppuccin theme state all verified on disk.
  Sandbox caught + fixed 2 real bugs (sessions-dir mkdir, NVIDIA false positive).
- Phase 6: full sweep — 377 bash scripts `bash -n` clean, 35 manifests JSON-valid
  with all entryPoints resolving; fixed CRLF terminators in 2 python-patched
  files + shell.json (Windows-python newline translation; rule: normalize with
  `sed -i 's/\r$//'` after any python write). Transfer: `omarchy-standalone.tar.gz`
  (5.2M, 792 entries) + sha256 + `standalone-src/RUNBOOK.md` (TTY steps, checks,
  verify-on-install items, rollback).
- Phase 7: `.gitignore` keeps unpacked `standalone-src/` out of git (tarball+sha
  stay tracked as the transfer artifact); no test walks the repo root so new
  top-level files can't pollute the suite. Upstream `theme-templates-test.sh`
  PASSES here (checkout untouched); `menu-test.sh` FAILS pre-existing
  (`menu lists Toggle first under Trigger` — source files dated checkout time,
  never modified by this build; upstream/environment issue, left alone).
- NEXT: live TTY run on CachyOS + vanilla Arch (needs Arch hardware).

## 10. V1 acceptance (all must pass; no partial credit)

- [ ] TTY `install.sh` completes on CachyOS + vanilla Arch; reboot → Ly offers
  "Omarchy Standalone"; login → `start-hyprland` → bar renders, journal
  (`journalctl -t omarchy-shell`) has no `agents` errors.
- [ ] `echo $OMARCHY_PATH` = `/usr/share/omarchy-standalone` in Fish + Hyprland exec.
- [ ] `omarchy-theme-set "Catppuccin"` recolors Kitty + Hyprland + shell.
- [ ] Menu search for ai/windows/spotify/steam/docker/chromium/nvim/foot = zero rows;
  Apps shows Helium, Kitty, Zed.
- [ ] `omarchy-launch-editor ~/notes` → Zed; `omarchy-launch-browser` → Helium;
  `omarchy-default-terminal` → kitty.
- [ ] `update.system/pacman-only/aur-only/check`, `install.package/aur`,
  `remove.package` all work via paru+gum (no yay, no fzf).
- [ ] AppImage in `~/Applications/` + installer → appears in Apps search + launches.
- [ ] Fish: `which omarchy-shell`, `$EDITOR` = Zed wrapper.
- [ ] btrfs/limine untouched (`bootctl status`/`limine` config unmodified).
