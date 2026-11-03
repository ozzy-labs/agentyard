#!/bin/bash
# scripts/lib/components/tools.sh
# Opt-in tools (ADR-0007 §4): zsh + oh-my-zsh, tmux, zellij, AWS CLI,
# Azure CLI, Google Cloud CLI, ast-grep, yq, markitdown, Bun.
# Linux: apt / official installers / mise. macOS: Homebrew / mise / uv.

# --- zsh + oh-my-zsh ---------------------------------------------------------
# https://github.com/ohmyzsh/ohmyzsh/blob/master/tools/install.sh
_install_ohmyzsh() {
  curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh |
    RUNZSH=no CHSH=no KEEP_ZSHRC="$1" sh -s -- --unattended
}

install_zsh() {
  log_section "zsh + oh-my-zsh"
  if [ "$(os_kind)" = "linux" ]; then
    apt_install zsh || return 1
  fi
  if [ -d "${ZSH:-$HOME/.oh-my-zsh}" ]; then
    log_skip "oh-my-zsh は導入済みです"
  else
    local keep=no
    # Never replace an existing ~/.zshrc (ADR-0007 principle 7).
    [ -f "$HOME/.zshrc" ] && keep=yes
    if quiet_run _install_ohmyzsh "$keep"; then
      state_add component oh-my-zsh
      log_ok "oh-my-zsh を導入しました"
      if [ "$keep" = "yes" ]; then
        log_info "既存の ~/.zshrc は残しました。oh-my-zsh を使うには ~/.oh-my-zsh/templates/zshrc.zsh-template を参考に設定してください。"
      fi
    else
      log_warn "oh-my-zsh のインストールに失敗しました"
    fi
  fi
  state_add component zsh
  # Login shell change: interactive confirmation only (needs a password).
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [ "$(os_kind)" = "linux" ] && [ "${SHELL:-}" != "$zsh_path" ] && ! is_non_interactive; then
    if ask_yes_no "ログインシェルを zsh に変更しますか？" n; then
      # sudo reuses the cached credentials; plain chsh would ask for the
      # user's password again.
      sudo chsh -s "$zsh_path" "$(id -un)" && log_ok "ログインシェルを zsh に変更しました（次回ログインから有効）"
    fi
  fi
}

# --- terminal multiplexers ---------------------------------------------------
install_tmux() {
  log_section "tmux"
  case "$(os_kind)" in
  linux) apt_install tmux ;;
  macos) brew_install formula tmux ;;
  esac
}

install_zellij() {
  log_section "zellij"
  case "$(os_kind)" in
  linux) mise_global zellij ;;
  macos) brew_install formula zellij ;;
  esac
}

# --- cloud CLIs ----------------------------------------------------------------
# AWS: official install script (user-local XDG install, signature-verified).
#   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
install_aws() {
  log_section "AWS CLI"
  if has_cmd aws; then
    log_skip "aws は導入済みです"
    return 0
  fi
  case "$(os_kind)" in
  linux)
    # The installer verifies its signature with gpg (absent on minimal images).
    apt_install gnupg || return 1
    if quiet_run run_remote_installer https://awscli.amazonaws.com/v2/install.sh bash --quiet; then
      state_add component aws
      log_ok "AWS CLI を導入しました (~/.local/bin/aws)"
    else
      log_warn "AWS CLI のインストールに失敗しました"
    fi
    ;;
  macos) brew_install formula awscli ;;
  esac
}

# Azure: https://learn.microsoft.com/cli/azure/install-azure-cli-linux?pivots=apt
install_azure() {
  log_section "Azure CLI"
  case "$(os_kind)" in
  linux)
    apt_repo_add azure-cli https://packages.microsoft.com/repos/azure-cli/ @codename main \
      https://packages.microsoft.com/keys/microsoft.asc microsoft.asc || return 1
    apt_install azure-cli
    ;;
  macos) brew_install cask azure-cli ;;
  esac
}

# gcloud: https://cloud.google.com/sdk/docs/install#deb
# The key file is ASCII-armored despite its .gpg name; store it as .asc.
install_gcloud() {
  log_section "Google Cloud CLI"
  case "$(os_kind)" in
  linux)
    apt_repo_add google-cloud-sdk https://packages.cloud.google.com/apt cloud-sdk main \
      https://packages.cloud.google.com/apt/doc/apt-key.gpg cloud.google.asc || return 1
    apt_install google-cloud-cli
    ;;
  macos) brew_install cask gcloud-cli ;;
  esac
}

# --- agent helper tools -------------------------------------------------------
install_ast_grep() {
  log_section "ast-grep"
  case "$(os_kind)" in
  linux) mise_global ast-grep ;;
  macos) brew_install formula ast-grep ;;
  esac
}

install_yq() {
  log_section "yq"
  case "$(os_kind)" in
  linux) mise_global yq ;;
  macos) brew_install formula yq ;;
  esac
}

# markitdown: Python app via uv tool (requires Python >=3.10; uv manages it).
install_markitdown() {
  log_section "markitdown"
  if ! has_cmd uv; then
    log_warn "uv が見つからないため markitdown をスキップします"
    return 1
  fi
  if uv tool list 2>/dev/null | grep -q '^markitdown '; then
    log_skip "markitdown は導入済みです"
    return 0
  fi
  if uv tool install 'markitdown[all]' >/dev/null 2>&1; then
    state_add uv-tool markitdown
    log_ok "markitdown[all] (uv tool)"
  else
    log_warn "markitdown のインストールに失敗しました"
  fi
}

install_bun() {
  log_section "Bun"
  mise_global bun
}
