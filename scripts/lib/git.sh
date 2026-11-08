#!/bin/bash
# scripts/lib/git.sh
# Minimal, non-destructive Git configuration (ADR-0007 §6).
# Never overwrites existing values. Reads include files (~/.gitconfig.local
# etc.) when checking whether name / email are already set.
# Requires lib/core.sh.

_git_has() {
  # --includes: honor [include] so split configs are respected.
  [ -n "$(git config --global --includes --get "$1" 2>/dev/null)" ]
}

configure_git() {
  log_section "Git"
  has_cmd git || {
    log_warn "git が見つかりません"
    return 1
  }

  if _git_has user.name && _git_has user.email; then
    log_skip "user.name / user.email は設定済みです"
  else
    # Answers were collected before the install started (lib/answers.sh).
    if ! _git_has user.name && [ -n "${ANSWER_GIT_NAME:-}" ]; then
      git config --global user.name "$ANSWER_GIT_NAME" && log_ok "user.name を設定しました"
    fi
    if ! _git_has user.email && [ -n "${ANSWER_GIT_EMAIL:-}" ]; then
      git config --global user.email "$ANSWER_GIT_EMAIL" && log_ok "user.email を設定しました"
    fi
    if ! _git_has user.name || ! _git_has user.email; then
      log_warn "user.name / user.email が未設定です（git config --global user.name / user.email で設定してください）"
    fi
  fi

  if _git_has init.defaultBranch; then
    log_skip "init.defaultBranch は設定済みです"
  else
    git config --global init.defaultBranch main
    log_ok "init.defaultBranch=main"
  fi

  if is_wsl; then
    if _git_has core.autocrlf; then
      log_skip "core.autocrlf は設定済みです"
    else
      git config --global core.autocrlf input
      log_ok "core.autocrlf=input (WSL)"
    fi
  fi

  if has_cmd git-lfs; then
    if _git_has filter.lfs.process; then
      log_skip "git-lfs は設定済みです"
    else
      git lfs install --skip-repo >/dev/null 2>&1 && log_ok "git lfs install --skip-repo"
    fi
  fi
}

configure_gh() {
  has_cmd gh || return 0
  if ! gh auth status >/dev/null 2>&1; then
    log_info "GitHub CLI にログインしていません。ログイン後に 'gh auth setup-git' を実行すると git の HTTPS 認証に使えます。"
    return 0
  fi
  if git config --global --get-all credential.https://github.com.helper 2>/dev/null | grep -q 'gh auth git-credential'; then
    log_skip "gh の git 認証連携は設定済みです"
    return 0
  fi
  if ask_yes_no "GitHub CLI を git の HTTPS 認証に使いますか（gh auth setup-git）？" y; then
    gh auth setup-git && log_ok "gh auth setup-git"
  fi
}
