#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path


STATE_DIR = Path.home() / ".cache" / "hypr"
STATE_FILE = STATE_DIR / "spotify-mode"
LOG_FILE = STATE_DIR / "spotify-miniplayer.log"
SPOTIFY_CLASSES = {"fastpotify"}
DEFAULT_WORKSPACE = "9"
MINI_MARGIN_X = 24
MINI_MARGIN_Y = 24


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
        raise RuntimeError("Hyprland event socket was not found")

    return max(candidates, key=lambda path: path.stat().st_mtime)


def hypr_env(hypr_dir: Path | None = None) -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault("XDG_RUNTIME_DIR", str(runtime_dir()))
    if hypr_dir is not None:
        env["HYPRLAND_INSTANCE_SIGNATURE"] = hypr_dir.name
    return env


def log(message: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with LOG_FILE.open("a", encoding="utf-8") as fh:
        fh.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")


def run(*args: str, capture: bool = False) -> subprocess.CompletedProcess[str]:
    hypr_dir = find_hypr_dir()
    return subprocess.run(
        ["hyprctl", *args],
        check=False,
        text=True,
        env=hypr_env(hypr_dir),
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )


def run_json(*args: str) -> object:
    result = run("-j", *args, capture=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"hyprctl {' '.join(args)} failed")
    return json.loads(result.stdout)


def load_state() -> str:
    try:
        return STATE_FILE.read_text(encoding="utf-8").strip() or "expanded"
    except FileNotFoundError:
        return "expanded"


def save_state(mode: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(f"{mode}\n", encoding="utf-8")


def get_spotify_client() -> dict[str, object] | None:
    clients = run_json("clients")
    if not isinstance(clients, list):
        return None

    spotify_clients = [
        client
        for client in clients
        if isinstance(client, dict) and str(client.get("class", "")) in SPOTIFY_CLASSES
    ]
    if not spotify_clients:
        return None

    focused = next((client for client in spotify_clients if client.get("focusHistoryID", 1) == 0), None)
    if focused:
        return focused

    workspace_match = next(
        (
            client
            for client in spotify_clients
            if str((client.get("workspace") or {}).get("name", "")) == DEFAULT_WORKSPACE
            or str((client.get("workspace") or {}).get("id", "")) == DEFAULT_WORKSPACE
        ),
        None,
    )
    return workspace_match or spotify_clients[0]


def get_monitor(name: str) -> dict[str, object] | None:
    monitors = run_json("monitors")
    if not isinstance(monitors, list):
        return None
    for monitor in monitors:
        if isinstance(monitor, dict) and str(monitor.get("name", "")) == name:
            return monitor
    return None


def launch_spotify() -> None:
    subprocess.Popen(
        ["fastpotify"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def ensure_spotify() -> dict[str, object]:
    client = get_spotify_client()
    if client:
        return client

    launch_spotify()
    for _ in range(80):
        time.sleep(0.15)
        client = get_spotify_client()
        if client:
            return client

    raise RuntimeError("Spotify window was not found")


def ensure_floating(address: str, is_floating: bool) -> None:
    if is_floating:
        return
    run("dispatch", "focuswindow", f"address:{address}")
    run("dispatch", "togglefloating")
    time.sleep(0.05)


def apply_mode(mode: str) -> None:
    client = ensure_spotify()
    address = str(client.get("address", ""))
    if not address:
        raise RuntimeError("Spotify window address was not found")

    monitor_name = str(client.get("monitor", ""))
    monitor = get_monitor(monitor_name)
    if not monitor:
        raise RuntimeError(f"Monitor {monitor_name!r} was not found")

    width = int(monitor.get("width", 0))
    height = int(monitor.get("height", 0))
    if width <= 0 or height <= 0:
        raise RuntimeError("Invalid monitor size")

    ensure_floating(address, bool(client.get("floating", False)))
    run("dispatch", "focuswindow", f"address:{address}")

    if mode == "mini":
        target_w = max(420, int(width * 0.42))
        target_h = max(140, int(height * 0.14))
        target_x = max(0, width - target_w - MINI_MARGIN_X)
        target_y = MINI_MARGIN_Y
    else:
        target_w = max(900, int(width * 0.82))
        target_h = max(900, int(height * 0.78))
        target_x = max(0, width - target_w - 24)
        target_y = max(0, int(height * 0.06))

    log(
        f"mode={mode} address={address} monitor={monitor_name} size={target_w}x{target_h} pos={target_x},{target_y}"
    )
    run("dispatch", "resizeactive", "exact", str(target_w), str(target_h))
    run("dispatch", "moveactive", "exact", str(target_x), str(target_y))
    save_state(mode)


def main() -> int:
    requested_mode = sys.argv[1] if len(sys.argv) > 1 else "toggle"

    if requested_mode not in {"toggle", "mini", "expanded"}:
        print("usage: SpotifyMiniPlayer.sh [toggle|mini|expanded]", file=sys.stderr)
        return 2

    try:
        if requested_mode == "toggle":
            target_mode = "mini" if load_state() == "expanded" else "expanded"
        else:
            target_mode = requested_mode
        apply_mode(target_mode)
    except Exception as exc:
        log(f"error: {exc}")
        print(f"SpotifyMiniPlayer: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
