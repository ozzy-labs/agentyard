#!/usr/bin/env bats
# tests/unit/answers.bats
# All questions are asked before the install starts (lib/answers.sh); the
# install steps read the collected answers instead of prompting.

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export AGENTYARD_CONFIG_DIR="$HOME/.config/agentyard"
  export AGENTYARD_ROOT="$SCRIPT_ROOT"
  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"
  unset AGENTYARD_ASSUME_YES AGENTYARD_MACOS_DOCKER
  export CI=false
  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/load.sh"
  # Nothing to ask unless a test says otherwise.
  _git_has() { return 0; }
  ubuntu_gh_replace_pending() { return 1; }
  selected() { return 1; }
  os_kind() { printf 'linux'; }
  is_wsl() { return 1; }
}

@test "answers: non-interactive mode asks nothing" {
  CI=true
  _git_has() { return 1; }
  run collect_answers </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "answers: Git identity is read once, up front" {
  _git_has() { return 1; }
  collect_answers <<<"$(printf 'ozzy\nozzy@example.com\n')"
  [ "$ANSWER_GIT_NAME" = "ozzy" ]
  [ "$ANSWER_GIT_EMAIL" = "ozzy@example.com" ]
}

@test "answers: an empty Git answer stays empty" {
  _git_has() { return 1; }
  collect_answers <<<"$(printf '\n\n')"
  [ -z "$ANSWER_GIT_NAME" ]
  [ -z "$ANSWER_GIT_EMAIL" ]
}

@test "answers: declining the gh replacement is remembered" {
  ubuntu_gh_replace_pending() { return 0; }
  apt_pkg_version() { printf '2.46.0-4'; }
  collect_answers <<<"n"
  [ "$ANSWER_GH_OFFICIAL" = "0" ]
}

@test "answers: accepting the gh replacement is the default" {
  ubuntu_gh_replace_pending() { return 0; }
  apt_pkg_version() { printf '2.46.0-4'; }
  collect_answers <<<""
  [ "$ANSWER_GH_OFFICIAL" = "1" ]
}

@test "answers: WSL systemd is only asked when docker is selected" {
  is_wsl() { return 0; }
  systemd_running() { return 1; }
  run collect_answers </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *"systemd"* ]]
  selected() { [ "$1" = "docker" ]; }
  collect_answers <<<"y"
  [ "$ANSWER_WSL_SYSTEMD" = "1" ]
}

@test "answers: macOS container runtime is chosen by number" {
  os_kind() { printf 'macos'; }
  selected() { [ "$1" = "docker" ]; }
  has_cmd() { [ "$1" != "docker" ]; }
  collect_answers <<<"2"
  [ "$ANSWER_MACOS_DOCKER" = "orbstack" ]
}

@test "git: configure_git uses the collected answers" {
  state_add() { :; }
  _git_has() { return 1; }
  git() { echo "git $*" >>"$MOCK_LOG"; }
  has_cmd() { return 0; }
  is_wsl() { return 1; }
  ANSWER_GIT_NAME="ozzy" ANSWER_GIT_EMAIL="ozzy@example.com" run configure_git
  [ "$status" -eq 0 ]
  grep -q 'git config --global user.name ozzy' "$MOCK_LOG"
  grep -q 'git config --global user.email ozzy@example.com' "$MOCK_LOG"
}

@test "git: without answers it warns instead of prompting" {
  _git_has() { return 1; }
  git() { echo "git $*" >>"$MOCK_LOG"; }
  has_cmd() { return 0; }
  run configure_git </dev/null
  [[ "$output" == *"user.name / user.email が未設定です"* ]]
  ! grep -q 'user.name ozzy' "$MOCK_LOG"
}
