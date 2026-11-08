#!/usr/bin/env bats
# tests/unit/agentsmd.bats
# Wiring the user-scope AGENTS.md into each installed agent is reported once:
# a re-run says so instead of claiming it added the wiring again.

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export AGENTYARD_CONFIG_DIR="$HOME/.config/agentyard"
  export AGENTYARD_ROOT="$SCRIPT_ROOT"
  export CI=true
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/load.sh"
  # Only Copilot is installed; it is the one wired through env.sh.
  agent_present() { [ "$1" = "copilot" ]; }
}

@test "copilot: the first run records the wiring and reports it" {
  run agents_md_wire
  [ "$status" -eq 0 ]
  [[ "$output" == *"COPILOT_CUSTOM_INSTRUCTIONS_DIRS"* ]]
  state_has setting copilot-dirs
}

@test "copilot: a re-run reports it as already wired" {
  agents_md_wire >/dev/null
  run agents_md_wire
  [ "$status" -eq 0 ]
  [[ "$output" == *"連携済み"* ]]
  [[ "$output" != *"追加"* ]]
}
