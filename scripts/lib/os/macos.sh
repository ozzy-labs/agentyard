#!/bin/bash
# scripts/lib/os/macos.sh
# macOS 26 / 27 (Apple Silicon) OS layer (ADR-0007 §4, §6).
# - Homebrew is the OS package manager (installs Xcode CLT when missing).
#   https://docs.brew.sh/Installation
# - Everything agentyard installs with Homebrew is recorded in its own
#   Brewfile so `update` upgrades only those items via `brew bundle`.
#   https://docs.brew.sh/Brew-Bundle-and-Brewfile
# Requires lib/core.sh, lib/state.sh.

agentyard_brewfile() { printf '%s/Brewfile' "$AGENTYARD_CONFIG_DIR"; }

macos_require_admin() {
  if ! id -Gn | tr ' ' '\n' | grep -qx admin; then
    die "管理者（admin グループ）のユーザーで実行してください。Homebrew のインストールに必要です。"
  fi
}

ensure_homebrew() {
  if [ -x /opt/homebrew/bin/brew ]; then
    log_skip "Homebrew はインストール済みです"
  else
    log_info "Homebrew をインストールします（Xcode Command Line Tools も必要に応じて入ります）"
    ensure_sudo
    if is_non_interactive; then
      (
        export NONINTERACTIVE=1
        run_remote_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh bash
      ) || die "Homebrew のインストールに失敗しました"
    else
      run_remote_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh bash ||
        die "Homebrew のインストールに失敗しました"
    fi
    state_add component homebrew
  fi
  session_path_setup
  if ! xcode-select -p >/dev/null 2>&1; then
    log_warn "Xcode Command Line Tools が見つかりません。'xcode-select --install' を実行してください。"
  fi
}

# brew_install <formula|cask> <name>
# Installs only when missing and records it in the agentyard Brewfile.
# Items the user installed beforehand are left alone (not recorded).
brew_install() {
  local kind="$1" name="$2" listflag="--formula"
  [ "$kind" = "cask" ] && listflag="--cask"
  if brew list "$listflag" "$name" >/dev/null 2>&1; then
    log_skip "$name (brew)"
    return 0
  fi
  if [ "$kind" = "cask" ]; then
    brew install --cask "$name" >/dev/null || {
      log_error "brew install --cask $name に失敗しました"
      return 1
    }
  else
    brew install "$name" >/dev/null || {
      log_error "brew install $name に失敗しました"
      return 1
    }
  fi
  _brewfile_add "$kind" "$name"
  log_ok "$name (brew)"
}

_brewfile_add() {
  local kind="$1" name="$2" file line
  file="$(agentyard_brewfile)"
  [ "$kind" = "formula" ] && kind="brew"
  line="$kind \"$name\""
  mkdir -p "$AGENTYARD_CONFIG_DIR"
  touch "$file"
  grep -qxF "$line" "$file" || printf '%s\n' "$line" >>"$file"
}

macos_prerequisites() {
  log_section "前提 (macOS)"
  macos_require_admin
  ensure_homebrew
}

macos_base_tools() {
  log_section "既定のツール (Homebrew)"
  local f
  for f in git-lfs gh jq ripgrep tree fzf fd; do
    brew_install formula "$f"
  done
}
