#!/usr/bin/env bats
# tests/unit/agents.bats
# Agent CLI installs: the vendor installer is driven unattended, and the
# outcome is judged by the binary rather than by the installer's exit status.

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  export BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
  export AGENTYARD_CONFIG_DIR="$HOME/.config/agentyard"
  # A clean PATH: the agents must not be found outside the test HOME.
  export PATH="$BIN_DIR:/usr/bin:/bin"
  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/core.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/state.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/agents.sh"
  selected() { return 0; }
}

# Stands in for the vendor installer: records the environment it was given,
# optionally drops the binary, and exits with MOCK_RC.
_mock_installer() {
  run_remote_installer() {
    printf 'installer %s CODEX_NON_INTERACTIVE=%s\n' "$1" "${CODEX_NON_INTERACTIVE:-}" >>"$MOCK_LOG"
    [ "${MOCK_INSTALLS:-1}" = "1" ] && printf '#!/bin/sh\n' >"$BIN_DIR/codex" && chmod +x "$BIN_DIR/codex"
    printf 'installer output line\n'
    return "${MOCK_RC:-0}"
  }
}

@test "codex: the installer runs with prompts disabled" {
  _mock_installer
  run install_agent codex
  [ "$status" -eq 0 ]
  grep -q 'installer https://chatgpt.com/codex/install.sh CODEX_NON_INTERACTIVE=1' "$MOCK_LOG"
}

@test "codex: a non-zero installer exit does not fail an install that worked" {
  _mock_installer
  MOCK_RC=130 run install_agent codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"exit 130"* ]]
  [[ "$output" == *"Codex CLI を導入しました"* ]]
  state_has agent codex
}

@test "codex: a missing binary is still a failure, with the installer output" {
  _mock_installer
  MOCK_INSTALLS=0 MOCK_RC=1 run install_agent codex
  [ "$status" -eq 1 ]
  [[ "$output" == *"インストールに失敗しました"* ]]
  [[ "$output" == *"installer output line"* ]]
  ! state_has agent codex
}

@test "codex: an installer that reports success is trusted, with a warning" {
  _mock_installer
  MOCK_INSTALLS=0 run install_agent codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"PATH に見つかりません"* ]]
  state_has agent codex
}

@test "codex: CODEX_NON_INTERACTIVE does not leak into the caller" {
  _mock_installer
  install_agent codex
  [ -z "${CODEX_NON_INTERACTIVE:-}" ]
}

@test "install_agent: an agent already installed by agentyard is recorded" {
  printf '#!/bin/sh\n' >"$BIN_DIR/codex"
  chmod +x "$BIN_DIR/codex"
  run install_agent codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"導入済み"* ]]
  state_has agent codex
}

@test "install_agent: an agent installed elsewhere is left unrecorded" {
  mkdir -p "$HOME/other/bin"
  printf '#!/bin/sh\n' >"$HOME/other/bin/codex"
  chmod +x "$HOME/other/bin/codex"
  PATH="$HOME/other/bin:$PATH" run install_agent codex
  [ "$status" -eq 0 ]
  ! state_has agent codex
}

@test "update_agents: codex reuses the same unattended installer" {
  _mock_installer
  state_add agent codex
  printf '#!/bin/sh\n' >"$BIN_DIR/codex"
  chmod +x "$BIN_DIR/codex"
  run update_agents
  [ "$status" -eq 0 ]
  grep -q 'installer https://chatgpt.com/codex/install.sh CODEX_NON_INTERACTIVE=1' "$MOCK_LOG"
}
