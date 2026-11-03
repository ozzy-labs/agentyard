#!/bin/bash
# scripts/doctor.sh
# shellcheck disable=SC2088  # "~/" appears literally in messages and file contents
# Diagnose the host (ADR-0007 §7). Exit code: 0 ok, 1 warnings, 2 errors.
# Usage: scripts/doctor.sh [--repo <path>]
set -u

AGENTYARD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/load.sh
. "$AGENTYARD_ROOT/scripts/lib/load.sh"

WARNINGS=0
ERRORS=0
ok() { printf '  ✅ %s\n' "$*"; }
warn() {
  printf '  ⚠️  %s\n' "$1"
  [ -n "${2:-}" ] && printf '      → %s\n' "$2"
  WARNINGS=$((WARNINGS + 1))
}
err() {
  printf '  ❌ %s\n' "$1"
  [ -n "${2:-}" ] && printf '      → %s\n' "$2"
  ERRORS=$((ERRORS + 1))
}
info() { printf '  ℹ️  %s\n' "$*"; }

# ---------------------------------------------------------------------------
check_platform() {
  log_section "プラットフォーム"
  local reason
  if reason="$(support_check_reason)"; then
    ok "サポート対象です"
  else
    err "$reason"
  fi
}

check_tools() {
  log_section "既定のツール"
  local t tools="git git-lfs gh jq rg tree fzf fd mise node pnpm uv"
  [ "$(os_kind)" = "linux" ] && tools="$tools bwrap socat"
  for t in $tools; do
    if has_cmd "$t"; then ok "$t"; else err "$t が見つかりません" "./install.sh install を再実行してください"; fi
  done
}

# Tools must also resolve from login and interactive shells started from a
# clean environment (this is what agents, IDEs and cron-like launchers see).
check_shell_env() {
  log_section "シェル環境"
  local t missing_login="" missing_interactive=""
  for t in mise node uv; do
    env -i HOME="$HOME" USER="$(id -un)" TERM=dumb bash -lc "command -v $t" >/dev/null 2>&1 ||
      missing_login="$missing_login $t"
    env -i HOME="$HOME" USER="$(id -un)" TERM=dumb bash -ic "command -v $t" >/dev/null 2>&1 ||
      missing_interactive="$missing_interactive $t"
  done
  if [ -z "$missing_login" ]; then ok "ログインシェル (bash -l) から見える"; else warn "ログインシェルから見えません:$missing_login" "ログイン時の設定ファイルに agentyard のブロックがあるか確認してください"; fi
  if [ -z "$missing_interactive" ]; then ok "対話シェル (bash -i) から見える"; else warn "対話シェルから見えません:$missing_interactive" "~/.bashrc に agentyard のブロックがあるか確認してください"; fi

  local dups
  dups="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -v '^$' | sort | uniq -d)"
  if [ -z "$dups" ]; then
    ok "PATH に重複はありません"
  else
    warn "PATH に重複があります: $(printf '%s' "$dups" | tr '\n' ' ')" "公式インストーラ（Antigravity など）が追記した PATH 設定と重複していないか確認してください"
  fi
}

check_agents() {
  log_section "AI エージェント"
  local id any=0 ver
  for id in claude codex copilot antigravity gemini; do
    agent_present "$id" || continue
    any=1
    ver="$("$(agent_bin "$id")" --version 2>/dev/null | head -n1)"
    ok "$(agent_label "$id"): ${ver:-バージョン不明}"
  done
  [ "$any" = "1" ] || warn "AI エージェントが見つかりません" "./install.sh install で選んでください"
  if agent_present claude; then
    # Reading AGENTS.md natively requires v2.1.281+ for all session types.
    ver="$(claude --version 2>/dev/null | awk '{ print $1 }')"
    if [ -n "$ver" ] && ! _version_ge "$ver" 2.1.281; then
      warn "Claude Code $ver は AGENTS.md をすべての環境で読めません（2.1.281 以上が必要）" "claude update"
    fi
  fi
  if has_cmd gh; then
    if gh auth status >/dev/null 2>&1; then ok "GitHub CLI: ログイン済み"; else warn "GitHub CLI: 未ログイン" "gh auth login"; fi
  fi
}

# _version_ge <a> <b>: a >= b (dotted numeric)
_version_ge() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]
}

