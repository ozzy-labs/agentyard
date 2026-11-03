#!/usr/bin/env bash
# agentyard installer / dispatcher (ADR-0007).
#
#   ./install.sh [install|update|doctor|uninstall] [options]
#   curl --proto '=https' --tlsv1.2 -fsSL \
#     https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh | bash
#
# Remote runs download the release archive (agentyard.tar.gz) attached to a
# GitHub release and verify its SHA-256 before extracting it.
set -euo pipefail

readonly REPO="ozzy-labs/agentyard"
readonly ASSET="agentyard.tar.gz"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [command] [options]

Commands:
  install            Set up this host (default)
  update [--dry-run] Update what agentyard installed
  doctor [--repo P]  Diagnose the host, or whether agents read P/AGENTS.md
  uninstall          Revert the settings agentyard wrote (tools are kept)
  (legacy aliases: local, all -> install; zsh -> install with zsh)

Options:
  --ref <ref>   Release tag to download (e.g. v0.5.0). Default: latest release.
                A branch name (e.g. main) downloads the source archive
                without checksum verification (for development only).
  -y, --auto    Non-interactive: AGENTYARD_ASSUME_YES=1
  --interactive Force interactive prompts
  -h, --help    Show this help

Environment (non-interactive selection):
  AGENTYARD_AGENTS   claude,codex,copilot,antigravity,gemini
                     (default: claude,codex,copilot,antigravity)
  AGENTYARD_WITH     docker,zsh,tmux,zellij,aws,azure,gcloud,ast-grep,yq,
                     markitdown,bun,agents-md,mise-trust,wsl-browser,apparmor
                     ("power" = ast-grep,yq,markitdown)
  AGENTYARD_DOCKER_GROUP=1        add the user to the docker group
  AGENTYARD_MISE_TRUSTED_PATHS    directories for mise-trust (comma separated)
  AGENTYARD_MACOS_DOCKER          docker-desktop | orbstack | colima
  AGENTYARD_ALLOW_UNSUPPORTED=1   continue on unsupported platforms
  AGENTYARD_UI=plain              numbered list instead of whiptail
  SETUP_LOG=1                     tee output to ~/agentyard-setup-*.log
EOF
}

log() { printf '%s\n' "$*"; }
die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

download() {
  # download <url> <dest>
  curl --proto '=https' --tlsv1.2 -fsSL "$1" -o "$2"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print $1 }'
  else
    shasum -a 256 "$1" | awk '{ print $1 }'
  fi
}

# Fetch and extract agentyard for <ref>; prints the extracted root.
fetch_release() {
  local ref="$1" tmp="$2" base
  case "$ref" in
  latest) base="https://github.com/$REPO/releases/latest/download" ;;
  v[0-9]*) base="https://github.com/$REPO/releases/download/$ref" ;;
  *)
    log "⚠️  '$ref' はリリースのタグではありません。開発用としてソースを取得します（チェックサム検証なし）。" >&2
    download "https://codeload.github.com/$REPO/tar.gz/$ref" "$tmp/src.tar.gz" ||
      die "ダウンロードに失敗しました: $ref"
    tar -xzf "$tmp/src.tar.gz" -C "$tmp"
    find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1
    return
    ;;
  esac
  download "$base/$ASSET" "$tmp/$ASSET" || die "リリースの配布物を取得できませんでした: $base/$ASSET"
  download "$base/$ASSET.sha256" "$tmp/$ASSET.sha256" || die "チェックサムを取得できませんでした: $base/$ASSET.sha256"
  local expected actual
  expected="$(awk '{ print $1 }' "$tmp/$ASSET.sha256")"
  actual="$(sha256_of "$tmp/$ASSET")"
  [ -n "$expected" ] && [ "$expected" = "$actual" ] ||
    die "チェックサムが一致しません（expected=$expected actual=$actual）"
  log "✅ チェックサムを確認しました ($ASSET)" >&2
  mkdir -p "$tmp/agentyard"
  tar -xzf "$tmp/$ASSET" -C "$tmp/agentyard"
  printf '%s' "$tmp/agentyard"
}

dispatch() {
  local root="$1" cmd="$2"
  shift 2
  case "$cmd" in
  install) bash "$root/scripts/setup.sh" ;;
  update) bash "$root/scripts/update.sh" "$@" ;;
  doctor) bash "$root/scripts/doctor.sh" "$@" ;;
  uninstall) bash "$root/scripts/uninstall.sh" "$@" ;;
  *) die "不明なコマンド: $cmd" ;;
  esac
}

main() {
  local cmd="install" ref="${AGENTYARD_REF:-${AGENTIC_BOOTSTRAP_REF:-${BOOTSTRAP_REF:-latest}}}"
  local passthrough=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
    install | update | doctor | uninstall) cmd="$1" ;;
    local | all) cmd="install" ;;
    zsh)
      cmd="install"
      export AGENTYARD_WITH="${AGENTYARD_WITH:+$AGENTYARD_WITH,}zsh"
      log "ℹ️  'zsh' コマンドは廃止予定です。AGENTYARD_WITH=zsh を使ってください。"
      ;;
    --ref)
      [ "$#" -ge 2 ] || die "--ref には値が必要です"
      ref="$2"
      shift
      ;;
    -y | --auto) export AGENTYARD_ASSUME_YES=1 ;;
    --interactive) export AGENTYARD_ASSUME_YES=0 ;;
    -h | --help)
      if [ "$cmd" = "update" ]; then
        passthrough+=("$1")
      else
        usage
        exit 0
      fi
      ;;
    --dry-run | --repo) passthrough+=("$1") ;;
    *)
      if [ "${#passthrough[@]}" -gt 0 ] && [ "${passthrough[${#passthrough[@]} - 1]}" = "--repo" ]; then
        passthrough+=("$1")
      else
        die "不明な引数: $1（--help を参照）"
      fi
      ;;
    esac
    shift
  done

  # Local checkout: run in place.
  local self="${BASH_SOURCE[0]:-}"
  if [ -n "$self" ] && [ -f "$self" ]; then
    local dir
    dir="$(cd "$(dirname "$self")" && pwd)"
    if [ -f "$dir/scripts/setup.sh" ]; then
      dispatch "$dir" "$cmd" ${passthrough[@]+"${passthrough[@]}"}
      return
    fi
  fi

  command -v curl >/dev/null 2>&1 || die "curl が必要です"
  command -v tar >/dev/null 2>&1 || die "tar が必要です"
  local tmp root
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064  # expand now: tmp is local to main
  trap "rm -rf -- '$tmp'" EXIT
  log "==> agentyard ($ref) を取得しています"
  root="$(fetch_release "$ref" "$tmp")"
  [ -f "$root/scripts/setup.sh" ] || die "配布物の展開に失敗しました"
  dispatch "$root" "$cmd" ${passthrough[@]+"${passthrough[@]}"}
}

if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  main "$@"
fi
