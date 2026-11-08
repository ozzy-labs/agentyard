#!/bin/bash
# scripts/lib/select.sh
# Component registry and selection (ADR-0007 §4, §7).
#
# Interactive: numbered list (toggle by number); whiptail checklist when
#              available and AGENTYARD_UI != plain.
# Non-interactive:
#   AGENTYARD_AGENTS  comma list of agents (default: claude,codex,copilot)
#   AGENTYARD_WITH    comma list of opt-in tools / settings
#   Legacy INSTALL_* variables are mapped for one migration period.
# Requires lib/core.sh. Bash 3.2 compatible (no associative arrays).

# Registry rows: id|group|default|label
# group: agent | tool | setting. default applies to the interactive screen;
# non-interactive defaults are AGENTYARD_DEFAULT_AGENTS only.
AGENTYARD_DEFAULT_AGENTS="claude,codex,copilot"

registry_rows() {
  cat <<'EOF'
claude|agent|1|Claude Code (Anthropic)
codex|agent|1|Codex CLI (OpenAI)
copilot|agent|1|GitHub Copilot CLI (GitHub, 有料契約が必要)
antigravity|agent|0|Antigravity CLI (Google, 18 歳以上)
gemini|agent|0|Gemini CLI (Google, Gemini Code Assist 契約者向け)
docker|tool|0|Docker (Linux: Docker Engine / macOS: Desktop・OrbStack・Colima から選択)
zsh|tool|0|zsh + oh-my-zsh
tmux|tool|0|tmux
zellij|tool|0|zellij
aws|tool|0|AWS CLI
azure|tool|0|Azure CLI
gcloud|tool|0|Google Cloud CLI
ast-grep|tool|0|ast-grep (構文を理解した検索・置換)
yq|tool|0|yq (YAML 版 jq)
markitdown|tool|0|markitdown (Office 文書などを Markdown に変換)
bun|tool|0|Bun
agents-md|setting|1|ユーザースコープの AGENTS.md (~/.agents/AGENTS.md) と各エージェントへの連携
docker-group|setting|0|docker グループに自分を追加 (sudo なしで docker を使える・実質 root 権限)
zsh-login-shell|setting|0|ログインシェルを zsh に変更
mise-trust|setting|0|mise: 指定ディレクトリ配下のリポジトリを自動で信頼する
wsl-browser|setting|0|WSL: ログイン時に Windows のブラウザを開く
apparmor|setting|0|Ubuntu 24.04: bwrap 用 AppArmor 対処 (サンドボックスを有効にする)
EOF
}

# Platform availability (returns 0 when the component applies here).
component_available() {
  case "$1" in
  wsl-browser) [ "$(os_kind)" = "linux" ] && is_wsl ;;
  # The docker group exists only on Linux; macOS zsh is already the login shell.
  docker-group | zsh-login-shell) [ "$(os_kind)" = "linux" ] ;;
  apparmor) [ "$(os_kind)" = "linux" ] && apparmor_applicable ;;
  *) return 0 ;;
  esac
}

# apparmor_applicable is provided by components/apparmor.sh; fall back to false.
if ! declare -F apparmor_applicable >/dev/null 2>&1; then
  apparmor_applicable() { return 1; }
fi

registry_label() {
  registry_rows | awk -F'|' -v id="$1" '$1 == id { print $4 }'
}

registry_group() {
  registry_rows | awk -F'|' -v id="$1" '$1 == id { print $2 }'
}

registry_ids() {
  registry_rows | awk -F'|' -v g="${1:-}" 'g == "" || $2 == g { print $1 }'
}

# ---------------------------------------------------------------------------
# Selection state: SELECTED is a space-delimited list of ids.
# ---------------------------------------------------------------------------
SELECTED=""

selected() {
  case " $SELECTED " in *" $1 "*) return 0 ;; esac
  return 1
}

select_add() {
  selected "$1" || SELECTED="${SELECTED:+$SELECTED }$1"
}

select_del() {
  local out="" id
  for id in $SELECTED; do
    [ "$id" = "$1" ] || out="${out:+$out }$id"
  done
  SELECTED="$out"
}

# Comma / space separated list -> SELECTED additions (unknown ids warned).
_select_add_list() {
  local list="$1" id
  list="$(printf '%s' "$list" | tr ',' ' ')"
  for id in $list; do
    case "$id" in
    power) id="ast-grep yq markitdown" ;;
    esac
    local one
    for one in $id; do
      if [ -n "$(registry_group "$one")" ]; then
        select_add "$one"
      else
        log_warn "不明な項目を無視します: $one"
      fi
    done
  done
}

# Map legacy INSTALL_* variables (v0.4.x) onto the new selection.
_select_apply_legacy() {
  local used=0
  _legacy() {
    # _legacy <var> <value-meaning-on> <ids...>
    local var="$1" on="$2" val
    shift 2
    eval "val=\${$var:-}"
    [ -n "$val" ] || return 0
    used=1
    local id
    for id in "$@"; do
      if [ "$val" = "$on" ]; then select_add "$id"; else select_del "$id"; fi
    done
  }
  _legacy INSTALL_CONTAINER 1 docker
  _legacy INSTALL_TMUX 1 tmux
  _legacy INSTALL_ZELLIJ 1 zellij
  _legacy INSTALL_BUN 1 bun
  _legacy INSTALL_AWS_CLI 1 aws
  _legacy INSTALL_AZURE_CLI 1 azure
  _legacy INSTALL_GCLOUD_CLI 1 gcloud
  _legacy INSTALL_AI_POWER_TOOLS 1 ast-grep yq markitdown
  _legacy INSTALL_CLAUDE_CODE 1 claude
  _legacy INSTALL_CODEX_CLI 1 codex
  _legacy INSTALL_COPILOT_CLI 1 copilot
  _legacy INSTALL_GEMINI_CLI 1 gemini
  unset -f _legacy
  if [ "$used" = "1" ]; then
    log_warn "INSTALL_* 環境変数は非推奨です。AGENTYARD_AGENTS / AGENTYARD_WITH を使ってください。"
  fi
}

