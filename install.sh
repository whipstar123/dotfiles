#!/bin/bash
#
# Omarchy Shell Standalone installer — TTY to desktop on any Arch-based system.
# Run from a TTY on the target machine:  sudo ./install.sh
# (sudo needed for pacman + /usr/share + Ly; user configs land in $SUDO_USER's home.)
#
# Order follows plans/omarchy-shell-standalone.md Sec. 2. Bootloader (limine)
# and filesystem (btrfs) are NEVER touched.

set -euo pipefail

TARGET="${OMARCHY_STANDALONE_TARGET:-/usr/share/omarchy-standalone}"
SESSIONS_DIR="${OMARCHY_STANDALONE_SESSIONS_DIR:-/usr/share/wayland-sessions}"
SRC="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Resolve the real user when run under sudo.
if (( EUID == 0 )) && [[ -n ${SUDO_USER:-} ]]; then
  USER_NAME="$SUDO_USER"
  USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
  USER_NAME="$(id -un)"
  USER_HOME="$HOME"
fi

log() { printf '\e[32m== %s\e[0m\n' "$*"; }
warn() { printf '\e[33m!! %s\e[0m\n' "$*" >&2; }
die() { printf '\e[31mXX %s\e[0m\n' "$*" >&2; exit 1; }

backup_copy() {
  local src="$1" dest="$2"
  if [[ -e $dest && ! -L $dest ]]; then
    local bak="${dest}.bak.$(date +%s)"
    log "Backing up $dest -> $bak"
    mv -- "$dest" "$bak"
  fi
  mkdir -p -- "$(dirname -- "$dest")"
  cp -a -- "$src" "$dest"
}

# --- 0. Preflight -----------------------------------------------------------
if [[ ${OMARCHY_STANDALONE_ALLOW_NON_ARCH:-0} != "1" ]]; then
  [[ -f /etc/arch-release ]] || die "Not an Arch-based system (/etc/arch-release missing)."
fi
command -v pacman >/dev/null || die "pacman not found."
command -v sudo >/dev/null || die "sudo not found."
sudo -v || die "sudo authentication failed."
[[ -n ${USER_HOME:-} && -d $USER_HOME ]] || die "Cannot resolve user home."
[[ -f $SRC/bin/omarchy-theme-set && -f $SRC/themes/catppuccin/colors.toml ]] \
  || die "Installer must run from the standalone-src tree (theme engine missing)."

# --- 1. Official-repo packages (only what the system doesn't already pack) ----
# Stock images (e.g. CachyOS nodesktop) already ship much of this list. Only
# missing packages are installed, so their setup (like mesa-git) is kept
# untouched and no provider/conflict prompts fire for satisfied deps.
# base-devel is a group, so it always goes through (-Q cannot test groups);
# --needed keeps it a no-op when complete.
want=(
  git fish ly hyprland
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-terminal-exec
  qt6-base qt6-declarative qt6-wayland qt6-svg qt6-multimedia quickshell
  kitty zed jq socat wl-clipboard grim slurp hyprsunset hyprpicker polkit
  pipewire wireplumber pipewire-pulse pipewire-alsa
  networkmanager bluez pamixer brightnessctl power-profiles-daemon udiskie
  nautilus sushi imv mpv evince btop fastfetch gum
  gpu-screen-recorder tesseract tesseract-data-eng
  ttf-cascadia-mono-nerd noto-fonts noto-fonts-emoji
  ttf-jetbrains-mono-nerd woff2-font-awesome
)
missing=()
for p in "${want[@]}"; do
  pacman -Q "$p" &>/dev/null || missing+=("$p")
