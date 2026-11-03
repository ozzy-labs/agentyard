#!/usr/bin/env bats
# tests/unit/foundation.bats
# Unit tests for the v0.5.0 foundation libs: state, block, select, support,
# shellenv, tools.toml parsing. No network, sudo, or package managers.

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export AGENTYARD_CONFIG_DIR="$HOME/.config/agentyard"
  unset AGENTYARD_AGENTS AGENTYARD_WITH AGENTYARD_ASSUME_YES CI
  unset INSTALL_CONTAINER INSTALL_TMUX INSTALL_GEMINI_CLI INSTALL_CLAUDE_CODE
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/core.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/state.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/block.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/support.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/select.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/shellenv.sh"
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/mise.sh"
}

# --- state -----------------------------------------------------------------

@test "state: add / has / list / get / remove" {
  state_add apt-pkg jq
  state_add apt-repo docker /etc/apt/x.sources noble docker-ce
  state_has apt-pkg jq
  [ "$(state_list apt-pkg)" = "jq" ]
  [ "$(state_get apt-repo docker 4)" = "noble" ]
  state_remove apt-pkg jq
  ! state_has apt-pkg jq
}

@test "state: add is idempotent and updates extra columns" {
  state_add apt-repo docker f noble p
  state_add apt-repo docker f resolute p
  [ "$(grep -c '^apt-repo' "$(state_file)")" -eq 1 ]
  [ "$(state_get apt-repo docker 4)" = "resolute" ]
}

# --- block -----------------------------------------------------------------

@test "block: creates missing file and records it" {
  f="$HOME/new.rc"
  block_upsert "$f" "echo hi"
  grep -qx '# >>> agentyard >>>' "$f"
  grep -qx 'echo hi' "$f"
  state_has created "$f"
}

@test "block: appends to existing content without touching it" {
  f="$HOME/.bashrc"
  printf 'user line 1\nuser line 2\n' >"$f"
  block_upsert "$f" "echo hi"
  [ "$(sed -n 1p "$f")" = "user line 1" ]
  [ "$(sed -n 2p "$f")" = "user line 2" ]
  [ "$(sed -n 3p "$f")" = "" ]
  [ "$(sed -n 4p "$f")" = "# >>> agentyard >>>" ]
}

@test "block: upsert replaces in place and is idempotent" {
  f="$HOME/.bashrc"
  printf 'before\n' >"$f"
  block_upsert "$f" "v1"
  printf 'after\n' >>"$f"
  block_upsert "$f" "v2"
  block_upsert "$f" "v2"
  [ "$(grep -c '>>> agentyard' "$f")" -eq 1 ]
  grep -qx v2 "$f"
  ! grep -qx v1 "$f"
  [ "$(tail -n1 "$f")" = "after" ]
}

@test "block: handles file without trailing newline" {
  f="$HOME/.zshrc"
  printf 'no-newline' >"$f"
  block_upsert "$f" "x"
  [ "$(sed -n 1p "$f")" = "no-newline" ]
  grep -qx '# >>> agentyard >>>' "$f"
}

@test "block: remove restores original content" {
  f="$HOME/.bashrc"
  printf 'a\nb\n' >"$f"
  cp "$f" "$HOME/orig"
  block_upsert "$f" "x"
  block_remove "$f"
  cmp "$f" "$HOME/orig"
  ! state_has block "$f"
}

@test "block: markdown style markers" {
  f="$HOME/AGENTS.md"
  block_upsert "$f" "@~/.agents/AGENTS.md" md
  grep -qx '<!-- >>> agentyard >>> -->' "$f"
  block_present "$f" md
}

@test "block: edits symlink target, keeps the symlink" {
  printf 'target\n' >"$HOME/target.md"
  ln -s "$HOME/target.md" "$HOME/link.md"
  block_upsert "$HOME/link.md" "x" md
  [ -L "$HOME/link.md" ]
  grep -qx x "$HOME/target.md"
}

# --- select ----------------------------------------------------------------

@test "select: non-interactive defaults to three agents" {
  select_resolve_noninteractive
  [ "$SELECTED" = "claude codex copilot" ]
}

@test "select: AGENTYARD_AGENTS and AGENTYARD_WITH" {
  AGENTYARD_AGENTS="claude,gemini" AGENTYARD_WITH="docker,power" select_resolve_noninteractive
  selected claude
  selected gemini
  ! selected codex
  selected docker
  selected ast-grep
  selected yq
  selected markitdown
}

@test "select: unknown ids are ignored with a warning" {
  run bash -c "source '$SCRIPT_ROOT/scripts/lib/core.sh'; source '$SCRIPT_ROOT/scripts/lib/select.sh'; AGENTYARD_WITH=bogus select_resolve_noninteractive; echo \"[\$SELECTED]\""
  [[ "$output" == *"不明な項目"* ]]
  [[ "$output" == *"[claude codex copilot]"* ]]
}

@test "select: legacy INSTALL_* variables are mapped" {
  INSTALL_CONTAINER=1 INSTALL_TMUX=1 INSTALL_CLAUDE_CODE=0 INSTALL_GEMINI_CLI=1 select_resolve_noninteractive
  selected docker
  selected tmux
  selected gemini
  ! selected claude
}

@test "select: platform-specific settings are dropped when unavailable" {
  is_wsl() { return 1; }
  AGENTYARD_WITH="wsl-browser" select_resolve_noninteractive
  ! selected wsl-browser
}

@test "select: numbered toggling" {
  SELECTED="claude"
  _select_toggle_number 1
  ! selected claude
  _select_toggle_number 1
  selected claude
  ! _select_toggle_number 999
}

# --- support ---------------------------------------------------------------

