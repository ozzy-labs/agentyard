#!/bin/bash
# scripts/lib/core.sh
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
# Shared primitives: version, logging, interactivity, tty, sudo, download.
# Source this file; do not execute it. Bash 3.2 compatible (macOS).

# Updated by release-please (see release-please-config.json extra-files).
AGENTYARD_VERSION="0.5.2" # x-release-please-version

AGENTYARD_REPO="ozzy-labs/agentyard"
AGENTYARD_CONFIG_DIR="${AGENTYARD_CONFIG_DIR:-$HOME/.config/agentyard}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log_section() { printf '\n━━ %s ━━\n' "$*"; }
log_info() { printf '  ℹ️  %s\n' "$*"; }
log_ok() { printf '  ✅ %s\n' "$*"; }
log_skip() { printf '  ⏭️  %s\n' "$*"; }
log_warn() { printf '  ⚠️  %s\n' "$*" >&2; }
log_error() { printf '  ❌ %s\n' "$*" >&2; }
die() {
  log_error "$*"
  exit 1
}

# ---------------------------------------------------------------------------
# Interactivity
# ---------------------------------------------------------------------------
# Non-interactive when AGENTYARD_ASSUME_YES=1 (legacy names honored) or CI=true.
is_non_interactive() {
  [ "${AGENTYARD_ASSUME_YES:-${AGENTIC_BOOTSTRAP_ASSUME_YES:-${BOOTSTRAP_ASSUME_YES:-0}}}" = "1" ] ||
    [ "${CI:-}" = "true" ]
}

# Attach /dev/tty when stdin is a pipe (curl | bash) in interactive mode.
attach_tty_if_needed() {
  if [ -t 0 ] || is_non_interactive; then
    return 0
  fi
  if [ -c /dev/tty ] && { exec </dev/tty; } 2>/dev/null; then
    return 0
  fi
  log_error "対話プロンプト用の TTY を確保できませんでした。"
  log_info "ファイルに保存して実行するか、非対話モード（AGENTYARD_ASSUME_YES=1）で実行してください。"
  exit 1
}

# ask_yes_no <prompt> <default: y|n>
# Returns 0 for yes. Non-interactive mode returns the default without reading.
ask_yes_no() {
  local prompt="$1" default="${2:-n}" reply hint
  if [ "$default" = "y" ]; then hint="[Y/n]"; else hint="[y/N]"; fi
  if is_non_interactive; then
    printf '%s %s %s (non-interactive)\n' "$prompt" "$hint" "$default"
    [ "$default" = "y" ]
    return
  fi
  printf '%s %s ' "$prompt" "$hint"
  reply=""
  read -r reply || true
  [ -z "$reply" ] && reply="$default"
  case "$reply" in
  [Yy]*) return 0 ;;
  *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Environment helpers
# ---------------------------------------------------------------------------
os_kind() {
  case "$(uname -s)" in
  Linux*) printf 'linux' ;;
  Darwin*) printf 'macos' ;;
  *) printf 'unknown' ;;
  esac
}

is_wsl() {
  [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Ensure ~/.local/bin and mise shims are on PATH for the current session.
session_path_setup() {
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
  local shims="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims"
  case ":$PATH:" in *":$shims:"*) ;; *) PATH="$shims:$PATH" ;; esac
  if [ -x /opt/homebrew/bin/brew ]; then
    case ":$PATH:" in *":/opt/homebrew/bin:"*) ;; *) PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" ;; esac
  fi
  export PATH
}

# Cache sudo credentials once (Linux / macOS).
ensure_sudo() {
  if [ "$(id -u)" = "0" ]; then
    return 0
  fi
  if ! has_cmd sudo; then
    die "sudo が見つかりません。"
  fi
  if ! sudo -n true 2>/dev/null; then
    if is_non_interactive; then
      die "非対話モードでは、パスワードなしで sudo を実行できる必要があります。"
    fi
    log_info "管理者権限が必要です（sudo のパスワードを入力してください）"
    sudo -v || die "sudo の認証に失敗しました。"
  fi
  _sudo_keepalive_start
}

# Keep the sudo timestamp fresh for the whole run so long steps (downloads,
# builds) never trigger a second password prompt. Stops when the parent exits.
_SUDO_KEEPALIVE_PID=""
_sudo_keepalive_start() {
  [ -n "$_SUDO_KEEPALIVE_PID" ] && return 0
  local parent=$$
  (
    while kill -0 "$parent" 2>/dev/null; do
      sudo -n true 2>/dev/null || exit 0
      sleep 50
    done
  ) >/dev/null 2>&1 &
  _SUDO_KEEPALIVE_PID=$!
  trap '_sudo_keepalive_stop' EXIT
}

_sudo_keepalive_stop() {
  if [ -n "$_SUDO_KEEPALIVE_PID" ]; then
    kill "$_SUDO_KEEPALIVE_PID" 2>/dev/null || true
    _SUDO_KEEPALIVE_PID=""
  fi
}

# quiet_run <cmd...>: hide output unless the command fails.
quiet_run() {
  local out rc
  out="$(mktemp)"
  if "$@" >"$out" 2>&1; then
    rm -f "$out"
    return 0
  else
    rc=$?
    sed 's/^/    | /' "$out" >&2
    rm -f "$out"
    return "$rc"
  fi
}

# Run a remote installer script fetched over HTTPS.
# run_remote_installer <url> <interpreter: bash|sh> [args...]
run_remote_installer() {
  local url="$1" interp="$2"
  shift 2
  curl --proto '=https' --tlsv1.2 -fsSL "$url" | "$interp" -s -- "$@"
}

# latest_release_version: prints the latest release version (without "v"),
# or nothing when offline / unavailable. AGENTYARD_OFFLINE=1 skips the call.
latest_release_version() {
  [ "${AGENTYARD_OFFLINE:-0}" = "1" ] && return 0
  curl -fsSL --max-time 10 "https://api.github.com/repos/$AGENTYARD_REPO/releases/latest" 2>/dev/null |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n1
}
