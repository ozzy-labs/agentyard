#!/bin/bash
# scripts/setup.sh
# agentyard install (ADR-0007). Ubuntu 24.04 / 26.04 and macOS 26 / 27.
# Usage: scripts/setup.sh   (normally via ./install.sh install)
set -eu

AGENTYARD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/load.sh
. "$AGENTYARD_ROOT/scripts/lib/load.sh"

if [ -n "${SETUP_LOG:-}" ]; then
  case "$SETUP_LOG" in
  1 | true) LOG_FILE="$HOME/agentyard-setup-$(date +%Y%m%d-%H%M%S).log" ;;
  *) LOG_FILE="$SETUP_LOG" ;;
  esac
  exec > >(tee -a "$LOG_FILE") 2>&1
  log_info "ログ: $LOG_FILE"
fi

printf '🚀 agentyard %s\n' "$AGENTYARD_VERSION"
support_gate
attach_tty_if_needed
session_path_setup

select_components
# Ask everything now, so the install itself runs without stopping.
collect_answers
if ! is_non_interactive; then
  ask_yes_no "この内容でインストールを開始しますか？" y || {
    log_info "中止しました"
    exit 0
  }
fi

FAILED=""
run_step() {
  # run_step <label> <function...>: keep going on failure, report at the end.
  local label="$1"
  shift
  if ! "$@"; then
    FAILED="${FAILED:+$FAILED, }$label"
    log_warn "$label でエラーが発生しました（続行します）"
  fi
}

case "$(os_kind)" in
linux)
  ubuntu_prerequisites
  run_step "既定のツール" ubuntu_base_tools
  ;;
macos)
  macos_prerequisites
  run_step "既定のツール" macos_base_tools
  ;;
esac

run_step "ランタイム" install_runtimes
run_step "AI エージェント" install_agents

selected docker && run_step "Docker" install_docker
selected docker-group && run_step "docker グループ" install_docker_group
selected zsh && run_step "zsh" install_zsh
selected zsh-login-shell && run_step "ログインシェル" install_zsh_login_shell
selected tmux && run_step "tmux" install_tmux
selected zellij && run_step "zellij" install_zellij
selected aws && run_step "AWS CLI" install_aws
selected azure && run_step "Azure CLI" install_azure
selected gcloud && run_step "Google Cloud CLI" install_gcloud
selected ast-grep && run_step "ast-grep" install_ast_grep
selected yq && run_step "yq" install_yq
selected markitdown && run_step "markitdown" install_markitdown
selected bun && run_step "Bun" install_bun
selected apparmor && run_step "AppArmor" install_apparmor
selected wsl-browser && run_step "WSL のブラウザ連携" install_wsl_browser
selected mise-trust && run_step "mise の信頼設定" install_mise_trust

run_step "Git" configure_git
run_step "GitHub CLI" configure_gh
# AGENTS.md last: the host block lists the tools installed above.
selected agents-md && run_step "AGENTS.md" install_agents_md
# Shell files last: env.sh content depends on the settings recorded above.
run_step "シェル設定" shellenv_setup

state_add setting version "$AGENTYARD_VERSION"

log_section "完了"
if [ -n "$FAILED" ]; then
  log_warn "一部の手順でエラーがありました: $FAILED"
fi
cat <<'EOF'

次のステップ:
  1. ターミナルを開き直す（または: exec "$SHELL" -l）
  2. 各エージェントにログインする（claude / codex / copilot / agy / gemini を起動）
  3. 状態を確認する: ./install.sh doctor
EOF
[ -z "$FAILED" ]
