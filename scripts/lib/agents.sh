#!/bin/bash
# scripts/lib/agents.sh
# AI agent CLIs (ADR-0007 §4). Always latest; installed with each vendor's
# officially recommended method. agentyard only installs agents and never
# drives them (Antigravity's terms forbid third-party tools accessing it).
#
#   claude       https://code.claude.com/docs/en/setup            (auto-updates)
#   codex        https://learn.chatgpt.com/docs/codex/cli         (update: rerun installer)
#   copilot      https://docs.github.com/en/copilot/how-tos/copilot-cli (update: copilot update)
#   antigravity  https://antigravity.google/download              (auto-updates)
#   gemini       https://geminicli.com/docs/get-started/installation
#                npm package, installed through mise's npm backend so it
#                does not disappear when the Node version changes. The brew
#                formula is deprecated (2026-06-18).
# Requires lib/core.sh, lib/state.sh, lib/mise.sh.

agent_bin() {
  case "$1" in
  claude) printf 'claude' ;;
  codex) printf 'codex' ;;
  copilot) printf 'copilot' ;;
  antigravity) printf 'agy' ;;
  gemini) printf 'gemini' ;;
  esac
}

agent_label() {
  case "$1" in
  claude) printf 'Claude Code' ;;
  codex) printf 'Codex CLI' ;;
  copilot) printf 'GitHub Copilot CLI' ;;
  antigravity) printf 'Antigravity CLI' ;;
  gemini) printf 'Gemini CLI' ;;
  esac
}

# True when the agent's binary is on PATH (ignoring VS Code's copilot shim).
agent_present() {
  local bin path
  bin="$(agent_bin "$1")"
  path="$(command -v "$bin" 2>/dev/null)" || return 1
  case "$path" in *".vscode-server"*) return 1 ;; esac
  return 0
}

# Agents installed via npm under a mise-managed Node (agentyard <= v0.4.x).
_agent_npm_legacy_path() {
  local path
  path="$(command -v "$(agent_bin "$1")" 2>/dev/null)" || return 1
  case "$path" in
  */mise/installs/node/* | */mise/shims/*) return 0 ;;
  esac
  return 1
}

# True when the agent sits exactly where agentyard's own install method puts
# it: ~/.local/bin for the vendor installers, a mise shim for gemini.
_agent_at_agentyard_path() {
  local path
  path="$(command -v "$(agent_bin "$1")" 2>/dev/null)" || return 1
  case "$1" in
  gemini)
    case "$path" in
    */mise/shims/* | */mise/installs/*) return 0 ;;
    esac
    return 1
    ;;
  *) [ "$path" = "$HOME/.local/bin/$(agent_bin "$1")" ] ;;
  esac
}

# Vendor installers do more than install. codex ends by offering to launch the
# CLI, copilot by offering to edit a shell rc file; both read /dev/tty
# directly, so neither redirecting output nor piping stdin suppresses them,
# and what they do decides the installer's exit status. Each agent therefore
# states how to run its installer unattended.
_agent_install() {
  case "$1" in
  claude) run_remote_installer https://claude.ai/install.sh bash ;;
  codex)
    # Ends with "Start Codex now? [y/N]" read from /dev/tty; accepting it runs
    # the TUI and that exit status becomes the installer's, so the install is
    # reported as failed even though the binary is in place.
    # CODEX_NON_INTERACTIVE=1 skips the prompts only — the installer still
    # sets up PATH. https://releases.openai.com/codex/install.sh
    (
      export CODEX_NON_INTERACTIVE=1
      run_remote_installer https://chatgpt.com/codex/install.sh sh
    )
    ;;
  # Asks "Would you like to add it to <rc file>?" only when copilot is not
  # already on PATH after the install; install_agent puts ~/.local/bin on PATH
  # first, so the question never comes up and agentyard keeps owning PATH.
  copilot) run_remote_installer https://gh.io/copilot-install bash ;;
  antigravity) run_remote_installer https://antigravity.google/cli/install.sh bash ;;
  gemini) mise_global "npm:@google/gemini-cli" latest ;;
  esac
}

install_agent() {
  local id="$1" label rc=0
  label="$(agent_label "$id")"
  if agent_present "$id"; then
    if [ "$id" = "codex" ] && _agent_npm_legacy_path codex; then
      log_warn "$label は npm（mise の Node 配下）で入っています。Node を更新すると消えるため、公式インストーラへの切り替えを推奨します: npm uninstall -g @openai/codex && agentyard を再実行"
    elif ! state_has agent "$id" && _agent_at_agentyard_path "$id"; then
      # Selected by the user, sitting where agentyard's own method installs it,
      # yet unrecorded (e.g. an install that was wrongly reported as failed).
      # Record it so update covers it; update uses the vendor's own updater.
      state_add agent "$id"
    fi
    log_skip "$label は導入済みです"
    return 0
  fi
  log_info "$label を公式の方法で導入します"
  # Before the installer: vendor scripts look at PATH to decide whether to
  # offer rc-file edits, and the binary must be visible right after.
  session_path_setup
  quiet_run _agent_install "$id" || rc=$?
  hash -r 2>/dev/null || true
  # Judge the outcome by the binary first: what an installer does after
  # installing (launching the CLI, offering a shell edit) must not turn a
  # working install into a reported failure. Only a failed installer with
  # nothing to show for it is an error.
  if agent_present "$id"; then
    [ "$rc" -eq 0 ] || log_warn "$label のインストーラは exit $rc で終了しましたが、$(agent_bin "$id") は使えます"
    state_add agent "$id"
    log_ok "$label を導入しました"
    return 0
  fi
  if [ "$rc" -eq 0 ]; then
    # All five agents install onto a PATH entry agentyard sets up, so this is
    # unexpected — but the installer reported success, so trust it rather than
    # calling a finished install a failure.
    state_add agent "$id"
    log_warn "$label を導入しましたが、$(agent_bin "$id") がこのセッションの PATH に見つかりません。新しいターミナルで確認してください"
    return 0
  fi
  log_error "$label のインストールに失敗しました"
  return 1
}

install_agents() {
  log_section "AI エージェント"
  local id failed=0
  for id in claude codex copilot antigravity gemini; do
    selected "$id" || continue
    install_agent "$id" || failed=1
  done
  return "$failed"
}

# Update agents that do not auto-update. Only agentyard-installed ones.
update_agents() {
  local id
  for id in $(state_list agent); do
    agent_present "$id" || continue
    case "$id" in
    codex)
      log_info "Codex CLI を更新します（公式インストーラを再実行）"
      quiet_run _agent_install codex && log_ok "Codex CLI" || log_warn "Codex CLI の更新に失敗しました"
      ;;
    copilot)
      copilot update >/dev/null 2>&1 && log_ok "GitHub Copilot CLI" || log_warn "GitHub Copilot CLI の更新に失敗しました"
      ;;
    gemini)
      mise_at_home upgrade "npm:@google/gemini-cli" >/dev/null 2>&1 && log_ok "Gemini CLI" || log_warn "Gemini CLI の更新に失敗しました"
      ;;
    claude | antigravity)
      log_skip "$(agent_label "$id") は自動更新されます"
      ;;
    esac
  done
}