check_sandbox() {
  [ "$(os_kind)" = "linux" ] || return 0
  log_section "サンドボックス (Linux)"
  if ! has_cmd bwrap; then
    err "bubblewrap がありません" "./install.sh install"
    return
  fi
  if bwrap --ro-bind / / --dev /dev --proc /proc --unshare-user true >/dev/null 2>&1; then
    ok "bubblewrap でサンドボックスを作成できます"
  else
    if apparmor_applicable; then
      err "bubblewrap がユーザー名前空間を作れません（Ubuntu 24.04 の AppArmor の制限）" "AGENTYARD_WITH=apparmor ./install.sh install（制限を bwrap について緩めます）"
    else
      err "bubblewrap がユーザー名前空間を作れません" "コンテナ内では外側の設定が必要です"
    fi
  fi
  has_cmd socat && ok "socat" || err "socat がありません（Claude Code のサンドボックスに必要）" "./install.sh install"
  info "サンドボックスを起動できないとき、エージェントによってはサンドボックスなしで実行を続けます。止めたい場合は各エージェントの設定を確認してください（例: Claude Code の sandbox.failIfUnavailable）。"
}

check_agents_md() {
  log_section "AGENTS.md (ユーザースコープ)"
  local src
  src="$(agents_md_source)"
  if [ ! -f "$src" ]; then
    info "$src はありません（AGENTYARD_WITH=agents-md で作成できます）"
    return
  fi
  ok "$src"
  if agent_present claude; then
    if grep -qF '@~/.agents/AGENTS.md' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md" 2>/dev/null; then ok "Claude Code: 連携済み（確実）"; else warn "Claude Code: 未連携" "./install.sh install"; fi
  fi
  _doctor_link_or_ref "Codex" "${CODEX_HOME:-$HOME/.codex}/AGENTS.md" codex
  if [ -f "${CODEX_HOME:-$HOME/.codex}/AGENTS.override.md" ]; then
    warn "Codex: AGENTS.override.md があるため ~/.codex/AGENTS.md は読まれません"
  fi
  _doctor_link_or_ref "Gemini CLI" "$HOME/.gemini/GEMINI.md" gemini
  if agent_present antigravity; then
    if grep -qF '](~/.agents/AGENTS.md)' "$HOME/.gemini/AGENTS.md" 2>/dev/null; then
      ok "Antigravity CLI: 連携済み（確実）"
      if [ -L "$HOME/.gemini/GEMINI.md" ] && [ "$(readlink "$HOME/.gemini/GEMINI.md")" = "$src" ]; then
        warn "Antigravity CLI: GEMINI.md と AGENTS.md の両方から正本を読み込んでいます（二重読み込み）"
      fi
    elif [ -L "$HOME/.gemini/GEMINI.md" ] && [ "$(readlink "$HOME/.gemini/GEMINI.md")" = "$src" ]; then
      ok "Antigravity CLI: ~/.gemini/GEMINI.md 経由で連携済み"
    else
      warn "Antigravity CLI: 未連携" "./install.sh install"
    fi
  fi
  if agent_present copilot; then
    if state_has setting copilot-dirs; then ok "Copilot CLI: COPILOT_CUSTOM_INSTRUCTIONS_DIRS で連携済み（確実）"; else warn "Copilot CLI: 未連携" "./install.sh install"; fi
  fi
  local f
  for f in "$HOME/.claude/AGENTS.md" "$HOME/AGENTS.md"; do
    [ -e "$f" ] && warn "$f があります。作業ディレクトリによって読まれたり読まれなかったりし、二重読み込みの原因になります"
  done
}

_doctor_link_or_ref() {
  local label="$1" file="$2" id="$3"
  agent_present "$id" || return 0
  if [ -L "$file" ] && [ "$(readlink "$file")" = "$(agents_md_source)" ]; then
    if [ -e "$file" ]; then ok "$label: シンボリックリンクで連携済み"; else err "$label: リンク先がありません" "$(agents_md_source) を作り直してください"; fi
  elif grep -qF '~/.agents/AGENTS.md' "$file" 2>/dev/null; then
    warn "$label: 参照の追記で連携しています（読み込みはエージェント次第）" "確実にするには、$file の内容を正本に移し、$file を削除してから再実行してください"
  else
    warn "$label: 未連携" "./install.sh install"
  fi
}