# Resolve the selection without prompting (non-interactive mode).
select_resolve_noninteractive() {
  SELECTED=""
  _select_add_list "${AGENTYARD_AGENTS:-$AGENTYARD_DEFAULT_AGENTS}"
  _select_add_list "${AGENTYARD_WITH:-}"
  # AGENTYARD_DOCKER_GROUP=1 (v0.5.x) selects the docker-group item.
  if [ "${AGENTYARD_DOCKER_GROUP:-0}" = "1" ]; then
    select_add docker-group
  fi
  _select_apply_legacy
  _select_drop_unavailable
}

_select_drop_unavailable() {
  local id
  for id in $SELECTED; do
    if ! component_available "$id"; then
      log_skip "$(registry_label "$id") はこの環境では対象外のため除外します"
      select_del "$id"
    fi
  done
}

_select_interactive_defaults() {
  SELECTED=""
  if [ -n "${AGENTYARD_AGENTS:-}" ]; then
    _select_add_list "$AGENTYARD_AGENTS"
  else
    while IFS='|' read -r id group def _label; do
      if [ "$def" = "1" ]; then select_add "$id"; fi
    done <<EOF
$(registry_rows)
EOF
  fi
  _select_add_list "${AGENTYARD_WITH:-}"
  _select_apply_legacy
}

# Visible ids for this platform, in registry order.
_select_visible_ids() {
  local id
  for id in $(registry_ids); do
    component_available "$id" && printf '%s\n' "$id"
  done
}

_select_print_menu() {
  local n=0 id group last="" mark
  for id in $(_select_visible_ids); do
    n=$((n + 1))
    group="$(registry_group "$id")"
    if [ "$group" != "$last" ]; then
      case "$group" in
      agent) printf '\n  [AI エージェント]\n' ;;
      tool) printf '\n  [ツール (opt-in)]\n' ;;
      setting) printf '\n  [設定 (opt-in)]\n' ;;
      esac
      last="$group"
    fi
    if selected "$id"; then mark="x"; else mark=" "; fi
    printf '  %2d) [%s] %s\n' "$n" "$mark" "$(registry_label "$id")"
  done
}

_select_toggle_number() {
  local want="$1" n=0 id
  for id in $(_select_visible_ids); do
    n=$((n + 1))
    if [ "$n" = "$want" ]; then
      if selected "$id"; then select_del "$id"; else select_add "$id"; fi
      return 0
    fi
  done
  return 1
}

_select_numbered() {
  local input tok
  while :; do
    printf '\n📦 インストールする項目を選んでください（[x] が選択中）\n'
    _select_print_menu
    printf '\n番号を入力すると選択を切り替えます（例: 5 7 12）。Enter だけで確定します: '
    input=""
    read -r input || true
    [ -z "$input" ] && break
    for tok in $(printf '%s' "$input" | tr ',' ' '); do
      case "$tok" in
      *[!0-9]*) log_warn "数字ではありません: $tok" ;;
      *) _select_toggle_number "$tok" || log_warn "範囲外の番号です: $tok" ;;
      esac
    done
  done
}

_select_whiptail() {
  local args=() id state result
  for id in $(_select_visible_ids); do
    if selected "$id"; then state=ON; else state=OFF; fi
    args+=("$id" "$(registry_label "$id")" "$state")
  done
  if ! result="$(whiptail --title "agentyard" --separate-output \
    --checklist "インストールする項目を選んでください（Space で切替、Enter で確定）" \
    24 100 16 "${args[@]}" 3>&1 1>&2 2>&3)"; then
    log_warn "選択画面が中断されました。番号入力で選び直します。"
    _select_numbered
    return
  fi
  SELECTED=""
  for id in $result; do select_add "$id"; done
}

# Entry point: populates SELECTED.
select_components() {
  if is_non_interactive; then
    select_resolve_noninteractive
  else
    _select_interactive_defaults
    if [ "${AGENTYARD_UI:-}" != "plain" ] && has_cmd whiptail; then
      _select_whiptail
    else
      _select_numbered
    fi
    _select_drop_unavailable
  fi
  printf '\n選択された項目:\n'
  local id
  for id in $SELECTED; do printf '  - %s\n' "$(registry_label "$id")"; done
}

# Install-time notices. Most agents ask users to accept their terms at the
# first login, so only Antigravity CLI (whose terms state that installing it
# means agreeing) gets a notice here. Account requirements are shown in the
# selection labels.
print_agent_notices() {
  selected antigravity || return 0
  printf '\n'
  log_info "Antigravity CLI は、インストールした時点で利用規約に同意したものとみなされます（利用データの収集が既定で有効。設定で無効にできます）: https://antigravity.google/terms"
}
