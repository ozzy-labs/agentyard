#!/bin/bash
# scripts/lib/shellenv.sh
# Two-layer shell integration (ADR-0007 §6):
#   env.sh          POSIX sh. PATH, mise shims, Homebrew, Copilot dirs, BROWSER.
#                   Sourced from login profiles so non-interactive and
#                   non-login processes inherit it.
#   interactive.sh  bash / zsh. Sources env.sh, then `mise activate` and fzf
#                   key bindings. Sourced from ~/.bashrc / ~/.zshrc.
# Follows mise's documented recommendation: shims in login profiles,
# `mise activate` in interactive rc files.
#   https://mise.jdx.dev/dev-tools/shims.html
# Requires lib/core.sh, lib/state.sh, lib/block.sh.

shellenv_env_path() { printf '%s/env.sh' "$AGENTYARD_CONFIG_DIR"; }
shellenv_interactive_path() { printf '%s/interactive.sh' "$AGENTYARD_CONFIG_DIR"; }

# Render env.sh (POSIX sh). Optional sections depend on state.
shellenv_render_env() {
  cat <<'EOF'
# Managed by agentyard. Regenerated on install / update; do not edit.
# POSIX sh: sourced from login profiles (~/.profile, ~/.zprofile, ...).
_agentyard_prepend() {
  case ":$PATH:" in
  *":$1:"*) ;;
  *) [ -d "$1" ] && PATH="$1:$PATH" ;;
  esac
}
if [ -x /opt/homebrew/bin/brew ] && [ -z "${HOMEBREW_PREFIX:-}" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv bash 2>/dev/null || /opt/homebrew/bin/brew shellenv)"
fi
_agentyard_prepend "$HOME/.local/bin"
_agentyard_prepend "${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
export PATH
unset -f _agentyard_prepend
EOF
  if state_has setting copilot-dirs; then
    cat <<'EOF'
# GitHub Copilot CLI: also read ~/.agents/AGENTS.md (comma-separated list).
case ",${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:-}," in
*",$HOME/.agents,"*) ;;
*) COPILOT_CUSTOM_INSTRUCTIONS_DIRS="${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:+$COPILOT_CUSTOM_INSTRUCTIONS_DIRS,}$HOME/.agents" ;;
esac
export COPILOT_CUSTOM_INSTRUCTIONS_DIRS
EOF
  fi
  if state_has setting wsl-browser; then
    cat <<'EOF'
# WSL: open login pages in the Windows default browser.
if [ -z "${BROWSER:-}" ] && [ -x "$HOME/.local/bin/agentyard-wsl-browser" ]; then
  BROWSER="$HOME/.local/bin/agentyard-wsl-browser"
  export BROWSER
fi
EOF
  fi
}

shellenv_render_interactive() {
  cat <<'EOF'
# Managed by agentyard. Regenerated on install / update; do not edit.
# Interactive bash / zsh only.
[ -r "$HOME/.config/agentyard/env.sh" ] && . "$HOME/.config/agentyard/env.sh"
if [ -n "${ZSH_VERSION:-}" ]; then
  _agentyard_shell=zsh
elif [ -n "${BASH_VERSION:-}" ]; then
  _agentyard_shell=bash
else
  _agentyard_shell=""
fi
if [ -n "$_agentyard_shell" ]; then
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate "$_agentyard_shell")"
  fi
  # fzf key bindings: built-in integration (fzf >= 0.48), else the files
  # shipped by the Ubuntu 24.04 package (fzf 0.44).
  if command -v fzf >/dev/null 2>&1; then
    if fzf "--$_agentyard_shell" >/dev/null 2>&1; then
      eval "$(fzf "--$_agentyard_shell")"
    elif [ -r "/usr/share/doc/fzf/examples/key-bindings.$_agentyard_shell" ]; then
      . "/usr/share/doc/fzf/examples/key-bindings.$_agentyard_shell"
    fi
  fi
fi
unset _agentyard_shell
EOF
}

# Write env.sh / interactive.sh (regenerated every run).
shellenv_write_files() {
  local tmp
  mkdir -p "$AGENTYARD_CONFIG_DIR"
  tmp="$(mktemp)"
  shellenv_render_env >"$tmp"
  cmp -s "$tmp" "$(shellenv_env_path)" 2>/dev/null || {
    cat "$tmp" >"$(shellenv_env_path)"
    SHELLENV_CHANGED=1
  }
  shellenv_render_interactive >"$tmp"
  cmp -s "$tmp" "$(shellenv_interactive_path)" 2>/dev/null || {
    cat "$tmp" >"$(shellenv_interactive_path)"
    SHELLENV_CHANGED=1
  }
  rm -f "$tmp"
}

_shellenv_env_line() {
  printf '%s' '[ -r "$HOME/.config/agentyard/env.sh" ] && . "$HOME/.config/agentyard/env.sh"'
}

_shellenv_interactive_line() {
  printf '%s' '[ -r "$HOME/.config/agentyard/interactive.sh" ] && . "$HOME/.config/agentyard/interactive.sh"'
}

# Login profile used by bash on Linux. bash reads only the first existing of
# ~/.bash_profile, ~/.bash_login, ~/.profile. Never create ~/.bash_profile on
# Ubuntu (it would stop ~/.profile from loading).
_shellenv_linux_bash_login() {
  if [ -f "$HOME/.bash_profile" ]; then
    printf '%s/.bash_profile' "$HOME"
  elif [ -f "$HOME/.bash_login" ]; then
    printf '%s/.bash_login' "$HOME"
  else
    printf '%s/.profile' "$HOME"
  fi
}

# Wire managed blocks into the rc files of shells present on this host.
SHELLENV_CHANGED=0
_shellenv_upsert() {
  block_upsert "$1" "$2"
  [ "$BLOCK_CHANGED" = "1" ] && SHELLENV_CHANGED=1
  return 0
}

shellenv_wire_rc_files() {
  local env_line interactive_line
  env_line="$(_shellenv_env_line)"
  interactive_line="$(_shellenv_interactive_line)"

  case "$(os_kind)" in
  linux)
    _shellenv_upsert "$(_shellenv_linux_bash_login)" "$env_line"
    _shellenv_upsert "$HOME/.bashrc" "$interactive_line"
    if has_cmd zsh; then
      _shellenv_upsert "$HOME/.zprofile" "$env_line"
      _shellenv_upsert "$HOME/.zshrc" "$interactive_line"
    fi
    ;;
  macos)
    # zsh is the default shell on macOS.
    _shellenv_upsert "$HOME/.zprofile" "$env_line"
    _shellenv_upsert "$HOME/.zshrc" "$interactive_line"
    # bash only when the user already uses it.
    if [ -f "$HOME/.bash_profile" ]; then
      _shellenv_upsert "$HOME/.bash_profile" "$env_line"
    fi
    if [ -f "$HOME/.bashrc" ]; then
      _shellenv_upsert "$HOME/.bashrc" "$interactive_line"
    fi
    ;;
  esac
}

shellenv_setup() {
  log_section "シェル設定"
  SHELLENV_CHANGED=0
  shellenv_write_files
  shellenv_wire_rc_files
  if [ "$SHELLENV_CHANGED" = "1" ]; then
    log_ok "env.sh / interactive.sh とシェル設定ファイルのブロックを更新しました"
  else
    log_skip "シェル設定は最新です"
  fi
}
