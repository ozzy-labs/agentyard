#!/bin/bash
# scripts/lib/answers.sh
# shellcheck disable=SC2034  # ANSWER_* are read by the scripts that source this file
# Everything the run needs from the user is collected here, before the install
# starts: the selection screen decides *what* to install, this asks the few
# things that cannot be derived from it (free text, host state), and the
# install steps then run without stopping to ask. Non-interactive mode answers
# from the environment only.
# Requires lib/core.sh, lib/select.sh, lib/git.sh, lib/os/ubuntu.sh,
# lib/components/docker.sh.

ANSWER_GIT_NAME=""
ANSWER_GIT_EMAIL=""
ANSWER_MACOS_DOCKER="${AGENTYARD_MACOS_DOCKER:-}"
ANSWER_GH_OFFICIAL=1 # replace Ubuntu's outdated gh unless the user declines
ANSWER_WSL_SYSTEMD=0 # leave /etc/wsl.conf alone unless asked to change it

# _ask_text <prompt>: prints the line the user typed (empty when skipped).
# The prompt goes to stderr so that $(_ask_text ...) captures the answer only.
_ask_text() {
  local reply=""
  printf '%s' "$1" >&2
  read -r reply || true
  printf '%s' "$reply"
}

_answers_section() {
  if [ "${_ANSWERS_SECTION:-0}" = "0" ]; then
    log_section "設定の確認"
    _ANSWERS_SECTION=1
  fi
}

collect_answers() {
  is_non_interactive && return 0

  # Git identity. git itself may not be installed yet, in which case the
  # current values cannot be read; ask, and let configure_git set only what is
  # still unset.
  if ! has_cmd git || ! _git_has user.name; then
    _answers_section
    ANSWER_GIT_NAME="$(_ask_text 'Git のユーザー名（空欄でスキップ）: ')"
  fi
  if ! has_cmd git || ! _git_has user.email; then
    _answers_section
    ANSWER_GIT_EMAIL="$(_ask_text 'Git のメールアドレス（空欄でスキップ。GitHub の noreply アドレスも使えます）: ')"
  fi

  if [ "$(os_kind)" = "linux" ] && ubuntu_gh_replace_pending; then
    _answers_section
    log_warn "Ubuntu 標準のリポジトリの gh $(apt_pkg_version gh) が入っています。公式版より大幅に古く、gh attestation などが使えません。"
    if ask_yes_no "GitHub 公式の apt リポジトリを登録して、公式版に更新しますか？" y; then
      ANSWER_GH_OFFICIAL=1
    else
      ANSWER_GH_OFFICIAL=0
    fi
  fi

  if selected docker; then
    case "$(os_kind)" in
    linux)
      if is_wsl && ! systemd_running; then
        _answers_section
        log_warn "WSL で systemd が無効です。Docker Engine の起動には systemd が必要です。"
        if ask_yes_no "/etc/wsl.conf に [boot] systemd=true を追加しますか？" n; then
          ANSWER_WSL_SYSTEMD=1
        else
          ANSWER_WSL_SYSTEMD=0
        fi
      fi
      ;;
    macos)
      if [ -z "$ANSWER_MACOS_DOCKER" ] && ! has_cmd docker; then
        _answers_section
        case "$(_ask_text 'コンテナ環境を選んでください: 1) Docker Desktop (組織の規模により有償)  2) OrbStack (商用は有償)  3) Colima [3]: ')" in
        1) ANSWER_MACOS_DOCKER=docker-desktop ;;
        2) ANSWER_MACOS_DOCKER=orbstack ;;
        *) ANSWER_MACOS_DOCKER=colima ;;
        esac
      fi
      ;;
    esac
  fi
  return 0
}
