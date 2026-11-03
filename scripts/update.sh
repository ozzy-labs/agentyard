#!/bin/bash
# scripts/update.sh
# Update only what agentyard installed (ADR-0007 §7).
# Usage: scripts/update.sh [--dry-run]
set -u

AGENTYARD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/load.sh
. "$AGENTYARD_ROOT/scripts/lib/load.sh"

DRY_RUN=0
case "${1:-}" in
--dry-run) DRY_RUN=1 ;;
-h | --help)
  cat <<'EOF'
Usage: ./install.sh update [--dry-run]

agentyard が入れたものだけを更新します:
  - mise 本体（mise self-update）と、agentyard が mise に追加したツール
  - agentyard が uv tool で入れたもの（markitdown）
  - 自動更新しないエージェント（Codex CLI、Copilot CLI、Gemini CLI）
  - agentyard の Brewfile に記録したもの（macOS）
  - ~/.agents/AGENTS.md のホスト環境ブロックと env.sh / interactive.sh
apt のパッケージは OS 全体の更新として 'sudo apt update && sudo apt upgrade' で更新してください。
EOF
  exit 0
  ;;
"") ;;
*)
  log_error "不明な引数: $1"
  exit 1
  ;;
esac

run() {
  # run <label> <cmd...>
  local label="$1"
  shift
  if [ "$DRY_RUN" = "1" ]; then
    printf '  [dry-run] %s: %s\n' "$label" "$*"
    return 0
  fi
  if "$@" >/dev/null 2>&1; then log_ok "$label"; else log_warn "$label の更新に失敗しました"; fi
}

printf '🔄 agentyard update (%s)\n' "$AGENTYARD_VERSION"
session_path_setup

log_section "agentyard"
latest="$(latest_release_version)"
if [ -n "$latest" ] && [ "$latest" != "$AGENTYARD_VERSION" ]; then
  log_warn "agentyard の新しいリリースがあります: $latest（現在 $AGENTYARD_VERSION）"
  log_info "固定バージョンのツールの更新は、新しいリリースで './install.sh --ref v$latest install' を実行すると反映されます。"
else
  log_skip "agentyard は最新です"
fi

log_section "mise"
if [ -x "$MISE_BIN" ]; then
  if mise_is_official_install; then
    run "mise 本体" "$MISE_BIN" self-update -y
  else
    log_skip "mise 本体（$MISE_BIN）は、入れた方法（apt / Homebrew など）で更新してください"
  fi
  for tool in $(state_list mise); do
    run "$tool" mise_at_home upgrade "$tool"
  done
else
  log_skip "mise が見つかりません"
fi

log_section "uv tool"
for tool in $(state_list uv-tool); do
  run "$tool" uv tool upgrade "$tool"
done

log_section "AI エージェント"
if [ "$DRY_RUN" = "1" ]; then
  printf '  [dry-run] update_agents: %s\n' "$(state_list agent | tr '\n' ' ')"
else
  update_agents
fi

if [ "$(os_kind)" = "macos" ] && [ -s "$(agentyard_brewfile)" ]; then
  log_section "Homebrew (agentyard の Brewfile)"
  run "brew bundle" brew bundle install --upgrade --file="$(agentyard_brewfile)"
fi

if [ "$DRY_RUN" = "0" ]; then
  log_section "設定ファイル"
  agents_md_refresh
  shellenv_write_files
  log_ok "AGENTS.md のホスト環境ブロックと env.sh / interactive.sh を更新しました"
fi

if [ "$(os_kind)" = "linux" ]; then
  log_info "apt のパッケージは 'sudo apt update && sudo apt upgrade' で更新してください。"
fi
