#!/bin/bash
# scripts/lib/mise.sh
# mise bootstrap and agentyard-owned global tools (ADR-0007 §4).
# mise is installed with its official installer on both Linux and macOS:
#   https://mise.jdx.dev/installing-mise.html
# Requires lib/core.sh, lib/state.sh.

MISE_BIN="${MISE_BIN:-$HOME/.local/bin/mise}"
# A mise installed some other way (mise apt repo, Homebrew, ...) is reused
# instead of installing a second copy.
if [ ! -x "$MISE_BIN" ] && command -v mise >/dev/null 2>&1; then
  MISE_BIN="$(command -v mise)"
fi

# True when mise came from the official installer (self-update applies).
mise_is_official_install() {
  [ "$MISE_BIN" = "$HOME/.local/bin/mise" ]
}
AGENTYARD_TOOLS_FILE="${AGENTYARD_TOOLS_FILE:-}"

# tools_version <name>  -> version spec from config/tools.toml
tools_version() {
  local name="$1" file="${AGENTYARD_TOOLS_FILE}"
  [ -n "$file" ] && [ -f "$file" ] || return 1
  awk -v n="$name" '
    /^\[/ { in_tools = ($0 == "[tools]"); next }
    in_tools && $0 ~ "^\"?" n "\"?[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*"/, ""); sub(/".*$/, ""); print; exit
    }
  ' "$file"
}

# Run mise from $HOME so a repository-local mise.toml never interferes.
mise_at_home() {
  (cd "$HOME" && "$MISE_BIN" "$@")
}

ensure_mise() {
  if [ -x "$MISE_BIN" ]; then
    if mise_is_official_install; then
      log_skip "mise は導入済みです ($("$MISE_BIN" --version 2>/dev/null | head -n1))"
    else
      log_skip "mise は $MISE_BIN にあります（その入れ方で更新してください）"
    fi
    return 0
  fi
  log_info "mise を公式インストーラで導入します"
  run_remote_installer https://mise.run sh >/dev/null || die "mise のインストールに失敗しました"
  MISE_BIN="$HOME/.local/bin/mise"
  state_add component mise
  log_ok "mise を導入しました"
}

# mise_global <tool> [spec]
# Adds <tool>@<spec> to the global config unless the user already manages
# <tool> there (then the user's entry wins and agentyard does not record it).
mise_global() {
  local tool="$1" spec="${2:-}"
  [ -n "$spec" ] || spec="$(tools_version "$tool")" || spec="latest"
  [ -n "$spec" ] || spec="latest"
  if mise_at_home ls --global --json 2>/dev/null | grep -q "\"$tool\":"; then
    if ! state_has mise "$tool"; then
      log_skip "$tool は mise のグローバル設定に既にあります（ユーザー設定を優先）"
      return 0
    fi
    if [ "$(state_get mise "$tool" 3)" = "$spec" ]; then
      log_skip "$tool@$spec (mise)"
      return 0
    fi
  fi
  if quiet_run mise_at_home use --global "$tool@$spec"; then
    state_add mise "$tool" "$spec"
    log_ok "$tool@$spec (mise)"
  else
    log_warn "$tool@$spec の導入に失敗しました（手動: mise use -g $tool@$spec）"
    return 1
  fi
}

install_runtimes() {
  log_section "ランタイム (mise)"
  ensure_mise
  session_path_setup
  mise_global node
  mise_global pnpm
  mise_global uv
}