check_wsl() {
  is_wsl || return 0
  log_section "WSL"
  if systemd_running; then ok "systemd が有効です"; else warn "systemd が無効です（Docker Engine に必要）" "/etc/wsl.conf の [boot] systemd=true"; fi
  local n
  n="$(printf '%s\n' "$PATH" | tr ':' '\n' | grep -c '^/mnt/[a-z]/' || true)"
  if [ "$n" -gt 0 ]; then
    info "PATH に Windows 側のディレクトリが $n 個あります。コマンドの検索が遅い場合は /etc/wsl.conf の [interop] appendWindowsPath=false を検討してください（code などが使えなくなります）"
  fi
  case "$PWD" in /mnt/[a-z]/*) warn "作業ディレクトリが Windows 側 ($PWD) にあります" "リポジトリは Linux 側（~/ 配下）に置くと高速です" ;; esac
  info "メモリ上限などは Windows 側の %UserProfile%\\.wslconfig で設定できます（memory, autoMemoryReclaim, sparseVhd）"
}

check_apt_repos() {
  [ "$(os_kind)" = "linux" ] || return 0
  local name old current
  current="$(ubuntu_codename 2>/dev/null)"
  for name in $(state_list apt-repo); do
    old="$(state_get apt-repo "$name" 4)"
    if [ "$old" != "-" ] && [ "$old" != "$current" ]; then
      warn "apt リポジトリ $name が古い Ubuntu ($old) 向けのままです" "./install.sh install を再実行すると書き直します"
    fi
  done
}

check_release() {
  log_section "agentyard"
  local latest
  latest="$(latest_release_version)"
  if [ -z "$latest" ]; then
    info "最新リリースを確認できませんでした（オフライン？）"
  elif [ "$latest" = "$AGENTYARD_VERSION" ] || _version_ge "$AGENTYARD_VERSION" "$latest"; then
    ok "最新です ($AGENTYARD_VERSION)"
  else
    warn "新しいリリースがあります: $latest（現在 $AGENTYARD_VERSION）" "./install.sh --ref v$latest install"
  fi
}

# ---------------------------------------------------------------------------
# --repo: does each installed agent read the repository's AGENTS.md?
# Only conditions stated in official docs are checked.
check_repo() {
  local repo="$1"
  [ -d "$repo" ] || {
    err "ディレクトリがありません: $repo"
    return
  }
  log_section "リポジトリ: $repo"
  if [ -f "$repo/AGENTS.md" ]; then
    ok "AGENTS.md"
  else
    warn "AGENTS.md がありません" "各エージェントの /init で作成できます"
  fi
  if agent_present claude; then
    # https://code.claude.com/docs/en/memory : a CLAUDE.md / CLAUDE.local.md
    # in the working directory or above suppresses AGENTS.md by default.
    local d="$repo" hit=""
    while :; do
      for f in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
        [ -f "$d/$f" ] && hit="$d/$f" && break 2
      done
      [ "$d" = "/" ] && break
      d="$(dirname "$d")"
    done
    if [ -n "$hit" ] && [ -f "$repo/AGENTS.md" ]; then
      warn "Claude Code: $hit があるため AGENTS.md は既定では読まれません" "CLAUDE.md を削除するか、CLAUDE.md に @AGENTS.md を書いてください"
    else
      ok "Claude Code: AGENTS.md を読みます"
    fi
  fi
  if agent_present gemini; then
    # https://geminicli.com/docs/cli/gemini-md : AGENTS.md requires context.fileName.
    if grep -q 'AGENTS.md' "$repo/.gemini/settings.json" 2>/dev/null; then
      ok "Gemini CLI: context.fileName に AGENTS.md があります"
    else
      warn "Gemini CLI: AGENTS.md は既定では読まれません" '.gemini/settings.json に {"context":{"fileName":["AGENTS.md","GEMINI.md"]}}'
    fi
  fi
  agent_present codex && ok "Codex: AGENTS.md を標準で読みます"
  agent_present copilot && ok "Copilot CLI: AGENTS.md を標準で読みます"
  agent_present antigravity && ok "Antigravity CLI: AGENTS.md を標準で読みます"
}

main() {
  printf '🩺 agentyard doctor (%s)\n' "$AGENTYARD_VERSION"
  session_path_setup
  if [ "${1:-}" = "--repo" ]; then
    check_repo "$(cd "${2:-.}" 2>/dev/null && pwd || printf '%s' "${2:-.}")"
  else
    check_platform
    check_tools
    check_shell_env
    check_agents
    check_sandbox
    check_agents_md
    check_wsl
    check_apt_repos
    check_release
  fi
  printf '\n結果: エラー %d 件、警告 %d 件\n' "$ERRORS" "$WARNINGS"
  if [ "$ERRORS" -gt 0 ]; then exit 2; fi
  if [ "$WARNINGS" -gt 0 ]; then exit 1; fi
  exit 0
}

main "$@"
