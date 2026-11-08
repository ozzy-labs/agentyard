#!/bin/bash
# scripts/lib/os/ubuntu.sh
# Ubuntu 24.04 / 26.04 OS layer (ADR-0007 §4, §6).
# - apt only installs packages that are missing, and records them.
# - Vendor repositories use deb822 `.sources` files. Keys are stored as
#   distributed under /etc/apt/keyrings (no `gpg --dearmor`, no gnupg).
# - Repositories already registered by the user (same URI) are reused.
# Requires lib/core.sh, lib/state.sh, lib/support.sh.

_APT_SOURCES_DIR="${_APT_SOURCES_DIR:-/etc/apt/sources.list.d}"
_APT_KEYRINGS_DIR="${_APT_KEYRINGS_DIR:-/etc/apt/keyrings}"
_APT_UPDATED=0

apt_update_once() {
  [ "$_APT_UPDATED" = "1" ] && return 0
  sudo apt-get update -qq || die "apt-get update に失敗しました（ネットワークや /etc/apt/sources.list.d を確認してください）"
  _APT_UPDATED=1
}

apt_pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

# apt_install <pkg...>: installs missing packages and records them.
apt_install() {
  local missing="" pkg
  for pkg in "$@"; do
    if apt_pkg_installed "$pkg"; then
      log_skip "$pkg (apt)"
    else
      missing="$missing $pkg"
    fi
  done
  [ -n "$missing" ] || return 0
  apt_update_once
  # `sudo env VAR=...`: sudo-rs (26.04 default) may reject VAR=value arguments.
  # shellcheck disable=SC2086  # word splitting of the package list is intended
  if sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $missing >/dev/null; then
    for pkg in $missing; do
      state_add apt-pkg "$pkg"
      log_ok "$pkg (apt)"
    done
  else
    log_error "apt-get install に失敗しました:$missing"
    return 1
  fi
}

# True when <uri> appears in an apt source that agentyard did not write.
apt_uri_registered_elsewhere() {
  local uri="$1" f
  for f in /etc/apt/sources.list "$_APT_SOURCES_DIR"/*.list "$_APT_SOURCES_DIR"/*.sources; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in agentyard-*) continue ;; esac
    if grep -v '^[[:space:]]*#' "$f" | grep -qF "$uri"; then
      return 0
    fi
  done
  return 1
}

# apt_repo_add <name> <uri> <suite|@codename> <components> <key-url> <key-file>
# Suite "@codename" means "the current Ubuntu codename" (rewritten on upgrade).
apt_repo_add() {
  local name="$1" uri="$2" suite="$3" components="$4" key_url="$5" key_file="$6"
  local file="$_APT_SOURCES_DIR/agentyard-$name.sources"
  local codename="-" real_suite="$suite" arch tmp

  if [ "$suite" = "@codename" ]; then
    codename="$(ubuntu_codename)"
    real_suite="$codename"
  fi

  if state_has apt-repo "$name" && [ -f "$file" ] &&
    [ "$(state_get apt-repo "$name" 4)" = "$codename" ]; then
    log_skip "$name の apt リポジトリは登録済みです"
    return 0
  fi

  if ! state_has apt-repo "$name" && apt_uri_registered_elsewhere "$uri"; then
    log_skip "$name の apt リポジトリは既に登録されています（既存の登録を使います）"
    return 0
  fi

  arch="$(dpkg --print-architecture)"
  sudo install -d -m 0755 "$_APT_KEYRINGS_DIR"
  tmp="$(mktemp)"
  if ! curl --proto '=https' --tlsv1.2 -fsSL "$key_url" -o "$tmp"; then
    rm -f "$tmp"
    log_error "$name の署名鍵を取得できませんでした: $key_url"
    return 1
  fi
  sudo install -m 0644 "$tmp" "$_APT_KEYRINGS_DIR/$key_file"
  rm -f "$tmp"

  printf 'Types: deb\nURIs: %s\nSuites: %s\nComponents: %s\nArchitectures: %s\nSigned-By: %s\n' \
    "$uri" "$real_suite" "$components" "$arch" "$_APT_KEYRINGS_DIR/$key_file" |
    sudo tee "$file" >/dev/null
  state_add apt-repo "$name" "$file" "$codename" "$_APT_KEYRINGS_DIR/$key_file"
  _APT_UPDATED=0
  log_ok "$name の apt リポジトリを登録しました (deb822)"
}

# After `do-release-upgrade`, codename-based repositories still point at the
# old release (and may be disabled). Rewrite them for the current codename.
apt_refresh_repos_for_upgrade() {
  local current name file old
  current="$(ubuntu_codename)"
  for name in $(state_list apt-repo); do
    old="$(state_get apt-repo "$name" 4)"
    [ "$old" = "-" ] && continue
    [ "$old" = "$current" ] && continue
    file="$(state_get apt-repo "$name" 3)"
    [ -f "$file" ] || continue
    log_info "Ubuntu のアップグレードを検出しました（$old → $current）。$name の apt リポジトリを書き直します"
    sudo sed -i -e "s/^Suites: .*/Suites: $current/" -e '/^Enabled: no$/d' "$file"
    state_add apt-repo "$name" "$file" "$current" "$(state_get apt-repo "$name" 5)"
    _APT_UPDATED=0
  done
}

