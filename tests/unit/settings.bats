#!/usr/bin/env bats
# tests/unit/settings.bats
# Settings that used to be asked during the run and are now selected up front:
# the docker group, the login shell, and mise's trusted paths.

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/bin"
  export AGENTYARD_CONFIG_DIR="$HOME/.config/agentyard"
  export AGENTYARD_ROOT="$SCRIPT_ROOT"
  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"
  export CI=true
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/load.sh"
  sudo() { echo "sudo $*" >>"$MOCK_LOG"; }
  os_kind() { printf 'linux'; }
}

# --- docker group ----------------------------------------------------------

@test "docker-group: skipped when docker is not installed" {
  has_cmd() { [ "$1" != "docker" ]; }
  run install_docker_group
  [ "$status" -eq 0 ]
  [[ "$output" == *"docker が見つかりません"* ]]
  [ ! -s "$MOCK_LOG" ]
  ! state_has setting docker-group
}

@test "docker-group: skipped when the user is already a member" {
  has_cmd() { return 0; }
  id() { case "$*" in -nG*) printf 'users docker' ;; -un) printf 'tester' ;; esac }
  run install_docker_group
  [ "$status" -eq 0 ]
  [[ "$output" == *"既に docker グループに所属"* ]]
  [ ! -s "$MOCK_LOG" ]
}

@test "docker-group: adds the user and records it" {
  has_cmd() { return 0; }
  id() { case "$*" in -nG*) printf 'users' ;; -un) printf 'tester' ;; esac }
  run install_docker_group
  [ "$status" -eq 0 ]
  grep -q "sudo usermod -aG docker tester" "$MOCK_LOG"
  [[ "$output" == *"docker グループに追加しました"* ]]
}

@test "docker-group: AGENTYARD_DOCKER_GROUP=1 selects the item" {
  AGENTYARD_DOCKER_GROUP=1 select_resolve_noninteractive
  selected docker-group
}

@test "docker-group: not selected without the variable" {
  select_resolve_noninteractive
  ! selected docker-group
}

# --- login shell -----------------------------------------------------------

@test "zsh-login-shell: skipped when zsh is already the login shell" {
  printf '#!/bin/sh\n' >"$HOME/bin/zsh"
  chmod +x "$HOME/bin/zsh"
  PATH="$HOME/bin:$PATH" SHELL="$HOME/bin/zsh" run install_zsh_login_shell
  [ "$status" -eq 0 ]
  [[ "$output" == *"既に zsh です"* ]]
  [ ! -s "$MOCK_LOG" ]
}

@test "zsh-login-shell: changes the shell and records it" {
  printf '#!/bin/sh\n' >"$HOME/bin/zsh"
  chmod +x "$HOME/bin/zsh"
  id() { printf 'tester'; }
  PATH="$HOME/bin:$PATH" SHELL=/bin/bash run install_zsh_login_shell
  [ "$status" -eq 0 ]
  grep -q "sudo chsh -s $HOME/bin/zsh tester" "$MOCK_LOG"
}

@test "zsh-login-shell: records the previous shell for uninstall" {
  printf '#!/bin/sh\n' >"$HOME/bin/zsh"
  chmod +x "$HOME/bin/zsh"
  id() { printf 'tester'; }
  PATH="$HOME/bin:$PATH" SHELL=/bin/bash install_zsh_login_shell
  [ "$(state_get setting login-shell 4)" = "/bin/bash" ]
}

@test "zsh-login-shell: skipped when zsh is missing" {
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  SHELL=/bin/bash PATH="$BATS_TEST_TMPDIR/empty" run install_zsh_login_shell
  [ "$status" -eq 0 ]
  [[ "$output" == *"zsh が見つかりません"* ]]
}

# --- mise trusted paths ----------------------------------------------------

@test "mise-trust: refuses \$HOME itself" {
  mise_at_home() { echo "mise $*" >>"$MOCK_LOG"; }
  AGENTYARD_MISE_TRUSTED_PATHS="$HOME" run install_mise_trust
  [ "$status" -eq 0 ]
  [[ "$output" == *"広すぎるため信頼しません"* ]]
  ! grep -q "settings add" "$MOCK_LOG"
}

@test "mise-trust: refuses a parent of \$HOME" {
  mise_at_home() { echo "mise $*" >>"$MOCK_LOG"; }
  AGENTYARD_MISE_TRUSTED_PATHS="$(dirname "$HOME")" run install_mise_trust
  [ "$status" -eq 0 ]
  [[ "$output" == *"広すぎるため信頼しません"* ]]
  ! grep -q "settings add" "$MOCK_LOG"
}

@test "mise-trust: no question when nothing is detected" {
  mise_at_home() { echo "mise $*" >>"$MOCK_LOG"; }
  run install_mise_trust </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"検出できませんでした"* ]]
  ! grep -q "settings add" "$MOCK_LOG"
}

@test "mise-trust: trusts a detected workspace directory" {
  mkdir -p "$HOME/github/org/repo/.git"
  mise_at_home() {
    case "$*" in
    "settings get trusted_config_paths") printf '[]\n' ;;
    *) echo "mise $*" >>"$MOCK_LOG" ;;
    esac
  }
  run install_mise_trust
  [ "$status" -eq 0 ]
  grep -q "settings add trusted_config_paths $HOME/github" "$MOCK_LOG"
}

# --- third-party notices ---------------------------------------------------

@test "notices: no run-time notice step exists" {
  ! declare -F print_agent_notices >/dev/null
  ! grep -q print_agent_notices "$SCRIPT_ROOT/scripts/setup.sh"
}

@test "notices: Antigravity's label carries the install-time terms" {
  [[ "$(registry_label antigravity)" == *"インストールで規約が適用"* ]]
}
