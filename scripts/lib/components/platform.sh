#!/bin/bash
# scripts/lib/components/platform.sh
# Platform-specific opt-in settings (ADR-0007 §6):
#   apparmor     Ubuntu 24.04 (non-WSL) only: let bwrap create user namespaces
#   wsl-browser  WSL only: open login pages in the Windows browser
#   mise-trust   mise trusted_config_paths

AGENTYARD_APPARMOR_PROFILE="/etc/apparmor.d/agentyard-bwrap"

# Ubuntu 24.04 restricts unprivileged user namespaces through AppArmor and,
# unlike 26.04, ships no bwrap profile, so bubblewrap-based agent sandboxes
# fail there. WSL kernels do not have the restriction at all.
apparmor_applicable() {
  [ "$(os_kind)" = "linux" ] || return 1
  is_wsl && return 1
  [ "$(cat /proc/sys/kernel/apparmor_restrict_unprivileged_userns 2>/dev/null)" = "1" ] || return 1
  [ -e /etc/apparmor.d/bwrap-userns-restrict ] && return 1
  return 0
}

install_apparmor() {
  log_section "AppArmor (bwrap)"
  if ! apparmor_applicable; then
    log_skip "この環境では不要です"
    return 0
  fi
  log_warn "Ubuntu のユーザー名前空間の制限を、/usr/bin/bwrap に限って緩めます。"
  log_warn "bwrap を使えば、どのユーザーもユーザー名前空間を作れるようになります（サンドボックスの前提）。"
  log_info "参考: https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces"
  if ! ask_yes_no "続行しますか？" n; then
    is_non_interactive || return 0
    # Non-interactive: explicit opt-in via AGENTYARD_WITH=apparmor is consent.
  fi
  sudo tee "$AGENTYARD_APPARMOR_PROFILE" >/dev/null <<'EOF'
# Managed by agentyard (ADR-0007). Allows bubblewrap to create user
# namespaces on Ubuntu 24.04 so AI agent sandboxes can start.
abi <abi/4.0>,
include <tunables/global>

profile agentyard-bwrap /usr/bin/bwrap flags=(unconfined) {
  userns,

  include if exists <local/agentyard-bwrap>
}
EOF
  if sudo apparmor_parser -r "$AGENTYARD_APPARMOR_PROFILE"; then
    state_add created "$AGENTYARD_APPARMOR_PROFILE"
    state_add component apparmor
    log_ok "AppArmor プロファイルを読み込みました: $AGENTYARD_APPARMOR_PROFILE"
  else
    log_error "AppArmor プロファイルの読み込みに失敗しました"
    return 1
  fi
}

# WSL: tiny BROWSER wrapper (wslu is not available on Ubuntu 26.04).
install_wsl_browser() {
  log_section "WSL のブラウザ連携"
  local wrapper="$HOME/.local/bin/agentyard-wsl-browser" tmp
  mkdir -p "$HOME/.local/bin"
  tmp="$(mktemp)"
  cat >"$tmp" <<'EOF'
#!/bin/sh
# Managed by agentyard. Opens URLs in the Windows default browser from WSL.
for exe in /mnt/c/Windows/explorer.exe "$(command -v explorer.exe 2>/dev/null)"; do
  if [ -n "$exe" ] && [ -x "$exe" ]; then
    "$exe" "$1"
    exit 0 # explorer.exe exits non-zero even on success
  fi
done
echo "explorer.exe が見つかりません。URL を手動で開いてください: $1" >&2
exit 1
EOF
  if [ -x "$wrapper" ] && cmp -s "$tmp" "$wrapper" && state_has setting wsl-browser; then
    rm -f "$tmp"
    log_skip "WSL のブラウザ連携は設定済みです"
    return 0
  fi
  cat "$tmp" >"$wrapper"
  rm -f "$tmp"
  chmod +x "$wrapper"
  state_add created "$wrapper"
  state_add setting wsl-browser 1
  log_ok "BROWSER に $wrapper を設定します（env.sh）"
}

# Common workspace directories under $HOME that actually contain git repos.
_mise_trust_candidates() {
  local d out=""
  for d in repos src code projects work dev; do
    [ -d "$HOME/$d" ] || continue
    if find "$HOME/$d" -mindepth 2 -maxdepth 2 -name .git 2>/dev/null | grep -q .; then
      out="${out:+$out,}~/$d"
    fi
  done
  printf '%s' "$out"
}

# mise: trust config files under the given directories (global config only).
# https://mise.jdx.dev/configuration/settings.html#trusted_config_paths
install_mise_trust() {
  log_section "mise の信頼設定"
  local paths="${AGENTYARD_MISE_TRUSTED_PATHS:-}"
  # Already configured by agentyard: do not ask again on re-runs. An explicit
  # AGENTYARD_MISE_TRUSTED_PATHS still adds more directories.
  if [ -z "$paths" ] && state_has setting mise-trust; then
    local current
    current="$(mise_at_home settings get trusted_config_paths 2>/dev/null | tr -d '[]"' | sed 's/, */,/g')"
    if [ -n "$current" ]; then
      log_skip "trusted_config_paths は設定済みです（$current）"
      log_info "追加: AGENTYARD_MISE_TRUSTED_PATHS=<dir> ./install.sh install / 削除: ~/.config/mise/config.toml の trusted_config_paths を編集（すべて外す場合は mise settings unset trusted_config_paths）"
      return 0
    fi
  fi
  if [ -z "$paths" ]; then
    if is_non_interactive; then
      log_warn "AGENTYARD_MISE_TRUSTED_PATHS が未指定のためスキップします"
      return 0
    fi
    log_warn "指定したディレクトリ配下のリポジトリの mise 設定は、確認なしで信頼されます。"
    local suggested
    suggested="$(_mise_trust_candidates)"
    if [ -n "$suggested" ]; then
      printf '  信頼するディレクトリ（カンマ区切り。Enter で [%s]、- でスキップ）: ' "$suggested"
      read -r paths || true
      [ -z "$paths" ] && paths="$suggested"
      [ "$paths" = "-" ] && return 0
    else
      printf '  信頼するディレクトリ（カンマ区切り、空欄でスキップ）: '
      read -r paths || true
      [ -n "$paths" ] || return 0
    fi
  fi
  local p ok=1 added=""
  for p in $(printf '%s' "$paths" | tr ',' ' '); do
    case "$p" in "~"*) p="$HOME${p#\~}" ;; esac
    if mise_at_home settings get trusted_config_paths 2>/dev/null | grep -qF "\"$p\""; then
      log_skip "$p は信頼済みです"
      continue
    fi
    # `mise settings add` appends to the array in the global config.
    if mise_at_home settings add trusted_config_paths "$p" >/dev/null 2>&1; then
      added="${added:+$added,}$p"
      log_ok "trusted_config_paths に追加: $p"
    else
      ok=0
      log_warn "$p を追加できませんでした（手動: mise settings add trusted_config_paths $p）"
    fi
  done
  [ -n "$added" ] && state_add setting mise-trust "$added"
  [ "$ok" = "1" ]
}
