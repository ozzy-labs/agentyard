#!/bin/bash
# scripts/lib/support.sh
# Supported platform gate (ADR-0007 §3).
#   Ubuntu 24.04 / 26.04 (amd64, arm64), macOS 26 / 27 (Apple Silicon).
# Unsupported platforms exit unless AGENTYARD_ALLOW_UNSUPPORTED=1.
# Requires lib/core.sh.

AGENTYARD_SUPPORTED_UBUNTU="24.04 26.04"
AGENTYARD_SUPPORTED_MACOS="26 27"

# Test seams: override in unit tests.
_SUPPORT_OS_RELEASE="${_SUPPORT_OS_RELEASE:-/etc/os-release}"

# Read a key from os-release (e.g. ID, VERSION_ID, VERSION_CODENAME).
os_release_get() {
  local key="$1" line
  [ -r "$_SUPPORT_OS_RELEASE" ] || return 1
  line="$(grep -E "^${key}=" "$_SUPPORT_OS_RELEASE" | head -n1)"
  [ -n "$line" ] || return 1
  line="${line#*=}"
  line="${line#\"}"
  line="${line%\"}"
  printf '%s' "$line"
}

ubuntu_codename() {
  os_release_get UBUNTU_CODENAME 2>/dev/null || os_release_get VERSION_CODENAME
}

normalized_arch() {
  case "$(uname -m)" in
  x86_64 | amd64) printf 'amd64' ;;
  aarch64 | arm64) printf 'arm64' ;;
  *) uname -m ;;
  esac
}

# Prints a reason and returns 1 when unsupported; returns 0 when supported.
support_check_reason() {
  local os arch
  os="$(os_kind)"
  arch="$(normalized_arch)"
  case "$os" in
  linux)
    local id ver
    id="$(os_release_get ID 2>/dev/null || true)"
    ver="$(os_release_get VERSION_ID 2>/dev/null || true)"
    if [ "$id" != "ubuntu" ]; then
      printf 'Linux ディストリビューション "%s" は非サポートです（Ubuntu 24.04 / 26.04 のみ）' "${id:-unknown}"
      return 1
    fi
    case " $AGENTYARD_SUPPORTED_UBUNTU " in
    *" $ver "*) ;;
    *)
      printf 'Ubuntu %s は非サポートです（24.04 / 26.04 のみ）' "${ver:-unknown}"
      return 1
      ;;
    esac
    if [ "$arch" != "amd64" ] && [ "$arch" != "arm64" ]; then
      printf 'アーキテクチャ %s は非サポートです（amd64 / arm64 のみ）' "$arch"
      return 1
    fi
    if is_wsl && ! _is_wsl2; then
      printf 'WSL1 は非サポートです（WSL2 を使ってください）'
      return 1
    fi
    ;;
  macos)
    local major
    major="$(sw_vers -productVersion 2>/dev/null | cut -d. -f1)"
    if [ "$arch" != "arm64" ]; then
      printf 'Intel Mac は非サポートです（Apple Silicon のみ）'
      return 1
    fi
    case " $AGENTYARD_SUPPORTED_MACOS " in
    *" $major "*) ;;
    *)
      printf 'macOS %s は非サポートです（%s のみ）' "${major:-unknown}" "$AGENTYARD_SUPPORTED_MACOS"
      return 1
      ;;
    esac
    ;;
  *)
    printf 'OS %s は非サポートです' "$(uname -s)"
    return 1
    ;;
  esac
  return 0
}

_is_wsl2() {
  # WSL2 runs a real Linux kernel ("microsoft-standard-WSL2"); WSL1 reports "Microsoft".
  grep -q 'WSL2' /proc/sys/kernel/osrelease 2>/dev/null || [ -d /run/WSL ]
}

# Exit unless supported (or explicitly overridden).
support_gate() {
  local reason
  if reason="$(support_check_reason)"; then
    return 0
  fi
  if [ "${AGENTYARD_ALLOW_UNSUPPORTED:-0}" = "1" ]; then
    log_warn "$reason"
    log_warn "AGENTYARD_ALLOW_UNSUPPORTED=1 が指定されたため、自己責任で続行します。"
    return 0
  fi
  log_error "$reason"
  log_info "サポート範囲: Ubuntu 24.04 / 26.04（amd64・arm64、WSL2 含む）、macOS 26 / 27（Apple Silicon）"
  log_info "Ubuntu 22.04 では agentyard v0.4.x を使うか、24.04 以降へアップグレードしてください（sudo do-release-upgrade）。"
  log_info "自己責任で続行する場合: AGENTYARD_ALLOW_UNSUPPORTED=1"
  exit 1
}
