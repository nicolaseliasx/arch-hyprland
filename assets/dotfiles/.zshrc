# p10k instant prompt must run before slower shell initialization.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

# XDG locations for zsh state and cache
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"

source $ZSH/oh-my-zsh.sh

# NVM (lazy): default version goes straight to PATH; `nvm` loads on first use.
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/alias/default" ]]; then
  _nvm_default=$(<"$NVM_DIR/alias/default")
  if [[ $_nvm_default == <-> ]]; then
    _nvm_versions=("$NVM_DIR"/versions/node/v${_nvm_default}.*(N))
    if (( ${#_nvm_versions} )); then
      _nvm_selected=$(printf '%s\n' "${_nvm_versions[@]}" | sort -V | tail -n 1)
      export NVM_BIN="$_nvm_selected/bin"
      export NVM_INC="$_nvm_selected/include/node"
      path=("$NVM_BIN" "${path[@]}")
    fi
  fi
  unset _nvm_default _nvm_versions _nvm_selected
fi
nvm() {
  unfunction nvm
  [[ -s /usr/share/nvm/init-nvm.sh ]] && source /usr/share/nvm/init-nvm.sh --no-use
  nvm "$@"
}

# PATH
export PATH="$HOME/.local/bin:$PATH"

# SDKMAN! (lazy): candidate binaries go straight to PATH; full `sdk` loads on first use.
export SDKMAN_DIR="$HOME/.sdkman"
_sdkman_bins=(~/.sdkman/candidates/*/current/bin(N))
(( ${#_sdkman_bins} )) && path=("${_sdkman_bins[@]}" "${path[@]}")
unset _sdkman_bins
sdk() {
  unfunction sdk
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
  sdk "$@"
}

# Directory jumping (cached; regenerate with: zoxide init zsh >| ~/.cache/zsh/zoxide-init.zsh)
_zoxide_init="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zoxide-init.zsh"
[[ -s $_zoxide_init ]] || zoxide init zsh >| $_zoxide_init
source $_zoxide_init
unset _zoxide_init

# Load p10k config
[[ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/p10k.zsh" ]] || source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/p10k.zsh"

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# OmniRoute shortcuts
alias start-omniroute="omniroute-start"
alias stop-omniroute="omniroute-stop"

start() {
  if [[ "${1:-}" == "omniroute" || "${1:-}" == "omni" ]]; then
    omniroute-start
  else
    echo "Uso: start omniroute"
  fi
}

stop() {
  if [[ "${1:-}" == "omniroute" || "${1:-}" == "omni" ]]; then
    omniroute-stop
  else
    echo "Uso: stop omniroute"
  fi
}


# ─── AGY model switchers ─────────────────────────────────────────────────────
# agys → Claude Sonnet 4.6 (Thinking)
# agyg → Gemini 3.1 Pro
agys() {
  python3 - <<'EOF'
import json, pathlib
s = pathlib.Path("~/.gemini/antigravity-cli/settings.json").expanduser()
d = json.loads(s.read_text())
d["model"] = "Claude Sonnet 4.6 (Thinking)"
s.write_text(json.dumps(d, indent=4))
print("✓ Model → Claude Sonnet 4.6 (Thinking)")
EOF
  agy "$@"
}

agyg() {
  python3 - <<'EOF'
import json, pathlib
s = pathlib.Path("~/.gemini/antigravity-cli/settings.json").expanduser()
d = json.loads(s.read_text())
d["model"] = "Gemini 3.1 Pro (High)"
s.write_text(json.dumps(d, indent=4))
print("✓ Model → Gemini 3.1 Pro (High)")
EOF
  agy "$@"
}
# ─────────────────────────────────────────────────────────────────────────────

# >>> dual Codex accounts >>>
# `codex` preserva a conta pessoal atual em ~/.codex.
# `codex2` usa credenciais/config proprios e compartilha sessoes com `codex`.
unalias codex2 2>/dev/null
codex2() {
  local -x CODEX_SQLITE_HOME="$HOME/.codex"
  __cf_codex_run "$HOME/.codex2" "$@"
}
# <<< dual Codex accounts <<<

export PATH="$HOME/development/flutter/bin:$PATH"

# >>> flow opencode-skills >>>
export OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1
# <<< flow opencode-skills <<<

# >>> flow shell >>>
source "$HOME/documents/workspace/workflow/packages/pec-workflow/shell/init.zsh"
# <<< flow shell <<<

# >>> neovim-workspace >>>
nvim() {
  if (( $# == 0 )); then
    nvim-workspace "$PWD"
  elif (( $# == 1 )) && [[ -d "$1" ]]; then
    nvim-workspace "$1"
  else
    command nvim "$@"
  fi
}
diff() {
  if (( $# > 1 )); then
    command diff "$@"
  elif (( $# == 1 )); then
    nvim-workspace "$1"
  else
    nvim-workspace "$PWD"
  fi
}
# <<< neovim-workspace <<<