done
if (( ${#missing[@]} == 0 )); then
  log "Official-repo packages already complete; nothing to install."
else
  log "Installing missing official-repo packages: ${missing[*]}"
  if pacman -Q mesa-git &>/dev/null; then
    warn "mesa-git detected (stock CachyOS graphics stack) - keeping it."
    warn "If pacman asks you to pick a provider, choose the -git one already installed."
  fi
  # Intentionally interactive (no --noconfirm): provider/conflict questions
  # belong to the operator on this TTY.
  sudo pacman -S --needed base-devel "${missing[@]}" \
    || die "pacman package install failed."
fi

# --- 2. paru (bootstrap if missing, rebuild if broken) -------------------------
# A paru linked against a stale libalpm (e.g. after a pacman upgrade) fails
# with "error while loading shared libraries". Rebuild it from AUR in that
# case instead of trusting the broken binary.
if command -v paru >/dev/null && paru --version &>/dev/null; then
  log "paru already present and working."
else
  if command -v paru >/dev/null; then
    warn "Installed paru is broken (stale library link); rebuilding from AUR..."
  else
    log "Bootstrapping paru from AUR..."
  fi
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
    || die "paru-bin clone failed (network or AUR unreachable)."
  (cd "$tmp/paru-bin" && makepkg -si --noconfirm) \
    || die "paru build/install failed (try a full system update first)."
  trap - EXIT
  rm -rf "$tmp"
fi
aur_want=(helium-browser-bin omasnap-bin cliamp)
aur_missing=()
for p in "${aur_want[@]}"; do
  pacman -Q "$p" &>/dev/null || aur_missing+=("$p")
done
if (( ${#aur_missing[@]} == 0 )); then
  log "AUR packages already complete; nothing to install."
else
  log "Installing missing AUR packages: ${aur_missing[*]}"
  paru -S --needed --noconfirm "${aur_missing[@]}" \
    || die "AUR package install failed."
fi

# --- 3. NVIDIA note (generic hardware: inform, don't auto-install) ------------
if lspci 2>/dev/null | grep -qi nvidia && ! command -v nvidia-smi >/dev/null 2>&1; then
  warn "NVIDIA GPU detected. If Hyprland fails to start, install the matching"
  warn "nvidia/nvidia-open driver + linux headers for your kernel, then reboot."
fi

# --- 4. System tree ------------------------------------------------------------
log "Installing standalone tree -> $TARGET ..."
sudo mkdir -p -- "$TARGET"
sudo cp -a -- "$SRC/shell" "$SRC/bin" "$SRC/config" "$SRC/themes" "$SRC/default" "$SRC/extras" "$TARGET/"
sudo chmod -R a+rX -- "$TARGET"
[[ -f $TARGET/shell/shell.qml ]] || die "Copy failed: $TARGET/shell/shell.qml missing."

# --- 5. User configs (backed up) ----------------------------------------------
export OMARCHY_PATH="$TARGET"
export PATH="$TARGET/bin:$PATH"

log "Writing user configs for $USER_NAME ..."
for f in hyprland.lua bindings.lua monitors.lua input.lua looknfeel.lua autostart.lua; do
  if [[ -f $SRC/config/hypr/$f ]]; then
    sudo -u "$USER_NAME" mkdir -p -- "$USER_HOME/.config/hypr"
    # backup-as-user to keep ownership sane
    if [[ -e $USER_HOME/.config/hypr/$f ]]; then
      sudo -u "$USER_NAME" mv -- "$USER_HOME/.config/hypr/$f" "$USER_HOME/.config/hypr/$f.bak.$(date +%s)"
    fi
    sudo cp -a -- "$SRC/config/hypr/$f" "$USER_HOME/.config/hypr/$f"
    sudo chown "$USER_NAME" -- "$USER_HOME/.config/hypr/$f"
  fi
done

# Shell autostart inside Hyprland.
if ! sudo -u "$USER_NAME" grep -q "omarchy-launch-shell" "$USER_HOME/.config/hypr/autostart.lua" 2>/dev/null; then
  echo 'o.launch_on_start("omarchy-launch-shell")' | sudo -u "$USER_NAME" tee -a "$USER_HOME/.config/hypr/autostart.lua" >/dev/null
fi

sudo -u "$USER_NAME" mkdir -p -- "$USER_HOME/.config/omarchy" "$USER_HOME/.config/fish/conf.d" \
  "$USER_HOME/.local/state/omarchy/defaults" "$USER_HOME/Applications"
if [[ -e $USER_HOME/.config/omarchy/shell.json ]]; then
  sudo -u "$USER_NAME" mv -- "$USER_HOME/.config/omarchy/shell.json" "$USER_HOME/.config/omarchy/shell.json.bak.$(date +%s)"
fi
sudo cp -a -- "$SRC/config/omarchy/shell.json" "$USER_HOME/.config/omarchy/shell.json"
sudo cp -a -- "$SRC/extras/omarchy-standalone.fish" "$USER_HOME/.config/fish/conf.d/omarchy-standalone.fish"
sudo chown "$USER_NAME" -- "$USER_HOME/.config/omarchy/shell.json" "$USER_HOME/.config/fish/conf.d/omarchy-standalone.fish"
printf 'zeditor\n' | sudo -u "$USER_NAME" tee "$USER_HOME/.local/state/omarchy/defaults/editor" >/dev/null
printf 'kitty\n' | sudo -u "$USER_NAME" tee "$USER_HOME/.local/state/omarchy/defaults/terminal" >/dev/null
printf 'kitty.desktop\n' | sudo -u "$USER_NAME" tee "$USER_HOME/.config/xdg-terminals.list" >/dev/null
sudo -u "$USER_NAME" mkdir -p -- "$USER_HOME/.local/state/omarchy"
sudo -u "$USER_NAME" touch -- "$USER_HOME/.local/state/omarchy/preinstalls-removed"
sudo -u "$USER_NAME" env -u BROWSER xdg-settings set default-web-browser helium.desktop \
  || warn "Could not set Helium as default browser (no xdg-settings session?)."

# Ly session entry (system path).
log "Installing Ly session entry..."
sudo mkdir -p -- "$SESSIONS_DIR"
sudo cp -a -- "$SRC/extras/omarchy-standalone.desktop" "$SESSIONS_DIR/omarchy-standalone.desktop"

# --- 6. Theme ------------------------------------------------------------------
log "Applying Catppuccin theme..."
sudo -u "$USER_NAME" env OMARCHY_PATH="$TARGET" PATH="$TARGET/bin:$PATH" \
  omarchy-theme-set-templates || die "Theme template render failed."
sudo -u "$USER_NAME" env OMARCHY_PATH="$TARGET" PATH="$TARGET/bin:$PATH" \
  omarchy-theme-set "Catppuccin" || die "Theme apply failed."

# --- 7. Enable Ly ---------------------------------------------------------------
log "Enabling Ly..."
sudo systemctl enable ly || die "Could not enable ly."

log "Done. Reboot, pick 'Omarchy Standalone' in Ly, and log in."
log "First checks: echo \$OMARCHY_PATH, omarchy-default-terminal (= kitty),"
log "  omarchy-default-editor (= zeditor), omarchy-default-browser (= helium)."
