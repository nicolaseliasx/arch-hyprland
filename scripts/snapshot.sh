#!/usr/bin/env bash
# Capture the portable PC-base profile without ever publishing credentials or
# leaving a partial snapshot in the repository.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${ARCH_HYPRLAND_REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SOURCE_HOME="${SNAPSHOT_HOME:-$HOME}"
ASSETS_DIR="$REPO_ROOT/assets"
PATHS_FILE="$ASSETS_DIR/snapshot-paths.txt"
STAGE_DIR=""

log() { printf '[snapshot] %s\n' "$*"; }
die() { printf '[snapshot] error: %s\n' "$*" >&2; exit 1; }

cleanup() {
  [[ -n "$STAGE_DIR" && -d "$STAGE_DIR" ]] && rm -rf -- "$STAGE_DIR"
}
trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

valid_relative_path() {
  [[ "$1" != /* && "$1" != *".."* && "$1" != "." && -n "$1" ]]
}

copy_config() {
  local source="$SOURCE_HOME/.config"
  local destination="$STAGE_DIR/dotfiles/.config"
  [[ -d "$source" ]] || die "expected configuration directory does not exist: $source"

  # These patterns intentionally favour safety over completeness. Application
  # credentials must be recreated on every machine, never committed to Git.
  local -a excludes=(
    '--exclude=.cache/***'
    '--exclude=.local/***'
    '--exclude=**/Cache/***'
    '--exclude=**/GPUCache/***'
    '--exclude=**/Code Cache/***'
    '--exclude=**/CachedData/***'
    '--exclude=**/CachedExtensionVSIXs/***'
    '--exclude=**/workspaceStorage/***'
    '--exclude=**/Local Storage/***'
    '--exclude=**/IndexedDB/***'
    '--exclude=**/Service Worker/***'
    '--exclude=**/Session Storage/***'
    '--exclude=**/Singleton*'
    '--exclude=**/*.log'
    '--exclude=**/*.sqlite'
    '--exclude=**/*.sqlite-*'
    '--exclude=**/*.db'
    '--exclude=**/*.pem'
    '--exclude=**/*.key'
    '--exclude=**/.env'
    '--exclude=**/.env.*'
    '--exclude=**/*.env'
    '--exclude=**/*token*'
    '--exclude=**/*Token*'
    '--exclude=**/*secret*'
    '--exclude=**/*Secret*'
    '--exclude=**/*password*'
    '--exclude=**/*Password*'
    '--exclude=**/google-chrome/***'
    '--exclude=**/google-chrome-for-testing/***'
    '--exclude=**/chromium/***'
    '--exclude=**/BraveSoftware/***'
    '--exclude=**/Mozilla/***'
    '--exclude=**/mozilla/***'
    '--exclude=JetBrains/analyzer/***'
    '--exclude=JetBrains/***'
    '--exclude=Code/***'
    '--exclude=pulse/***'
    '--exclude=Code/User/History/***'
    '--exclude=Code/User/globalStorage/***'
    '--exclude=Code/User/workspaceStorage/***'
    '--exclude=opencode/node_modules/***'
    '--exclude=Slack/***'
    '--exclude=discord/***'
    '--exclude=anytype/***'
    '--exclude=obsidian/***'
    '--exclude=Codex/***'
    '--exclude=hypr/wallpaper_effects/***'
    '--exclude=hypr/.initial_startup_done'
    '--exclude=gh/***'
    '--exclude=gcloud/***'
    '--exclude=rclone/***'
    '--exclude=aws/***'
    '--exclude=azure/***'
    '--exclude=op/***'
    '--exclude=codex/***'
    '--exclude=codex-mobile/***'
    '--exclude=configstore/***'
    '--exclude=**/*accounts*'
    '--exclude=**/Cookies*'
    '--exclude=systemd/user/arch-hyprland-snapshot.service'
    '--exclude=systemd/user/arch-hyprland-snapshot.timer'
    '--exclude=systemd/user/timers.target.wants/arch-hyprland-snapshot.timer'
  )

  mkdir -p "$destination"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --safe-links --prune-empty-dirs "${excludes[@]}" "$source/" "$destination/"
  else
    log 'rsync is unavailable; using the streaming tar fallback'
    (
      cd "$source"
      tar --create --file=- --wildcards "${excludes[@]}" .
    ) | (
      cd "$destination"
      tar --extract --file=- --preserve-permissions
    )
    # Keep the fallback's exclusions aligned with the rsync rules above.
    find "$destination" -type d \( -name '.cache' -o -name '.local' -o -name 'Cache' -o -name 'GPUCache' -o -name 'Code Cache' -o -name 'workspaceStorage' -o -name 'Local Storage' -o -name 'IndexedDB' -o -name 'Service Worker' -o -name 'Session Storage' -o -name 'google-chrome' -o -name 'google-chrome-for-testing' -o -name 'chromium' -o -name 'BraveSoftware' -o -name 'Mozilla' -o -name 'mozilla' -o -name 'Slack' -o -name 'discord' -o -name 'Code' -o -name 'JetBrains' -o -name 'pulse' -o -name 'gh' -o -name 'gcloud' -o -name 'rclone' -o -name 'aws' -o -name 'azure' -o -name 'op' -o -name 'codex' -o -name 'Codex' -o -name 'codex-mobile' -o -name 'configstore' -o -name 'anytype' -o -name 'obsidian' \) -prune -exec rm -rf -- {} +
    rm -rf -- "$destination/JetBrains" "$destination/Code" "$destination/pulse" "$destination/opencode/node_modules" "$destination/anytype" "$destination/obsidian" "$destination/Codex" "$destination/hypr/wallpaper_effects" "$destination/configstore"
    rm -f -- "$destination/hypr/.initial_startup_done"
    find "$destination" -type f \( -name '*.log' -o -name '*.sqlite' -o -name '*.sqlite-*' -o -name '*.db' -o -name '*.pem' -o -name '*.key' -o -name '*.env' -o -name '.env.*' -o -name '*.env' -o -name 'Cookies*' -o -iname '*token*' -o -iname '*secret*' -o -iname '*password*' -o -iname '*accounts*' \) -delete
    find "$destination" -type l \( -lname '/*' -o -lname '*..*' \) -delete
    rm -f -- "$destination/systemd/user/arch-hyprland-snapshot.service" "$destination/systemd/user/arch-hyprland-snapshot.timer" "$destination/systemd/user/timers.target.wants/arch-hyprland-snapshot.timer"
  fi

  # Electron and JetBrains keep credentials and multi-gigabyte runtime state in
  # .config. Re-add only the settings that make the editors behave like the
  # PC base on a fresh machine.
  local code_source="$source/Code/User"
  local code_destination="$destination/Code/User"
  local code_item
  for code_item in settings.json keybindings.json mcp.json tasks.json extensions.json snippets; do
    [[ -e "$code_source/$code_item" ]] || continue
    mkdir -p "$code_destination"
    cp -a -- "$code_source/$code_item" "$code_destination/$code_item"
  done

  local product component product_name
  for product in "$source/JetBrains"/*; do
    [[ -d "$product" ]] || continue
    product_name="$(basename "$product")"
    for component in options codestyles keymaps colors templates inspection; do
      [[ -e "$product/$component" ]] || continue
      mkdir -p "$destination/JetBrains/$product_name"
      cp -a -- "$product/$component" "$destination/JetBrains/$product_name/$component"
    done
  done

  # A portable monitor definition prevents connector names from the desktop
  # PC (for example DP-3) from breaking Hyprland on a notebook.
  mkdir -p "$destination/hypr"
  cat >"$destination/hypr/monitors.conf" <<'EOF'
# Portable profile generated by arch-hyprland snapshot.
monitor = , preferred, auto, 1
EOF
}

copy_profile_path() {
  local relative_path="$1"
  local source="$SOURCE_HOME/$relative_path"
  local destination="$STAGE_DIR/dotfiles/$relative_path"

  [[ "$relative_path" == '.config' ]] && { copy_config; return; }
  [[ -e "$source" || -L "$source" ]] || { log "not present on base: $relative_path"; return; }
  [[ -L "$source" ]] && { log "skipping symbolic link outside profile: $relative_path"; return; }

  mkdir -p "$(dirname "$destination")"
  if [[ -d "$source" ]]; then
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --safe-links "$source/" "$destination/"
    else
      mkdir -p "$destination"
      cp -a -- "$source/." "$destination/"
    fi
  else
    cp -a -- "$source" "$destination"
  fi
}

normalize_portable_profile() {
  local dotfiles="$STAGE_DIR/dotfiles"
  local escaped_source_home portable_home file
  escaped_source_home="${SOURCE_HOME//\\/\\\\}"
  escaped_source_home="${escaped_source_home//|/\\|}"
  escaped_source_home="${escaped_source_home//&/\\&}"
  portable_home='$HOME'

  # Snapshot source paths must not tie the restored profile to one username.
  while IFS= read -r -d '' file; do
    grep -Iq . "$file" || continue
    sed -i "s|$escaped_source_home|$portable_home|g" "$file"
  done < <(find "$dotfiles" -type f -print0)

  # Keep the versioned profile usable on a single-panel notebook. The base PC
  # can recreate its connector-specific layout locally with nwg-displays.
  if [[ -f "$dotfiles/.config/hypr/workspaces.conf" ]]; then
    sed -i '/^[[:space:]]*workspace[[:space:]]*=.*,[[:space:]]*monitor:/d' "$dotfiles/.config/hypr/workspaces.conf"
  fi
  if [[ -f "$dotfiles/.config/hypr/monitors.lua" ]]; then
    cat >"$dotfiles/.config/hypr/monitors.lua" <<'EOF'
-- Portable fallback: preferred resolution, automatic placement and scale 1.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
EOF
  fi
  if [[ -f "$dotfiles/.config/hypr/workspaces.lua" ]]; then
    cat >"$dotfiles/.config/hypr/workspaces.lua" <<'EOF'
-- Workspaces intentionally are not pinned to connector names.
EOF
  fi
  if [[ -f "$dotfiles/.config/hypr/hyprlock.conf" ]]; then
    sed -i 's/^[[:space:]]*monitor[[:space:]]*=.*$/    monitor =/' "$dotfiles/.config/hypr/hyprlock.conf"
  fi
  if [[ -f "$dotfiles/.config/hypr/hypridle.conf" ]]; then
    sed -i 's|^[[:space:]]*unlock_cmd[[:space:]]*=.*$|    unlock_cmd = hyprctl dispatch dpms on|' "$dotfiles/.config/hypr/hypridle.conf"
  fi
  if [[ -f "$dotfiles/.config/hypr/scripts/LockScreen.sh" ]]; then
    sed -i \
      -e "s|hyprctl eval 'hl.monitor({ output = \"DP-2\", disabled = true })'|hyprctl dispatch dpms off|" \
      -e "s|hyprctl eval 'hl.monitor({ output = \"DP-2\", disabled = false })'|hyprctl dispatch dpms on|" \
      "$dotfiles/.config/hypr/scripts/LockScreen.sh"
  fi

  # rsync --safe-links correctly drops absolute links from the source machine.
  # Recreate only the known visual selectors as relative links after confirming
  # that both the source and target stay inside the captured home profile.
  local relative_link source_link resolved_source relative_target destination_link link_value
  for relative_link in \
    .config/waybar/config \
    .config/waybar/style.css \
    .config/rofi/.current_wallpaper; do
    source_link="$SOURCE_HOME/$relative_link"
    [[ -L "$source_link" ]] || continue
    resolved_source="$(readlink -f "$source_link" 2>/dev/null || true)"
    [[ "$resolved_source" == "$SOURCE_HOME/"* ]] || continue
    relative_target="${resolved_source#"$SOURCE_HOME/"}"
    [[ -e "$dotfiles/$relative_target" ]] || continue
    destination_link="$dotfiles/$relative_link"
    mkdir -p "$(dirname "$destination_link")"
    link_value="$(realpath --relative-to="$(dirname "$destination_link")" "$dotfiles/$relative_target")"
    ln -sfn "$link_value" "$destination_link"
  done
}

capture_packages() {
  local packages_dir="$STAGE_DIR/packages"
  mkdir -p "$packages_dir"
  {
    pacman -Qqen | grep -vxE '^(nvidia|nvidia-dkms|nvidia-open|nvidia-open-dkms|nvidia-settings|nvidia-utils|libva-nvidia-driver)$' || true
    printf '%s\n' breeze-icons eza
  } | LC_ALL=C sort -u >"$packages_dir/pacman-explicit.txt"
  # Only preserve explicitly installed foreign packages. `yay -Qqm` also
  # includes dependency and split debug packages that cannot be installed by
  # name on a fresh machine (for example waybar-git-debug).
  pacman -Qqem | grep -vxE '^(yay|yay-bin|paru)$' | LC_ALL=C sort -u >"$packages_dir/aur-explicit.txt" || true
  pacman -Qqe | LC_ALL=C sort >"$packages_dir/pacman-versions.txt"
  pacman -Qqm | grep -vE '^(yay|yay-bin|paru) ' | LC_ALL=C sort >"$packages_dir/aur-versions.txt" || true
}

validate_stage() {
  [[ -d "$STAGE_DIR/dotfiles/.config" ]] || die 'snapshot validation failed: .config was not captured'
  [[ -f "$STAGE_DIR/packages/pacman-explicit.txt" ]] || die 'snapshot validation failed: pacman list is missing'
  [[ -f "$STAGE_DIR/packages/aur-explicit.txt" ]] || die 'snapshot validation failed: AUR list is missing'
  [[ -f "$STAGE_DIR/dotfiles/.config/hypr/shaders/digital-vibrance-90.frag" ]] || die 'snapshot validation failed: screen shader is missing'
  [[ -f "$STAGE_DIR/dotfiles/pictures/wallpapers/583256.jpg" ]] || die 'snapshot validation failed: default wallpaper is missing'
  [[ -d "$STAGE_DIR/dotfiles/.themes/NCLS-Black-Waybar" ]] || die 'snapshot validation failed: GTK theme is missing'
  [[ -e "$STAGE_DIR/dotfiles/.config/waybar/config" ]] || die 'snapshot validation failed: active Waybar layout is missing'
  [[ -e "$STAGE_DIR/dotfiles/.config/waybar/style.css" ]] || die 'snapshot validation failed: active Waybar style is missing'
  [[ -e "$STAGE_DIR/dotfiles/.config/rofi/.current_wallpaper" ]] || die 'snapshot validation failed: active wallpaper link is missing'
  local oversized
  oversized="$(find "$STAGE_DIR/dotfiles" -type f -size +95M -print -quit)"
  [[ -z "$oversized" ]] || die "snapshot validation failed: file exceeds GitHub's practical size limit: $oversized"
  local credential_pattern='(sk-(proj-)?[A-Za-z0-9_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|api[_-]?key[[:space:]]*[:=]|[0-9]{8,10}:[A-Za-z0-9_-]{35})'
  local sensitive_paths
  if command -v rg >/dev/null 2>&1; then
    sensitive_paths="$(rg -l -i "$credential_pattern" "$STAGE_DIR/dotfiles" 2>/dev/null || true)"
  elif command -v grep >/dev/null 2>&1; then
    sensitive_paths="$(grep -rEl "$credential_pattern" "$STAGE_DIR/dotfiles" 2>/dev/null || true)"
  else
    die 'snapshot validation failed: no text search tool (rg or grep) available'
  fi
  [[ -z "$sensitive_paths" ]] || die "snapshot validation failed: possible credential found in $sensitive_paths"
}

replace_snapshot_artifact() {
  local staged="$1"
  local target="$2"
  local previous="${target}.previous.$$"
  [[ -e "$staged" ]] || die "staged artifact is missing: $staged"
  rm -rf -- "$previous"
  if [[ -e "$target" ]]; then
    mv -- "$target" "$previous"
  fi
  if ! mv -- "$staged" "$target"; then
    [[ -e "$previous" ]] && mv -- "$previous" "$target"
    die "could not replace $target"
  fi
  rm -rf -- "$previous"
}

main() {
  [[ -f "$PATHS_FILE" ]] || die "path manifest not found: $PATHS_FILE"
  [[ -d "$SOURCE_HOME" ]] || die "home directory not found: $SOURCE_HOME"
  require_command pacman

  STAGE_DIR="$(mktemp -d "$REPO_ROOT/.snapshot-stage.XXXXXX")"
  mkdir -p "$STAGE_DIR/dotfiles"
  while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
    [[ -z "$relative_path" || "$relative_path" == \#* ]] && continue
    valid_relative_path "$relative_path" || die "unsafe path in manifest: $relative_path"
    log "capturing $relative_path"
    copy_profile_path "$relative_path"
  done <"$PATHS_FILE"

  normalize_portable_profile
  capture_packages
  cat >"$STAGE_DIR/snapshot-metadata.env" <<EOF
SNAPSHOT_FORMAT=2
CREATED_AT=$(date --iso-8601=seconds)
PACMAN_PACKAGE_COUNT=$(wc -l <"$STAGE_DIR/packages/pacman-explicit.txt")
AUR_PACKAGE_COUNT=$(wc -l <"$STAGE_DIR/packages/aur-explicit.txt")
EOF
  validate_stage

  replace_snapshot_artifact "$STAGE_DIR/dotfiles" "$ASSETS_DIR/dotfiles"
  replace_snapshot_artifact "$STAGE_DIR/packages" "$ASSETS_DIR/packages"
  replace_snapshot_artifact "$STAGE_DIR/snapshot-metadata.env" "$ASSETS_DIR/snapshot-metadata.env"
  log 'snapshot completed successfully'
}

main "$@"
