#!/usr/bin/env bats
# =======================================================================
# tests/unit/install-languages.bats
# -----------------------------------------------------------------------
# scripts/lib/install-languages.sh の install_bun 関数を検証する。
# ensure_mise_installed / mise_use_global をモックして、外部依存
# （mise, network）を一切呼ばない。
#
# 検証範囲:
#   - INSTALL_BUN 未指定 / 0 → no-op（mise_use_global を呼ばない）
#   - INSTALL_BUN=1 → ensure_mise_installed + mise_use_global("bun@...") を呼ぶ
#
# NOTE: install_bun は真の opt-in（既定 OFF）であり、global mise config
# テンプレート (dotfiles/dot_config/mise/config.toml) には意図的に列挙しない。
# このため install_dev_tools の chezmoi apply より後に呼ぶ前提だが、関数単体の
# 振る舞い（フラグによる分岐）は呼び出し順序に依存しないためここで検証する。
# =======================================================================

bats_require_minimum_version 1.5.0

setup() {
  SCRIPT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  export MOCK_LOG="$BATS_TEST_TMPDIR/mock.log"
  : >"$MOCK_LOG"

  # shellcheck disable=SC1091
  source "$SCRIPT_ROOT/scripts/lib/install-languages.sh"

  ensure_mise_installed() {
    echo "ensure_mise_installed" >>"$MOCK_LOG"
    return 0
  }
  export -f ensure_mise_installed

  mise_use_global() {
    echo "mise_use_global $*" >>"$MOCK_LOG"
    return 0
  }
  export -f mise_use_global
}

# ------------------------------------------------------------------
# INSTALL_BUN 未指定 → no-op
# ------------------------------------------------------------------

@test "install_bun: no-op when INSTALL_BUN is unset" {
  unset INSTALL_BUN

  run install_bun
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_LOG" ]
}

# ------------------------------------------------------------------
# INSTALL_BUN=0 → no-op
# ------------------------------------------------------------------

@test "install_bun: no-op when INSTALL_BUN=0" {
  export INSTALL_BUN=0

  run install_bun
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_LOG" ]
}

# ------------------------------------------------------------------
# INSTALL_BUN=1 → ensure_mise_installed + mise_use_global("bun@...")
# ------------------------------------------------------------------

@test "install_bun: INSTALL_BUN=1 invokes mise_use_global with bun" {
  export INSTALL_BUN=1

  run install_bun
  [ "$status" -eq 0 ]
  grep -q "ensure_mise_installed" "$MOCK_LOG"
  grep -q "mise_use_global bun@" "$MOCK_LOG"
}

# ------------------------------------------------------------------
# install_mise_and_languages は INSTALL_BUN に影響されない
# （bun は別関数。INSTALL_NODE / INSTALL_PYTHON 双方 OFF なら no-op のまま）
# ------------------------------------------------------------------

@test "install_mise_and_languages: INSTALL_BUN does not trigger node/python path" {
  export INSTALL_BUN=1
  export INSTALL_NODE=0
  export INSTALL_PYTHON=0

  run install_mise_and_languages
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_LOG" ]
}
