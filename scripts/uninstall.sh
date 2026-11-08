#!/bin/bash
# scripts/uninstall.sh
# Revert only what agentyard wrote (ADR-0007 §7). Installed tools are kept.
# Usage: scripts/uninstall.sh [--dry-run]
set -u

AGENTYARD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/load.sh
. "$AGENTYARD_ROOT/scripts/lib/load.sh"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

do_or_print() {
  if [ "$DRY_RUN" = "1" ]; then printf '  [dry-run] %s\n' "$*"; else "$@"; fi
}

printf '🧹 agentyard uninstall (%s)\n' "$AGENTYARD_VERSION"
if [ ! -f "$(state_file)" ]; then
  log_info "記録がありません（$(state_file)）。元に戻すものはありません。"
  exit 0
fi
attach_tty_if_needed
if [ "$DRY_RUN" = "0" ] && ! is_non_interactive; then
  ask_yes_no "agentyard が書き換えた設定を元に戻します（ツール本体は残します）。続行しますか？" n || exit 0
fi

src="$(agents_md_source)"

log_section "シェル設定・指示ファイルのブロック"
# Copy the list first: block_remove edits the state file.
blocks="$(awk -F'\t' '$1 == "block" { print $2 "\t" $3 }' "$(state_file)")"
printf '%s\n' "$blocks" | while IFS="$(printf '\t')" read -r file style; do
  [ -n "$file" ] || continue
  [ "$file" = "$src" ] && continue
  do_or_print block_remove "$file" "${style:-sh}"
  log_ok "ブロックを削除: $file"
done

log_section "シンボリックリンク"
for link in $(state_list symlink); do
  if [ -L "$link" ]; then
    do_or_print rm -f "$link"
    log_ok "削除: $link"
  fi
  [ "$DRY_RUN" = "1" ] || state_remove symlink "$link"
done

log_section "AGENTS.md の正本"
if [ -f "$src" ]; then
  do_or_print block_remove "$src" md
  template_sum="$(state_get setting agents-md-template 3 2>/dev/null || true)"
  if [ "$DRY_RUN" = "0" ] && [ -n "$template_sum" ] && [ "$(_agents_md_checksum "$src")" = "$template_sum" ]; then
    rm -f "$src"
    rmdir "$(dirname "$src")" 2>/dev/null || true
    log_ok "未編集の雛形を削除しました: $src"
  else
    log_skip "ユーザーが書いた内容があるため残します: $src"
  fi
fi

log_section "agentyard が作ったファイル"
for f in $(state_list created); do
  case "$f" in
  /etc/apparmor.d/*)
    if [ -f "$f" ]; then
      do_or_print sudo apparmor_parser -R "$f" 2>/dev/null || true
      do_or_print sudo rm -f "$f"
      log_ok "AppArmor プロファイルを削除: $f"
    fi
    ;;
  "$HOME/.local/bin/agentyard-wsl-browser")
    do_or_print rm -f "$f"
    log_ok "削除: $f"
    ;;
  *)
    # Files created only to hold a managed block: delete when now empty.
    if [ -f "$f" ] && [ ! -s "$f" ]; then
      do_or_print rm -f "$f"
      log_ok "空になったファイルを削除: $f"
    fi
    ;;
  esac
done

log_section "apt リポジトリ"
for name in $(state_list apt-repo); do
  log_skip "$name: そこから入れたツールの更新に必要なため残します（$(state_get apt-repo "$name" 3)）"
done

log_section "残したもの"
printf '  - インストールしたツール本体（apt / Homebrew / mise / 公式インストーラ）\n'
printf '  - mise のグローバル設定に追加した項目: %s\n' "$(state_list mise | tr '\n' ' ')"
printf '  - Git の設定（init.defaultBranch など）\n'
state_has setting docker-group && printf '  - docker グループへの所属（sudo gpasswd -d %s docker で外せます）\n' "$(id -un)"
if state_has setting login-shell; then
  prev_shell="$(state_get setting login-shell 4 2>/dev/null || true)"
  printf '  - ログインシェルの変更（戻す場合: chsh -s %s）\n' "${prev_shell:-<元のシェル>}"
fi

if [ "$DRY_RUN" = "0" ]; then
  rm -rf "$AGENTYARD_CONFIG_DIR"
  log_ok "$AGENTYARD_CONFIG_DIR を削除しました"
fi
