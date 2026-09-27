#!/usr/bin/env bash
# Start the available wallpaper daemon and reapply the selected wallpaper.

set -u

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

rofi_wallpaper="$HOME/.config/rofi/.current_wallpaper"
current_wallpaper="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
log_file="$HOME/.cache/hypr/wallpaper-daemon.log"

mkdir -p "$(dirname "$log_file")"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file"
}

wallpaper_bin=""
daemon_bin=""

if command -v swww >/dev/null 2>&1 && command -v swww-daemon >/dev/null 2>&1; then
  wallpaper_bin="swww"
  daemon_bin="swww-daemon"
elif command -v awww >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
  wallpaper_bin="awww"
  daemon_bin="awww-daemon"
fi

if [[ -z "$wallpaper_bin" || -z "$daemon_bin" ]]; then
  log "missing wallpaper daemon"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Wallpaper daemon missing" "Install swww or awww"
  fi
  exit 1
fi

if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
  for _ in {1..50}; do
    [[ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]] && break
    sleep 0.1
  done
fi

start_daemon() {
  if [[ "$daemon_bin" == "swww-daemon" ]]; then
    "$daemon_bin" --format xrgb >/dev/null 2>&1 &
  else
    "$daemon_bin" --quiet >/dev/null 2>&1 &
  fi
}

wait_for_daemon() {
  for _ in {1..50}; do
    "$wallpaper_bin" query >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

if ! "$wallpaper_bin" query >/dev/null 2>&1; then
  if ! pgrep -x "$daemon_bin" >/dev/null 2>&1; then
    log "starting $daemon_bin for $wallpaper_bin"
    start_daemon
  fi

  if ! wait_for_daemon; then
    log "$daemon_bin did not become ready"
  fi
fi

# Keep the horizontal secondary monitor blank.
if [[ "$wallpaper_bin" == "awww" ]]; then
  "$wallpaper_bin" clear -o DP-3 000000ff >/dev/null 2>&1 || true
fi

restore_args=()
[[ "$wallpaper_bin" == "awww" ]] && restore_args=(-o DP-2)

wallpaper_path=""
if [[ -e "$rofi_wallpaper" ]]; then
  wallpaper_path="$(readlink -f "$rofi_wallpaper" 2>/dev/null || printf '%s' "$rofi_wallpaper")"
fi

if [[ ! -f "$wallpaper_path" && -f "$current_wallpaper" ]]; then
  wallpaper_path="$current_wallpaper"
fi

if [[ -f "$wallpaper_path" ]]; then
  log "applying $wallpaper_path"
  "$wallpaper_bin" img -o DP-2 --transition-type none "$wallpaper_path" >/dev/null 2>&1 ||
    "$wallpaper_bin" restore "${restore_args[@]}" >/dev/null 2>&1 ||
    log "failed to apply or restore wallpaper"
else
  log "no saved wallpaper found, trying restore"
  "$wallpaper_bin" restore "${restore_args[@]}" >/dev/null 2>&1 || true
fi
