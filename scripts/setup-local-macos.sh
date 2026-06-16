#!/bin/bash
# shellcheck disable=SC2088  # チルダはログメッセージ内の表示用であり、パス展開は不要
# shellcheck disable=SC2016  # シェル設定に遅延展開させる文字列をそのまま書き込む
set -e

# ========================================
# macOS ローカル環境セットアップスクリプト
# ----------------------------------------
# Phase 1 Wave 1: setup-local-linux.sh と同じく mise を入口にした
# 共通フローで開発環境を整える。Linux 側との重複を最小化するため、
# OS 固有の依存（Homebrew、apt の代替）以外はすべて mise / uv tool に集約する。
#
# 検証範囲（canary.yaml の macOS ジョブで CI 緑を維持）:
#   - mise（公式インストーラ）
#   - mise 経由のランタイム / CLI（node, pnpm, python, uv, gitleaks, ast-grep,
#     yq, just, zoxide, shellcheck）
#   - uv tool（markitdown[all]）
#
# Docker Desktop / AI エージェント CLI の自動セットアップは macOS では
# 未対応（ライセンス・インタラクティブ認証の都合）。READMEの該当章を参照。
# ========================================

# ========================================
# グローバル変数（インストール対象フラグ）
# ========================================
INSTALL_MISE_LANGUAGES="${INSTALL_MISE_LANGUAGES:-1}" # node + pnpm + python + uv
INSTALL_GIT_TOOLS="${INSTALL_GIT_TOOLS:-1}"           # gitleaks（mise 経由）
INSTALL_AI_POWER_TOOLS="${INSTALL_AI_POWER_TOOLS:-1}" # ast-grep, yq, markitdown
INSTALL_DEV_TOOLS="${INSTALL_DEV_TOOLS:-1}"           # just, zoxide, shellcheck, chezmoi
INSTALL_TMUX="${INSTALL_TMUX:-0}"                     # tmux（macOS では自動化対象外、READMEの手動案内のみ）
INSTALL_ZELLIJ="${INSTALL_ZELLIJ:-0}"                 # Zellij（opt-in、mise 経由）
INSTALL_BUN="${INSTALL_BUN:-0}"                       # Bun（opt-in、mise 経由、JS ランタイム/パッケージマネージャ）

# スクリプトのディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ========================================
# lib/*.sh の読み込み
# ----------------------------------------
# Linux 側 setup-local-linux.sh と同様、共通ロジックは lib/ に集約する。
# macOS 固有のインストール関数（install_mise_and_languages 等）は本ファイルに
# 残し、OS 中立な低レベルヘルパーのみ lib から import する。
# ========================================
# shellcheck source=lib/detect.sh
. "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/prompts.sh
. "$SCRIPT_DIR/lib/prompts.sh"
# shellcheck source=lib/shell_config.sh
. "$SCRIPT_DIR/lib/shell_config.sh"
# shellcheck source=lib/mise.sh
. "$SCRIPT_DIR/lib/mise.sh"

# `MISE_BIN` は lib/mise.sh が定義する（${MISE_BIN:-$HOME/.local/bin/mise}）。
# 後段のサマリー表示等で参照するため再エクスポートはせず、そのまま利用する。

# パイプ実行時 (curl ... | bash) でも対話プロンプトが動作するよう、
# stdin が tty でなく /dev/tty が読める場合は /dev/tty にフォールバックする。
_attach_tty_if_needed

# ========================================
# インストール関数群
# ========================================

# mise + 言語環境（Node.js + pnpm + Python + uv）
install_mise_and_languages() {
  [ "$INSTALL_MISE_LANGUAGES" != "1" ] && return

  ensure_mise_installed || return 1

  # バージョン方針: aqua レジストリ経由のツールは具体パッチ版に明示ピン。
  # uv は aqua の signer_workflow が Immutable Release に追従していないため
  # github バックエンドに切替。詳細は scripts/lib/install-languages.sh のヘッダ参照。
  echo ""
  echo "📦 Node.js / pnpm / Python / uv を mise でインストール中..."
  mise_use_global "node@lts" "Node.js LTS"
  mise_use_global "pnpm@10.33.2" "pnpm"
  mise_use_global "python@latest" "Python"
  mise_use_global "github:astral-sh/uv@0.11.9" "uv"
  echo "✅ mise + 言語環境インストール完了"
}

