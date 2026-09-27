#!/usr/bin/env bash

set -euo pipefail

workspace="9"

wait_for_window() {
  local class_regex="$1"
  local retries="${2:-80}"
  local sleep_seconds="${3:-0.10}"

  for _ in $(seq 1 "$retries"); do
    if hyprctl -j clients 2>/dev/null | grep -Eq "\"class\":\"${class_regex}\""; then
      return 0
    fi
    sleep "$sleep_seconds"
  done

  return 1
}

hyprctl dispatch workspace "$workspace"
sleep 0.2

fastpotify >/dev/null 2>&1 &
wait_for_window '[Ff]astpotify' || true
sleep 0.2

hyprctl dispatch layoutmsg preselect d
slack >/dev/null 2>&1 &
wait_for_window 'Slack' || true
sleep 0.2

hyprctl dispatch layoutmsg preselect d
kitty --class kitty-boot-bottom --title workspace-9-terminal >/dev/null 2>&1 &
wait_for_window 'kitty-boot-bottom' || true

sleep 0.2
hyprctl dispatch workspace 1
