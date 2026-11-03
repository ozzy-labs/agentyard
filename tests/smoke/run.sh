#!/bin/bash
# =======================================================================
# tests/smoke/run.sh
# -----------------------------------------------------------------------
# セットアップスクリプトに対する最速のサニティチェック。
# ネットワーク・sudo・apt を一切使わず、5 秒以内に完了するよう設計。
#
# 検証内容:
#   - install.sh の引数解析 / --help 出力（pipe 実行を含む）
#   - update / uninstall の --help / --dry-run
#   - 全シェルスクリプトの構文チェック（bash -n）
#   - doctor の終了コード範囲
#
# Usage:
#   ./tests/smoke/run.sh
# =======================================================================
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

PASS=0
FAIL=0
START_TIME=$(date +%s%N)

# ------------------------------------------------------------------
# ヘルパー関数
# ------------------------------------------------------------------

# $1: テスト名, $2...: コマンドと引数
# stdout をキャプチャし exit 0 を期待
assert_success() {
  local name="$1"
  shift
  printf '▶ %s\n' "$name"
  if "$@" >/dev/null 2>&1; then
    printf '  ✅ pass\n'
    PASS=$((PASS + 1))
  else
    printf '  ❌ fail (exit=%d, cmd: %s)\n' "$?" "$*"
    FAIL=$((FAIL + 1))
  fi
}

# $1: テスト名, $2...: コマンドと引数
# exit 非 0 を期待
assert_failure() {
  local name="$1"
  shift
  printf '▶ %s\n' "$name"
  if "$@" >/dev/null 2>&1; then
    printf '  ❌ fail (expected non-zero exit, got 0)\n'
    FAIL=$((FAIL + 1))
  else
    printf '  ✅ pass (exit=%d)\n' "$?"
    PASS=$((PASS + 1))
  fi
}

# $1: テスト名, $2: 期待するパターン, $3...: コマンドと引数
# stdout に期待パターンが含まれることを検証
assert_stdout_contains() {
  local name="$1"
  local pattern="$2"
  shift 2
  printf '▶ %s\n' "$name"
  local output
  if output=$("$@" 2>/dev/null); then
    if printf '%s' "$output" | grep -q -- "$pattern"; then
      printf '  ✅ pass\n'
      PASS=$((PASS + 1))
    else
      printf '  ❌ fail (missing pattern: %s)\n' "$pattern"
      FAIL=$((FAIL + 1))
    fi
  else
    printf '  ❌ fail (command exited non-zero)\n'
    FAIL=$((FAIL + 1))
  fi
}

# ------------------------------------------------------------------
# 1. install.sh argument parsing
# ------------------------------------------------------------------

assert_stdout_contains "install.sh --help prints Usage" \
  "Usage:" \
  bash install.sh --help

assert_stdout_contains "install.sh --help lists commands" \
  "uninstall" \
  bash install.sh --help

assert_failure "install.sh rejects unknown flag" \
  bash install.sh --bogus-flag-xyz

assert_failure "install.sh rejects unknown positional arg" \
  bash install.sh unknown-subcommand

# curl | bash style: BASH_SOURCE[0] is not a file, so install.sh takes the
# download path. --help must still work (EXIT trap / set -u regressions).
assert_stdout_contains "install.sh works via stdin pipe (curl|bash style)" \
  "Usage:" \
  bash -c 'cat install.sh | bash -s -- --help'

assert_stdout_contains "install.sh --ref accepts value via stdin pipe" \
  "Usage:" \
  bash -c 'cat install.sh | bash -s -- --ref v0.5.0 --help'

# ------------------------------------------------------------------
# 2. update / uninstall argument parsing and dry-run
# ------------------------------------------------------------------

assert_stdout_contains "update --help describes scope" \
  "agentyard が入れたもの" \
  bash install.sh update --help

assert_stdout_contains "update --dry-run emits dry-run markers or skips" \
  "agentyard update" \
  env AGENTYARD_OFFLINE=1 bash install.sh update --dry-run

assert_failure "update.sh rejects unknown flag" \
  bash scripts/update.sh --bogus-flag-xyz

assert_stdout_contains "uninstall --dry-run without state is a no-op" \
  "元に戻すものはありません" \
  env AGENTYARD_CONFIG_DIR="$(mktemp -d)/none" bash install.sh uninstall --dry-run

# ------------------------------------------------------------------
# 3. Syntax checks (bash -n) for every script and library
# ------------------------------------------------------------------

for f in install.sh scripts/*.sh scripts/lib/*.sh scripts/lib/*/*.sh; do
  assert_success "syntax check: $f" bash -n "$f"
done

# ------------------------------------------------------------------
# 4. doctor exit code is within the documented range {0,1,2}
# ------------------------------------------------------------------

for args in "" "--repo ."; do
  printf '▶ doctor %s exit code in {0,1,2}\n' "$args"
  doctor_exit=0
  # shellcheck disable=SC2086  # $args is intentionally split
  AGENTYARD_OFFLINE=1 bash scripts/doctor.sh $args >/dev/null 2>&1 || doctor_exit=$?
  if [ "$doctor_exit" -ge 0 ] && [ "$doctor_exit" -le 2 ]; then
    printf '  ✅ pass (exit=%d)\n' "$doctor_exit"
    PASS=$((PASS + 1))
  else
    printf '  ❌ fail (exit=%d, expected 0/1/2)\n' "$doctor_exit"
    FAIL=$((FAIL + 1))
  fi
done

# ------------------------------------------------------------------
# 5. Identifier and layout pins
# ------------------------------------------------------------------

assert_stdout_contains "install.sh --help documents AGENTYARD_AGENTS" \
  "AGENTYARD_AGENTS" \
  bash install.sh --help

assert_stdout_contains "install.sh --help documents AGENTYARD_WITH" \
  "AGENTYARD_WITH" \
  bash install.sh --help

assert_success "install.sh REPO is ozzy-labs/agentyard" \
  grep -q '^readonly REPO="ozzy-labs/agentyard"$' install.sh

assert_success "core.sh carries the release-please version marker" \
  grep -q 'x-release-please-version' scripts/lib/core.sh

assert_success "config/tools.toml has a [tools] table" \
  grep -qx '\[tools\]' config/tools.toml

assert_success "renovate.json watches config/tools.toml" \
  grep -q 'tools' renovate.json

assert_success "lefthook.yaml defines agentyard-shell hook" \
  grep -q '^[[:space:]]*agentyard-shell:' lefthook.yaml

assert_success "release-please-config.json declares package-name agentyard" \
  grep -q '"package-name": "agentyard"' release-please-config.json

# ------------------------------------------------------------------
# サマリー
# ------------------------------------------------------------------

END_TIME=$(date +%s%N)
ELAPSED_MS=$(((END_TIME - START_TIME) / 1000000))
TOTAL=$((PASS + FAIL))

printf '\n'
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
if [ "$FAIL" -eq 0 ]; then
  printf '✅ All %d smoke tests passed (%dms)\n' "$TOTAL" "$ELAPSED_MS"
  exit 0
else
  printf '❌ %d of %d smoke tests failed (%dms)\n' "$FAIL" "$TOTAL" "$ELAPSED_MS"
  exit 1
fi
