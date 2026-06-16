#!/bin/bash
# =======================================================================
# tests/integration/assert-tools.sh
# -----------------------------------------------------------------------
# 主要ツールがインストール後にバージョン取得可能であることを検証。
# mise シム経由でのみ到達可能なツールも想定し、PATH を mise activate
# 相当で拡張してから各コマンドを呼ぶ。
# =======================================================================
set -u

# mise activate 相当の PATH 拡張（非インタラクティブシェルでもツールを解決）
export PATH="$HOME/.local/share/mise/shims:$HOME/.local/bin:$HOME/.local/share/pnpm:$PATH"

PASS=0
FAIL=0

# $1: ツール名（表示用）, $2...: バージョン取得コマンド
assert_tool() {
  local name="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    printf '  ✅ %-14s %s\n' "$name:" "$(printf '%s' "$output" | head -n1)"
    PASS=$((PASS + 1))
  else
    printf '  ❌ %-14s (command failed: %s)\n' "$name:" "$*"
    FAIL=$((FAIL + 1))
  fi
}

echo "🔧 Version manager / runtimes"
assert_tool "mise" mise --version
assert_tool "node" node --version
assert_tool "pnpm" pnpm --version
assert_tool "python3" python3 --version
assert_tool "uv" uv --version

echo ""
echo "🔒 Git / security"
assert_tool "git" git --version
assert_tool "gh" gh --version
assert_tool "gitleaks" gitleaks version
# trivy は dotfiles テンプレート (dot_config/mise/config.toml) で global pin される。
# 過去に chezmoi apply が trivy を消す回帰 (#153/#156) があったため、
# 統合テストで positive assertion を入れて再発を検知する。
assert_tool "trivy" trivy --version

echo ""
echo "🧠 AI power tools"
assert_tool "markitdown" markitdown --version
assert_tool "tesseract" tesseract --version
assert_tool "ffmpeg" ffmpeg -version
assert_tool "ast-grep" ast-grep --version
assert_tool "yq" yq --version

echo ""
echo "🛠️ Dev helpers"
assert_tool "just" just --version
assert_tool "zoxide" zoxide --version
assert_tool "shellcheck" shellcheck --version

echo ""
if [ "${INSTALL_CONTAINER:-1}" = "1" ]; then
  echo "🐳 Container / sandbox"
  assert_tool "bubblewrap" bwrap --version
  echo ""
fi

# Bun は opt-in（既定 OFF）。INSTALL_BUN=1 を明示したときだけ assert する。
if [ "${INSTALL_BUN:-0}" = "1" ]; then
  echo "🍞 Bun (opt-in)"
  assert_tool "bun" bun --version
  echo ""
fi

if [ "${INSTALL_TMUX:-0}" = "1" ] || [ "${INSTALL_ZELLIJ:-0}" = "1" ]; then
  echo "🪟 Terminal multiplexer"
  if [ "${INSTALL_TMUX:-0}" = "1" ]; then
    assert_tool "tmux" tmux -V
  fi
  if [ "${INSTALL_ZELLIJ:-0}" = "1" ]; then
    assert_tool "zellij" zellij --version
  fi
  echo ""
fi

echo "📌 Basic CLI"
assert_tool "tree" tree --version
assert_tool "fzf" fzf --version
assert_tool "jq" jq --version
assert_tool "rg" rg --version
assert_tool "fd" fd --version

echo ""
TOTAL=$((PASS + FAIL))
if [ "$FAIL" -eq 0 ]; then
  printf '✅ All %d tool assertions passed\n' "$TOTAL"
  exit 0
else
  printf '❌ %d of %d tool assertions failed\n' "$FAIL" "$TOTAL"
  exit 1
fi