_fake_os_release() {
  export _SUPPORT_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  printf 'ID=%s\nVERSION_ID="%s"\nVERSION_CODENAME=%s\nUBUNTU_CODENAME=%s\n' "$1" "$2" "$3" "$3" >"$_SUPPORT_OS_RELEASE"
}

@test "support: Ubuntu 24.04 and 26.04 are supported" {
  os_kind() { printf linux; }
  normalized_arch() { printf amd64; }
  is_wsl() { return 1; }
  _fake_os_release ubuntu 24.04 noble
  support_check_reason
  _fake_os_release ubuntu 26.04 resolute
  support_check_reason
  [ "$(ubuntu_codename)" = "resolute" ]
}

@test "support: Ubuntu 22.04 and Debian are rejected" {
  os_kind() { printf linux; }
  normalized_arch() { printf amd64; }
  is_wsl() { return 1; }
  _fake_os_release ubuntu 22.04 jammy
  ! support_check_reason >/dev/null
  _fake_os_release debian 13 trixie
  ! support_check_reason >/dev/null
}

@test "support: gate honors AGENTYARD_ALLOW_UNSUPPORTED" {
  os_kind() { printf linux; }
  normalized_arch() { printf amd64; }
  is_wsl() { return 1; }
  _fake_os_release ubuntu 22.04 jammy
  run support_gate
  [ "$status" -eq 1 ]
  AGENTYARD_ALLOW_UNSUPPORTED=1 run support_gate
  [ "$status" -eq 0 ]
}

# --- shellenv --------------------------------------------------------------

@test "shellenv: env.sh is valid POSIX sh and idempotent on PATH" {
  state_add setting copilot-dirs 1
  shellenv_write_files
  mkdir -p "$HOME/.local/bin"
  run sh -c ". '$AGENTYARD_CONFIG_DIR/env.sh'; . '$AGENTYARD_CONFIG_DIR/env.sh'; printf '%s\n' \"\$PATH\" | tr ':' '\n' | grep -c '^$HOME/.local/bin\$'; echo \"\$COPILOT_CUSTOM_INSTRUCTIONS_DIRS\""
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1" ]
  [ "${lines[1]}" = "$HOME/.agents" ]
}

@test "shellenv: Copilot dirs are appended, not replaced" {
  state_add setting copilot-dirs 1
  shellenv_write_files
  run sh -c "COPILOT_CUSTOM_INSTRUCTIONS_DIRS=/team; . '$AGENTYARD_CONFIG_DIR/env.sh'; echo \"\$COPILOT_CUSTOM_INSTRUCTIONS_DIRS\""
  [ "$output" = "/team,$HOME/.agents" ]
}

@test "shellenv: Linux wires ~/.profile and ~/.bashrc, never creates ~/.bash_profile" {
  os_kind() { printf linux; }
  has_cmd() { [ "$1" != "zsh" ] && command -v "$1" >/dev/null 2>&1; }
  printf '# ubuntu profile\n' >"$HOME/.profile"
  printf '# ubuntu bashrc\n' >"$HOME/.bashrc"
  shellenv_wire_rc_files
  grep -q 'agentyard/env.sh' "$HOME/.profile"
  grep -q 'agentyard/interactive.sh' "$HOME/.bashrc"
  [ ! -e "$HOME/.bash_profile" ]
  [ ! -e "$HOME/.zshrc" ]
}

@test "shellenv: Linux uses existing ~/.bash_profile as login file" {
  os_kind() { printf linux; }
  has_cmd() { [ "$1" != "zsh" ] && command -v "$1" >/dev/null 2>&1; }
  printf '# custom\n' >"$HOME/.bash_profile"
  shellenv_wire_rc_files
  grep -q 'agentyard/env.sh' "$HOME/.bash_profile"
  [ ! -e "$HOME/.profile" ]
}

@test "shellenv: interactive.sh is valid bash" {
  shellenv_write_files
  run bash -n "$AGENTYARD_CONFIG_DIR/interactive.sh"
  [ "$status" -eq 0 ]
}

# --- tools.toml ------------------------------------------------------------

@test "tools: versions are read from config/tools.toml" {
  AGENTYARD_TOOLS_FILE="$SCRIPT_ROOT/config/tools.toml"
  [ "$(tools_version node)" = "lts" ]
  [ "$(tools_version pnpm)" = "10" ]
  [ -n "$(tools_version zellij)" ]
  ! tools_version nonexistent >/dev/null || [ -z "$(tools_version nonexistent)" ]
}

# --- quiet_run / mise-trust candidates --------------------------------------

@test "quiet_run: hides output on success, shows it on failure" {
  run quiet_run sh -c 'echo noisy'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run quiet_run sh -c 'echo boom >&2; exit 3'
  [ "$status" -eq 3 ]
  [[ "$output" == *"| boom"* ]]
}

@test "mise-trust: suggests only workspace dirs that contain git repos" {
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/components/platform.sh"
  mkdir -p "$HOME/repos/a/.git" "$HOME/src" "$HOME/code/b"
  [ "$(_mise_trust_candidates)" = "~/repos" ]
  mkdir -p "$HOME/src/c/.git"
  [ "$(_mise_trust_candidates)" = "~/repos,~/src" ]
}

@test "block: BLOCK_CHANGED reports whether the file changed" {
  f="$HOME/.bashrc"
  printf 'a\n' >"$f"
  block_upsert "$f" "x"
  [ "$BLOCK_CHANGED" = "1" ]
  block_upsert "$f" "x"
  [ "$BLOCK_CHANGED" = "0" ]
  block_upsert "$f" "y"
  [ "$BLOCK_CHANGED" = "1" ]
}
