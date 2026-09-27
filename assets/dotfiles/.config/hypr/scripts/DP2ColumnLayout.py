#!/usr/bin/env python3
from __future__ import annotations

import json
import logging
import os
import socket
import subprocess
import sys
import time
from pathlib import Path


TARGET_MONITOR = "DP-2"
TARGET_WORKSPACES = {"9", "10", "11", "12"}
SPLIT_ABOVE = "u"
SPLIT_BELOW = "d"
RECONNECT_DELAY_SECONDS = 1.0
OPEN_WINDOW_SETTLE_SECONDS = 0.05

RECHECK_EVENTS = {
    "activewindow",
    "activewindowv2",
    "closewindow",
    "configreloaded",
    "focusedmon",
    "focusedmonv2",
    "movewindow",
    "movewindowv2",
    "openwindow",
    "workspace",
    "workspacev2",
}

LOG_PATH = Path.home() / ".cache" / "hypr" / "DP2ColumnLayout.log"


def setup_logging() -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        filename=LOG_PATH,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )


def runtime_dir() -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))


def find_hypr_dir() -> Path:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if signature:
        candidate = runtime_dir() / "hypr" / signature
        if (candidate / ".socket2.sock").exists():
            return candidate

    candidates = [
        path.parent
        for path in (runtime_dir() / "hypr").glob("*/.socket2.sock")
        if path.exists()
    ]
    if not candidates:
        raise FileNotFoundError("Hyprland event socket was not found")

    return max(candidates, key=lambda path: path.stat().st_mtime)


def hypr_env(hypr_dir: Path | None = None) -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault("XDG_RUNTIME_DIR", str(runtime_dir()))
    if hypr_dir is not None:
        env["HYPRLAND_INSTANCE_SIGNATURE"] = hypr_dir.name
    return env


def hyprctl(*args: str, hypr_dir: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["hyprctl", *args],
        check=False,
        env=hypr_env(hypr_dir),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )


def hypr_eval(lua: str, hypr_dir: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["hyprctl", "eval", lua],
        check=False,
        env=hypr_env(hypr_dir),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def hyprctl_json(*args: str, hypr_dir: Path | None = None) -> object | None:
    result = subprocess.run(
        ["hyprctl", "-j", *args],
        check=False,
        env=hypr_env(hypr_dir),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        logging.warning("hyprctl -j %s failed: %s", " ".join(args), result.stderr.strip())
        return None

    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        logging.warning("hyprctl -j %s returned invalid JSON: %s", " ".join(args), exc)
        return None


def active_workspace_is_target(hypr_dir: Path | None = None) -> bool | None:
    workspace = hyprctl_json("activeworkspace", hypr_dir=hypr_dir)
    if not isinstance(workspace, dict):
        return None

    workspace_id = str(workspace.get("id", ""))
    workspace_name = str(workspace.get("name", ""))
    monitor = str(workspace.get("monitor", ""))

    return monitor == TARGET_MONITOR and (
        workspace_id in TARGET_WORKSPACES or workspace_name in TARGET_WORKSPACES
    )


def active_split_direction(hypr_dir: Path | None = None) -> str:
    window = hyprctl_json("activewindow", hypr_dir=hypr_dir)
    monitors = hyprctl_json("monitors", hypr_dir=hypr_dir)

    if not isinstance(window, dict) or not isinstance(monitors, list):
        return SPLIT_BELOW

    monitor = next(
        (
            item
            for item in monitors
            if isinstance(item, dict) and item.get("name") == TARGET_MONITOR
        ),
        None,
    )
    if not isinstance(monitor, dict):
        return SPLIT_BELOW

    window_at = window.get("at")
    window_size = window.get("size")
    if not (
        isinstance(window_at, list)
        and isinstance(window_size, list)
        and len(window_at) >= 2
        and len(window_size) >= 2
    ):
        return SPLIT_BELOW

    try:
        window_center_y = float(window_at[1]) + (float(window_size[1]) / 2)
    except (TypeError, ValueError):
        return SPLIT_BELOW

    try:
        transform = int(monitor.get("transform") or 0)
    except (TypeError, ValueError):
        transform = 0

    monitor_height = monitor.get("height", 0)
    if transform in (1, 3):
        monitor_height = monitor.get("width", 0)

    try:
        monitor_midpoint_y = float(monitor.get("y", 0)) + (float(monitor_height) / 2)
    except (TypeError, ValueError):
        return SPLIT_BELOW

    if window_center_y > monitor_midpoint_y:
        return SPLIT_ABOVE
    return SPLIT_BELOW


class ColumnMode:
    def __init__(self) -> None:
        self.enabled: bool | None = None
        self.last_direction: str | None = None

    def set_enabled(self, enable: bool, hypr_dir: Path) -> None:
        if self.enabled == enable:
            return

        value = "true" if enable else "false"
        result = hypr_eval(
            f"hl.config({{ dwindle = {{ permanent_direction_override = {value} }} }})",
            hypr_dir=hypr_dir,
        )
        if result.returncode == 0:
            self.enabled = enable
            logging.info("DP-2 column mode %s", "enabled" if enable else "disabled")
        else:
            logging.warning(
                "Failed to set dwindle:permanent_direction_override=%s: %s",
                value,
                result.stderr.strip(),
            )

    def apply_for_current_focus(self, hypr_dir: Path, force_preselect: bool = False) -> None:
        is_target = active_workspace_is_target(hypr_dir)
        if is_target is None:
            return

        self.set_enabled(is_target, hypr_dir)
        if not is_target:
            self.last_direction = None
            return

        if force_preselect or self.enabled:
            direction = active_split_direction(hypr_dir)
            result = hypr_eval(
                f'hl.dsp.layout("preselect {direction}")',
                hypr_dir=hypr_dir,
            )
            if result.returncode != 0:
                logging.debug("preselect %s skipped: %s", direction, result.stderr.strip())
            elif direction != self.last_direction:
                self.last_direction = direction
                placement = "above" if direction == SPLIT_ABOVE else "below"
                logging.info("Next DP-2 split will open %s the focused window", placement)


def should_recheck(event_line: str) -> tuple[bool, bool]:
    event_name, separator, _ = event_line.partition(">>")
    if not separator:
        return False, False

    return event_name in RECHECK_EVENTS, event_name in {"openwindow", "movewindow", "movewindowv2"}


def listen_events(column_mode: ColumnMode, hypr_dir: Path) -> None:
    socket_path = hypr_dir / ".socket2.sock"
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(str(socket_path))
        with client.makefile("r", encoding="utf-8", errors="replace") as events:
            column_mode.apply_for_current_focus(hypr_dir, force_preselect=True)
            for line in events:
                recheck, delayed = should_recheck(line.strip())
                if not recheck:
                    continue
                if delayed:
                    time.sleep(OPEN_WINDOW_SETTLE_SECONDS)
                column_mode.apply_for_current_focus(hypr_dir, force_preselect=True)


def main() -> int:
    setup_logging()
    column_mode = ColumnMode()

    if sys.argv[1:] == ["--once"]:
        column_mode.apply_for_current_focus(find_hypr_dir(), force_preselect=True)
        return 0

    logging.info("Starting DP-2 column layout helper")

    while True:
        try:
            hypr_dir = find_hypr_dir()
            listen_events(column_mode, hypr_dir)
        except KeyboardInterrupt:
            column_mode.set_enabled(False, find_hypr_dir())
            return 0
        except Exception as exc:
            logging.warning("DP-2 column layout helper reconnecting after error: %s", exc)
            time.sleep(RECONNECT_DELAY_SECONDS)


if __name__ == "__main__":
    raise SystemExit(main())
