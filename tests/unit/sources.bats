#!/usr/bin/env bats
# tests/unit/sources.bats
# Tool source handling: Ubuntu's old gh is replaced by the official build,
# and an existing mise from another install method is reused.

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export AGENTYARD_CONFIG_DIR="$HOME/.config/agentyard"
  export CI=true
  export AGENTYARD_ROOT="$SCRIPT_ROOT"
  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"
}

_load() {
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/load.sh"
  # Mocks: record calls instead of touching the system.
  apt_repo_add() { echo "apt_repo_add $*" >>"$MOCK_LOG"; }
  apt_install() { echo "apt_install $*" >>"$MOCK_LOG"; }
  apt_update_once() { :; }
  sudo() { echo "sudo $*" >>"$MOCK_LOG"; }
}

@test "gh: Ubuntu's package is replaced by the official repository (non-interactive)" {
  _load
  apt_uri_registered_elsewhere() { return 1; }
  apt_pkg_installed() { [ "$1" = "gh" ]; }
  apt_pkg_version() { printf '2.46.0-4'; }
  run ubuntu_install_gh
  [ "$status" -eq 0 ]
  grep -q '^apt_repo_add github-cli https://cli.github.com/packages' "$MOCK_LOG"
  grep -q 'only-upgrade gh' "$MOCK_LOG"
  [[ "$output" == *"Ubuntu 標準のリポジトリの gh"* ]]
}

@test "gh: an already-registered official repository is left as is" {
  _load
  apt_uri_registered_elsewhere() { return 0; }
  apt_pkg_installed() { [ "$1" = "gh" ]; }
  apt_pkg_version() { printf '2.100.0'; }
  run ubuntu_install_gh
  [ "$status" -eq 0 ]
  [[ "$output" != *"Ubuntu 標準のリポジトリの gh"* ]]
}

@test "gh: a non-apt gh (e.g. Homebrew, manual) is not touched" {
  _load
  apt_uri_registered_elsewhere() { return 1; }
  apt_pkg_installed() { return 1; }
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho gh version 2.100.0\n' >"$BATS_TEST_TMPDIR/bin/gh"
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH" run ubuntu_install_gh
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_LOG" ]
}

@test "gh: fresh host installs gh from the official repository" {
  _load
  apt_uri_registered_elsewhere() { return 1; }
  apt_pkg_installed() { return 1; }
  has_cmd() { [ "$1" != "gh" ] && command -v "$1" >/dev/null 2>&1; }
  run ubuntu_install_gh
  [ "$status" -eq 0 ]
  grep -q '^apt_repo_add github-cli' "$MOCK_LOG"
  grep -q '^apt_install gh' "$MOCK_LOG"
}

@test "mise: an existing mise elsewhere on PATH is reused" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\necho 2026.1.0\n' >"$BATS_TEST_TMPDIR/bin/mise"
  chmod +x "$BATS_TEST_TMPDIR/bin/mise"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  unset MISE_BIN
  _load
  [ "$MISE_BIN" = "$BATS_TEST_TMPDIR/bin/mise" ]
  ! mise_is_official_install
}

@test "mise: the official install location is preferred" {
  mkdir -p "$HOME/.local/bin"
  printf '#!/bin/sh\necho 2026.1.0\n' >"$HOME/.local/bin/mise"
  chmod +x "$HOME/.local/bin/mise"
  unset MISE_BIN
  _load
  [ "$MISE_BIN" = "$HOME/.local/bin/mise" ]
  mise_is_official_install
}

@test "mise-trust: re-runs skip the prompt when already configured" {
  _load
  state_add setting mise-trust "$HOME/repos"
  mise_at_home() {
    case "$*" in
    "settings get trusted_config_paths") printf '["%s/repos"]\n' "$HOME" ;;
    *) echo "mise $*" >>"$MOCK_LOG" ;;
    esac
  }
  unset AGENTYARD_MISE_TRUSTED_PATHS
  AGENTYARD_ASSUME_YES=0 CI=false run install_mise_trust </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"設定済みです"* ]]
  [[ "$output" != *"信頼するディレクトリ"* ]]
  [ ! -s "$MOCK_LOG" ]
}

@test "mise-trust: an explicit AGENTYARD_MISE_TRUSTED_PATHS still adds directories" {
  _load
  state_add setting mise-trust "$HOME/repos"
  mise_at_home() {
    case "$*" in
    "settings get trusted_config_paths") printf '["%s/repos"]\n' "$HOME" ;;
    *) echo "mise $*" >>"$MOCK_LOG" ;;
    esac
  }
  AGENTYARD_MISE_TRUSTED_PATHS="$HOME/work" run install_mise_trust
  [ "$status" -eq 0 ]
  grep -q "settings add trusted_config_paths $HOME/work" "$MOCK_LOG"
}