ubuntu_prerequisites() {
  log_section "前提パッケージ (apt)"
  ensure_sudo
  apt_refresh_repos_for_upgrade
  apt_install ca-certificates curl unzip openssh-client
}

ubuntu_base_tools() {
  log_section "既定のツール (apt)"
  apt_install build-essential pkgconf libssl-dev git git-lfs jq ripgrep tree fzf fd-find bubblewrap socat

  # Ubuntu ships fd as `fdfind`; expose it as `fd` for humans and agents.
  if ! has_cmd fd && has_cmd fdfind; then
    mkdir -p "$HOME/.local/bin"
    ln -s "$(command -v fdfind)" "$HOME/.local/bin/fd"
    state_add symlink "$HOME/.local/bin/fd"
    log_ok "fd -> fdfind のシンボリックリンクを作成しました"
  fi

  ubuntu_install_gh
}

# apt_pkg_version <pkg>: installed version, empty when not installed via dpkg.
apt_pkg_version() {
  apt_pkg_installed "$1" || return 0
  dpkg-query -W -f='${Version}' "$1" 2>/dev/null
}

# GitHub CLI from the official apt repository (ADR-0007 §4).
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md
# Ubuntu's own `gh` package is far behind upstream (24.04: 2.45, 26.04: 2.46)
# and lacks commands such as `gh attestation`. When it is installed, offer to
# replace it with the official build (same package name, newer version).
# True when Ubuntu's own gh is installed and the official repository is not
# registered yet: the one case where replacing it is a decision, so it is
# asked before the install starts (lib/answers.sh).
ubuntu_gh_replace_pending() {
  state_has apt-repo github-cli && return 1
  apt_uri_registered_elsewhere https://cli.github.com/packages && return 1
  apt_pkg_installed gh
}

ubuntu_install_gh() {
  local official=0
  if state_has apt-repo github-cli || apt_uri_registered_elsewhere https://cli.github.com/packages; then
    official=1
  fi
  if [ "$official" = "0" ] && has_cmd gh && ! apt_pkg_installed gh; then
    log_skip "gh は apt 以外の方法で導入されています（$(command -v gh)）"
    return 0
  fi
  if ubuntu_gh_replace_pending; then
    if [ "${ANSWER_GH_OFFICIAL:-1}" != "1" ]; then
      log_skip "gh は Ubuntu 標準の版のままにします"
      return 0
    fi
    log_warn "Ubuntu 標準のリポジトリの gh $(apt_pkg_version gh) を公式版に更新します"
  fi
  apt_repo_add github-cli https://cli.github.com/packages stable main \
    https://cli.github.com/packages/githubcli-archive-keyring.gpg githubcli-archive-keyring.gpg || return 1
  if apt_pkg_installed gh; then
    local before after
    before="$(apt_pkg_version gh)"
    apt_update_once
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --only-upgrade gh >/dev/null ||
      log_warn "gh の更新に失敗しました"
    after="$(apt_pkg_version gh)"
    if [ "$before" != "$after" ]; then
      log_ok "gh を更新しました（$before → $after）"
    else
      log_skip "gh (apt)"
    fi
  else
    apt_install gh
  fi
}
