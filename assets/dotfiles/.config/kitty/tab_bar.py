"""Custom tab bar drawing with project path & animated spinner for OpenCode."""

import os
import time
from kitty.fast_data_types import add_timer, get_boss
from kitty.tab_bar import draw_tab_with_fade

# Frames de animação do spinner (Braille dots fluido)
SPINNER_FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

_timer_started = False


def _on_spinner_tick(timer_id):
    boss = get_boss()
    if not boss:
        return
    for tm in getattr(boss, "os_window_map", {}).values():
        if hasattr(tm, "mark_tab_bar_dirty"):
            tm.mark_tab_bar_dirty()


def _ensure_animation_timer():
    global _timer_started
    if not _timer_started:
        _timer_started = True
        try:
            add_timer(_on_spinner_tick, 0.1, True)
        except Exception:
            pass


def _is_omni_tab(tab):
    kitty_tab = get_boss().tab_for_id(tab.tab_id)
    return bool(
        kitty_tab
        and any(window.user_vars.get("omniroute_title") == "1" for window in kitty_tab)
    )


def _get_tab_display_title(tab):
    boss = get_boss()
    if not boss:
        return tab.title

    kitty_tab = boss.tab_for_id(tab.tab_id)
    if not kitty_tab:
        return tab.title

    window = kitty_tab.active_window or (kitty_tab.windows[0] if kitty_tab.windows else None)
    if not window:
        return tab.title

    cwd = getattr(window, "cwd", None) or getattr(window, "user_vars", {}).get("PWD", "")
    project_name = os.path.basename(cwd.rstrip("/")) if cwd else ""

    # Verifica se a aba está executando o OpenCode
    is_opencode = False
    if tab.title.startswith("OC |") or tab.title.startswith("OpenCode"):
        is_opencode = True
    else:
        fg_procs = getattr(window.child, "foreground_processes", [])
        for p in fg_procs:
            cmd = " ".join(p.get("cmdline", []))
            if "opencode" in cmd:
                is_opencode = True
                break

    if is_opencode and project_name:
        # Detecta se o OpenCode está ocupado (gerando resposta / executando tools)
        try:
            screen_text = window.as_text()
            is_busy = "esc interrupt" in screen_text or "······" in screen_text
        except Exception:
            is_busy = False

        if is_busy:
            _ensure_animation_timer()
            frame = SPINNER_FRAMES[int(time.time() * 10) % len(SPINNER_FRAMES)]
            return f"{frame} {project_name}"
        else:
            return project_name

    return tab.title


def draw_tab(
    draw_data,
    screen,
    tab,
    before,
    max_tab_length,
    index,
    is_last,
    extra_data,
):
    if _is_omni_tab(tab):
        draw_data = draw_data._replace(max_tab_title_length=0)

    # Substitui o título da aba dinamicamente
    new_title = _get_tab_display_title(tab)
    tab = tab._replace(title=new_title)

    return draw_tab_with_fade(
        draw_data,
        screen,
        tab,
        before,
        max_tab_length,
        index,
        is_last,
        extra_data,
    )