# Git セキュリティツール（gitleaks）
install_git_security_tools() {
  [ "$INSTALL_GIT_TOOLS" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🔒 Git セキュリティツール（gitleaks）を mise でインストール中..."
  mise_use_global "gitleaks@8.30.1" "gitleaks"
}

# AI パワーツール: ast-grep / yq（mise）+ markitdown（uv tool）
install_ai_power_tools() {
  [ "$INSTALL_AI_POWER_TOOLS" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🧠 AI パワーツールをインストール中..."
  mise_use_global "ast-grep@0.42.1" "ast-grep"
  mise_use_global "yq@4.53.2" "yq"

  if command -v uv &>/dev/null; then
    if ! uv tool list 2>/dev/null | grep -q "^markitdown"; then
      uv tool install "markitdown[all]" >/dev/null
      echo "  ✅ markitdown[all] インストール完了"
    else
      uv tool upgrade markitdown >/dev/null 2>&1 || true
      echo "  ⏭️  markitdown は導入済み・最新化しました"
    fi
  else
    echo "  ⚠️  uv が見つからないため markitdown はスキップしました"
  fi
}

# Terminal multiplexer（opt-in、mise 経由）
# zellij は aqua バックエンドで導入。tmux は macOS では自動化対象外（README §6.3.2 参照）。
# `INSTALL_TMUX=1` が指定された場合は notice のみ表示してスキップする（mise-first 方針を維持）。
install_multiplexer_tools() {
  # tmux は macOS では自動化しない（brew install tmux を README で案内）
  if [ "${INSTALL_TMUX:-0}" = "1" ]; then
    echo ""
    echo "ℹ️  macOS では tmux は手動インストール対象です (brew install tmux)"
    echo "    詳細は README §6.3.2 を参照してください"
  fi

  [ "${INSTALL_ZELLIJ:-0}" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🪟 Terminal multiplexer をインストール中..."
  mise_use_global "zellij@0.44.3" "Zellij"
}

# Bun（opt-in、JS ランタイム / パッケージマネージャ / バンドラ、mise 経由）
# Bun-native な MCP サーバ等（bun:sqlite を使うアプリは npx/Node では動かない）を
# ホスト直で動かすための opt-in ランタイム（既定 OFF、INSTALL_BUN=1 で有効化）。
# bun は mise core backend 扱いのため node / python と同じレンジ指定でピンする。
#
# 重要（呼び出し順序の制約）: 本関数は install_dev_tools の `chezmoi apply` より
# 後に呼ぶこと。bun は真の opt-in であり global mise config テンプレートには
# 意図的に列挙しないため、apply 前に登録すると上書きで消える（Linux 側
# scripts/lib/install-languages.sh の install_bun ヘッダと同じ理由）。
install_bun() {
  [ "${INSTALL_BUN:-0}" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🍞 Bun を mise でインストール中..."
  mise_use_global "bun@1" "Bun"
}

# 開発補助ツール: just / zoxide / shellcheck / chezmoi（mise）
install_dev_tools() {
  [ "$INSTALL_DEV_TOOLS" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🛠️ 開発補助ツールをインストール中..."
  mise_use_global "just@1.50.0" "just"
  mise_use_global "zoxide@0.9.9" "zoxide"
  mise_use_global "shellcheck@0.11.0" "shellcheck"
  mise_use_global "chezmoi@2.70.2" "chezmoi"

  add_to_shell_config "$HOME/.zshrc" "zoxide init zsh" 'eval "$(zoxide init zsh)"' "~/.zshrc に zoxide 初期化を追加しました"
  add_to_shell_config "$HOME/.bash_profile" "zoxide init bash" 'eval "$(zoxide init bash)"' "~/.bash_profile に zoxide 初期化を追加しました"
  add_to_shell_config "$HOME/.bashrc" "zoxide init bash" 'eval "$(zoxide init bash)"' "~/.bashrc に zoxide 初期化を追加しました"

  # ~/.zshrc.d/ 方式のセットアップ
  echo "📁 ~/.zshrc.d/ を準備中..."
  mkdir -p ~/.zshrc.d
  add_to_shell_config "$HOME/.zshrc" "zshrc.d" '# OzzyLabs 推奨設定の読み込み（~/.zshrc.d/*.zsh）
if [ -d ~/.zshrc.d ]; then
  for file in ~/.zshrc.d/*.zsh; do
    [ -r "$file" ] && source "$file"
  done
  unset file
fi' "~/.zshrc に ~/.zshrc.d/ の読み込み設定を追加しました"

  # chezmoi による設定適用（ADR-0003）
  local repo_root
  repo_root="$(dirname "$SCRIPT_DIR")"
  if [ -d "$repo_root/dotfiles" ]; then
    echo ""
    echo "🏠 chezmoi で推奨設定を適用中..."
    if _is_non_interactive; then
      _mise_at_home exec chezmoi -- chezmoi apply --force --source "$repo_root/dotfiles"
    else
      _mise_at_home exec chezmoi -- chezmoi apply --interactive --source "$repo_root/dotfiles"
    fi
    echo "  ✅ chezmoi による設定適用完了"

    # chezmoi apply で書き出された ~/.config/mise/config.toml に宣言されているが
    # 未インストールのツール（trivy 等、install_* 関数で明示的に mise_use_global
    # していないもの）を実体化する。dotfiles テンプレートに追加された全ツールを
    # ここでカバーする（Linux 側 install-dev.sh と同じ処理）。
    echo "📦 chezmoi apply 後の mise install で template 追加ツールを実体化中..."
    if _mise_at_home install; then
      echo "  ✅ mise install 完了"
    else
      echo "  ⚠️  mise install に失敗しました（手動で確認: cd \$HOME && mise install）"
    fi
  fi
}

# ========================================
# メイン処理開始
# ========================================

# ログ出力機能（SETUP_LOG 環境変数が設定されている場合）
if [ -n "${SETUP_LOG:-}" ]; then
  if [ "$SETUP_LOG" = "1" ] || [ "$SETUP_LOG" = "true" ]; then
    LOG_FILE="$HOME/setup-local-macos-$(date +%Y%m%d-%H%M%S).log"
  else
    LOG_FILE="$SETUP_LOG"
  fi
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "ℹ️  ログを $LOG_FILE に記録します"
fi

echo "🚀 macOS ローカル環境セットアップ開始（mise を入口にした共通フロー）"
echo ""

# 1. 環境チェック
if ! _is_darwin; then
  echo "⚠️  このスクリプトは macOS 専用です（現在の OS: $(uname -s)）"
  echo "ℹ️  Linux 環境では scripts/setup-local-linux.sh を使用してください"
  exit 1
fi

echo "✅ 実行環境チェック完了 ($(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null))"
echo ""

# 2. 依存ツールの確認: curl は macOS に標準同梱
if ! command -v curl >/dev/null 2>&1; then
  echo "⚠️  curl が見つかりません（macOS 標準同梱のはずです）"
  exit 1
fi

# 3. インストール処理
install_mise_and_languages
# install.sh が同梱する .mise.toml を信頼。これをやらないと末尾サマリで
# `node --version` 等の mise shim 呼び出しが "not trusted" で失敗する。
mise_trust_repo_config "$(dirname "$SCRIPT_DIR")"
install_git_security_tools
install_ai_power_tools
install_multiplexer_tools
install_dev_tools
# Bun (opt-in) は install_dev_tools の `chezmoi apply` 後に登録する（global mise
# config テンプレート非掲載の真の opt-in のため、apply 前だと wipe される）。
install_bun

# ========================================
# セットアップ完了サマリー
# ========================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 セットアップ結果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚡ バージョン管理:"
echo "  mise:           $("$MISE_BIN" --version 2>/dev/null | head -n1 || echo '未インストール')"
echo ""
echo "📦 言語ランタイム:"
echo "  Node.js:        $(_mise_at_home exec node@lts -- node --version 2>/dev/null || echo '未インストール')"
echo "  pnpm:           $(_mise_at_home exec pnpm -- pnpm --version 2>/dev/null || echo '未インストール')"
echo "  Bun:            $(_mise_at_home exec bun -- bun --version 2>/dev/null || echo '未インストール (opt-in)')"
echo "  Python:         $(_mise_at_home exec python -- python3 --version 2>/dev/null || echo '未インストール')"
echo "  uv:             $(_mise_at_home exec uv -- uv --version 2>/dev/null | head -n1 || echo '未インストール')"
echo ""
echo "🔒 Git セキュリティ:"
echo "  gitleaks:       $(_mise_at_home exec gitleaks -- gitleaks version 2>/dev/null || echo '未インストール')"
echo ""
echo "🧠 AI パワーツール:"
echo "  ast-grep:       $(_mise_at_home exec ast-grep -- ast-grep --version 2>/dev/null || echo '未インストール')"
echo "  yq:             $(_mise_at_home exec yq -- yq --version 2>/dev/null || echo '未インストール')"
echo "  markitdown:     $(command -v markitdown >/dev/null && markitdown --version 2>/dev/null || echo '未インストール')"
echo ""
echo "🛠️ 開発補助ツール:"
echo "  just:           $(_mise_at_home exec just -- just --version 2>/dev/null || echo '未インストール')"
echo "  zoxide:         $(_mise_at_home exec zoxide -- zoxide --version 2>/dev/null || echo '未インストール')"
echo "  shellcheck:     $(_mise_at_home exec shellcheck -- shellcheck --version 2>/dev/null | awk '/^version:/{print $2}' || echo '未インストール')"
echo "  chezmoi:        $(_mise_at_home exec chezmoi -- chezmoi --version 2>/dev/null || echo '未インストール')"
echo ""
echo "🪟 Terminal multiplexer:"
echo "  tmux:           $(tmux -V 2>/dev/null || echo '未インストール (brew install tmux で手動導入)')"
echo "  Zellij:         $(_mise_at_home exec zellij -- zellij --version 2>/dev/null || echo '未インストール (opt-in)')"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 macOS セットアップ完了！"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "次のステップ:"
echo "  1. シェルを再起動して mise activate を反映:"
echo "     exec \$SHELL -l"
echo ""
echo "  2. macOS では以下は手動セットアップが推奨です（自動化対象外）:"
echo "     - Docker Desktop（公式インストーラ: https://www.docker.com/products/docker-desktop）"
echo "     - AI エージェント CLI（Claude Code / Codex CLI / GitHub Copilot CLI / Gemini CLI）"
echo "     - クラウド CLI（aws / az / gcloud は brew install で導入可）"
echo ""
if [ -n "${LOG_FILE:-}" ]; then
  echo "ℹ️  セットアップログ: $LOG_FILE"
  echo ""
fi
