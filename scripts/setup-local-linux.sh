#!/bin/bash
# shellcheck disable=SC2088  # チルダはログメッセージ内の表示用であり、パス展開は不要
# shellcheck disable=SC2016  # シェル設定に遅延展開させる文字列をそのまま書き込む
# shellcheck disable=SC1091  # /etc/os-release は実行環境で提供される
set -e

# ========================================
# scripts/setup-local-linux.sh — Ubuntu/Debian 向けセットアップオーケストレータ
# ----------------------------------------
# 実装は scripts/lib/*.sh に分割されている。本スクリプトは以下のみ担当する:
# 1. 環境フラグのデフォルト設定
# 2. lib/*.sh の読み込み
# 3. 環境チェック（OS / 対話モード / sudo）
# 4. 対話的な選択（インストール対象 / Git ユーザー情報）
# 5. システム前提の準備（locale / timezone / devcontainer ディレクトリ / PATH）
# 6. install_* 関数群の呼び出し
# 7. 結果サマリー表示
# ========================================

# ========================================
# グローバル変数（インストール対象フラグ）
# ========================================
# 環境変数で事前に設定されている場合はそれを尊重（CI / Docker でのオーバーライド用途）

# 基本開発環境
INSTALL_BUILD_TOOLS="${INSTALL_BUILD_TOOLS:-1}" # build-essential
INSTALL_BASIC_CLI="${INSTALL_BASIC_CLI:-1}"     # tree, fzf, jq, ripgrep, fd, unzip
INSTALL_GIT_TOOLS="${INSTALL_GIT_TOOLS:-1}"     # Git, GitHub CLI, gitleaks

# プログラミング言語環境（mise で統一管理）
INSTALL_NODE="${INSTALL_NODE:-1}"     # mise + Node.js LTS + pnpm
INSTALL_PYTHON="${INSTALL_PYTHON:-1}" # mise + Python + uv
INSTALL_BUN="${INSTALL_BUN:-0}"       # mise + Bun（opt-in、JS ランタイム/パッケージマネージャ）

# コンテナ / サンドボックスツール
INSTALL_CONTAINER="${INSTALL_CONTAINER:-1}" # Docker, Docker Compose, bubblewrap

# クラウドツール（個別選択可能、Azure/GCP は opt-in）
INSTALL_AWS_CLI="${INSTALL_AWS_CLI:-1}"       # AWS CLI (デフォルト ON)
INSTALL_AZURE_CLI="${INSTALL_AZURE_CLI:-0}"   # Azure CLI (opt-in)
INSTALL_GCLOUD_CLI="${INSTALL_GCLOUD_CLI:-0}" # Google Cloud CLI (opt-in)

# AIエージェント CLI（個別選択可能）
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-1}" # Claude Code
INSTALL_CODEX_CLI="${INSTALL_CODEX_CLI:-1}"     # Codex CLI
INSTALL_COPILOT_CLI="${INSTALL_COPILOT_CLI:-1}" # GitHub Copilot CLI
INSTALL_GEMINI_CLI="${INSTALL_GEMINI_CLI:-1}"   # Gemini CLI

# AIパワーツール（エージェントの文書読み込み・検索を強化）
INSTALL_AI_POWER_TOOLS="${INSTALL_AI_POWER_TOOLS:-1}" # markitdown, tesseract-ocr(+jpn), ffmpeg, ast-grep, yq

# Terminal multiplexer（opt-in）
INSTALL_TMUX="${INSTALL_TMUX:-0}"     # tmux（opt-in、apt）
INSTALL_ZELLIJ="${INSTALL_ZELLIJ:-0}" # Zellij（opt-in）

# 開発補助ツール
INSTALL_DEV_TOOLS="${INSTALL_DEV_TOOLS:-1}" # just, zoxide, shellcheck, chezmoi

# ========================================
# グローバル変数（実行時に設定される値）
# ========================================

# スクリプトのディレクトリ（dotfiles 等の相対パス指定に使用）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ========================================
# lib/*.sh の読み込み
# ========================================
# shellcheck source=lib/detect.sh
. "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/prompts.sh
. "$SCRIPT_DIR/lib/prompts.sh"
# shellcheck source=lib/shell_config.sh
. "$SCRIPT_DIR/lib/shell_config.sh"
# shellcheck source=lib/apt.sh
. "$SCRIPT_DIR/lib/apt.sh"
# shellcheck source=lib/mise.sh
. "$SCRIPT_DIR/lib/mise.sh"
# shellcheck source=lib/docker.sh
. "$SCRIPT_DIR/lib/docker.sh"
# shellcheck source=lib/install-build.sh
. "$SCRIPT_DIR/lib/install-build.sh"
# shellcheck source=lib/install-basic-cli.sh
. "$SCRIPT_DIR/lib/install-basic-cli.sh"
# shellcheck source=lib/install-git.sh
. "$SCRIPT_DIR/lib/install-git.sh"
# shellcheck source=lib/install-languages.sh
. "$SCRIPT_DIR/lib/install-languages.sh"
# shellcheck source=lib/install-container.sh
. "$SCRIPT_DIR/lib/install-container.sh"
# shellcheck source=lib/install-cloud.sh
. "$SCRIPT_DIR/lib/install-cloud.sh"
# shellcheck source=lib/install-multiplexer.sh
. "$SCRIPT_DIR/lib/install-multiplexer.sh"
# shellcheck source=lib/install-ai-agents.sh
. "$SCRIPT_DIR/lib/install-ai-agents.sh"
# shellcheck source=lib/install-ai-power.sh
. "$SCRIPT_DIR/lib/install-ai-power.sh"
# shellcheck source=lib/install-dev.sh
. "$SCRIPT_DIR/lib/install-dev.sh"

# ========================================
# tty フォールバック（パイプ実行時の対話プロンプト対応）
# ========================================
_attach_tty_if_needed

# ========================================
# メイン処理開始
# ========================================

# ログ出力機能（SETUP_LOG 環境変数が設定されている場合）
if [ -n "${SETUP_LOG:-}" ]; then
  # SETUP_LOG=1 または SETUP_LOG=true の場合はデフォルトパスを使用
  if [ "$SETUP_LOG" = "1" ] || [ "$SETUP_LOG" = "true" ]; then
    LOG_FILE="$HOME/setup-local-linux-$(date +%Y%m%d-%H%M%S).log"
  else
    LOG_FILE="$SETUP_LOG"
  fi
  # プロセス置換と tee を使って標準出力とログファイルの両方に出力
  exec > >(tee -a "$LOG_FILE") 2>&1
  echo "ℹ️  ログを $LOG_FILE に記録します"
fi

echo "🚀 Linux (Ubuntu/Debian-based) ローカル環境セットアップ開始"
echo ""

# ========================================
# 1. 環境チェック
# ========================================

if [ ! -f /etc/os-release ]; then
  echo "⚠️  このスクリプトは Linux 環境でのみ実行できます"
  exit 1
fi

if ! _is_ubuntu_or_debian; then
  echo "⚠️  このスクリプトは Ubuntu/Debian 系向けに最適化されています。他 OS では動作保証外です。"
  echo "ℹ️  現在の OS: $(_os_pretty_name)"
  _prompt_default_no "続行しますか？ (y/N): "
  echo
  echo "ℹ️  ユーザー入力: $REPLY" # ログに記録
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "スクリプトを中止しました"
    exit 1
  fi
fi

echo "✅ 実行環境チェック完了"
echo ""

# ========================================
# 2. ツールの選択
# ========================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 インストール対象ツールの選択"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "インストール可能なツール:"
echo "  📌 基本CLIツール - tree, fzf, jq, ripgrep, fd, unzip"
echo "  🔧 ビルドツール - build-essential"
echo "  🔧 Git関連ツール - Git, GitHub CLI, gitleaks"
echo "  📦 Node.js環境 - mise, Node.js LTS, pnpm"
echo "  🐍 Python環境 - mise, Python, uv"
echo "  🍞 Bun (opt-in) - mise, Bun ランタイム / パッケージマネージャ"
echo "  🐳 コンテナ / サンドボックスツール - Docker Engine, Docker Compose, bubblewrap"
echo "  ☁️ クラウドツール - AWS CLI (default) / Azure CLI, Google Cloud CLI (opt-in)"
echo "  🪟 Terminal multiplexer - tmux / zellij (opt-in)"
echo "  🤖 AIエージェント CLI - Claude Code, Codex CLI, GitHub Copilot CLI, Gemini CLI"
echo "  🧠 AIパワーツール - markitdown, tesseract-ocr, ffmpeg, ast-grep, yq"
echo "  🛠️ 開発補助ツール - just, zoxide, shellcheck, chezmoi"
echo ""
echo "すべてのツールをインストールしますか？"
echo "  y: すべてインストール（デフォルト）"
echo "  n: 個別に選択"
echo ""
if _is_non_interactive; then
  INSTALL_ALL=Y
  echo "選択 [Y/n]: Y (non-interactive)"
else
  INSTALL_ALL=""
  read -p "選択 [Y/n]: " -n 1 -r INSTALL_ALL || true
  echo ""
fi
echo "ℹ️  ユーザー入力: ${INSTALL_ALL:-Y}"

if [[ ! $INSTALL_ALL =~ ^[Yy]?$ ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "各カテゴリのインストール設定"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  _prompt_default_yes "📌 基本CLIツール (tree, fzf, jq, ripgrep, fd) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_BASIC_CLI=0

  _prompt_default_yes "🔧 ビルドツール (build-essential) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_BUILD_TOOLS=0

  _prompt_default_yes "🔧 Git関連ツール (Git, GitHub CLI, gitleaks) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_GIT_TOOLS=0

  _prompt_default_yes "📦 Node.js環境 (mise, Node.js, pnpm) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_NODE=0

  _prompt_default_yes "🐍 Python環境 (mise, Python, uv) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_PYTHON=0

  _prompt_default_no "🍞 Bun (mise, JS ランタイム/パッケージマネージャ, opt-in) をインストールしますか? [y/N]: "
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_BUN=1

  _prompt_default_yes "🐳 コンテナ / サンドボックスツール (Docker, Docker Compose, bubblewrap) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_CONTAINER=0

  echo ""
  echo "☁️ クラウドツール:"
  _prompt_default_yes "  AWS CLI をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_AWS_CLI=0

  _prompt_default_no "  Azure CLI をインストールしますか? [y/N]: "
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_AZURE_CLI=1

  _prompt_default_no "  Google Cloud CLI をインストールしますか? [y/N]: "
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_GCLOUD_CLI=1

  echo ""
  echo "🪟 Terminal multiplexer:"
  _prompt_default_no "  tmux をインストールしますか? [y/N]: "
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_TMUX=1

  _prompt_default_no "  zellij をインストールしますか? [y/N]: "
  echo ""
  [[ $REPLY =~ ^[Yy]$ ]] && INSTALL_ZELLIJ=1

  echo ""
  echo "🤖 AIエージェント CLI:"
  _prompt_default_yes "  Claude Code をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_CLAUDE_CODE=0

  _prompt_default_yes "  Codex CLI をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_CODEX_CLI=0

  _prompt_default_yes "  GitHub Copilot CLI をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_COPILOT_CLI=0

  _prompt_default_yes "  Gemini CLI をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_GEMINI_CLI=0

  echo ""
  _prompt_default_yes "🧠 AIパワーツール (markitdown, tesseract-ocr, ffmpeg, ast-grep, yq) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_AI_POWER_TOOLS=0

  echo ""
  _prompt_default_yes "🛠️ 開発補助ツール (just, zoxide, shellcheck, chezmoi) をインストールしますか? [Y/n]: "
  echo ""
  [[ $REPLY =~ ^[Nn]$ ]] && INSTALL_DEV_TOOLS=0
fi

echo ""
echo "✅ インストール対象ツールの選択完了"
echo ""

# ========================================
# 3. 初期設定（ユーザー入力）
# ========================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 初期設定（ユーザー入力が必要な項目）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# sudo パスワード確認（最初に実行してキャッシュ）
echo "🔐 sudo パスワードの確認..."
if sudo -v; then
  echo "✅ sudo パスワード確認完了"
else
  echo "⚠️  sudo パスワードの確認に失敗しました"
  exit 1
fi
echo ""

# Git ユーザー情報の事前確認・設定
echo "🔧 Git ユーザー情報の確認..."

# user.name の確認・設定
if ! git config --global user.name &>/dev/null || [ -z "$(git config --global user.name)" ]; then
  echo ""
  echo "📝 Git ユーザー名が未設定です"
  read -r -e -p "Git ユーザー名を入力してください（例: Taro Yamada）: " -i "$USER" git_user_name
  echo "ℹ️  入力値: $git_user_name" # ログに記録
  if [ -n "$git_user_name" ] && [ -n "${git_user_name// /}" ]; then
    git config --global user.name "$git_user_name"
    echo "  ✅ user.name を設定しました: $git_user_name"
  else
    echo "  ⚠️  ユーザー名が入力されませんでした（後で 'git config --global user.name \"Your Name\"' で設定してください）"
  fi
else
  echo "  ⏭️  user.name は既に設定済み: $(git config --global user.name)"
fi

# user.email の確認・設定
if ! git config --global user.email &>/dev/null || [ -z "$(git config --global user.email)" ]; then
  echo ""
  echo "📝 Git メールアドレスが未設定です"
  read -r -e -p "Git メールアドレスを入力してください（例: your.email@example.com）: " git_user_email
  echo "ℹ️  入力値: $git_user_email" # ログに記録
  if [ -n "$git_user_email" ]; then
    if [[ "$git_user_email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      git config --global user.email "$git_user_email"
      echo "  ✅ user.email を設定しました: $git_user_email"
    else
      echo "  ⚠️  無効なメールアドレス形式です（後で 'git config --global user.email \"you@example.com\"' で設定してください）"
    fi
  else
    echo "  ⚠️  メールアドレスが入力されませんでした（後で 'git config --global user.email \"you@example.com\"' で設定してください）"
  fi
else
  echo "  ⏭️  user.email は既に設定済み: $(git config --global user.email)"
fi

echo ""
echo "✅ 初期設定完了"
echo ""

# ========================================
# 4. システムパッケージの更新と環境設定
# ========================================

# Locale と Timezone の設定
echo "🌏 ロケールとタイムゾーンを設定中..."

if [ "$(cat /etc/timezone 2>/dev/null)" != "Asia/Tokyo" ]; then
  sudo timedatectl set-timezone Asia/Tokyo 2>/dev/null || sudo ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
  echo "  ✅ タイムゾーンを Asia/Tokyo に設定しました"
else
  echo "  ⏭️  タイムゾーンは既に Asia/Tokyo に設定済み"
fi

if ! locale -a 2>/dev/null | grep -q "^ja_JP.utf8"; then
  sudo apt-get install -y locales
  sudo locale-gen ja_JP.UTF-8
  echo "  ✅ ja_JP.UTF-8 ロケールを生成しました"
else
  echo "  ⏭️  ja_JP.UTF-8 ロケールは既に生成済み"
fi

add_to_shell_config ~/.zshrc "export LANG=ja_JP.UTF-8" "export LANG=ja_JP.UTF-8" "~/.zshrc に LANG を設定しました"
add_to_shell_config ~/.bashrc "export LANG=ja_JP.UTF-8" "export LANG=ja_JP.UTF-8" "~/.bashrc に LANG を設定しました"

echo "✅ ロケールとタイムゾーン設定完了"
echo ""

# devcontainer マウント用のディレクトリ/ファイル作成
echo "📁 devcontainer マウント用のディレクトリ/ファイルを準備中..."

for dir in ~/.aws ~/.claude ~/.gemini ~/.config/gh ~/.local/share/pnpm; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    echo "  ✅ $dir を作成しました"
  fi
done

# PNPM_HOME の設定（未設定の場合のみ）
if [ -z "${PNPM_HOME:-}" ]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  echo "  ✅ PNPM_HOME を $PNPM_HOME に設定しました"
else
  echo "  ⏭️  PNPM_HOME は既に $PNPM_HOME に設定済み"
fi

# 現在のシェルセッションの PATH に PNPM_HOME を追加
if [[ ":$PATH:" != *":$PNPM_HOME:"* ]]; then
  export PATH="$PNPM_HOME:$PATH"
  echo "  ✅ PATH に PNPM_HOME ($PNPM_HOME) を追加しました"
else
  echo "  ⏭️  PATH には既に PNPM_HOME ($PNPM_HOME) が含まれています"
fi

# ファイルの作成（存在しない場合のみ）
if [ -f ~/.zshrc ] && [ ! -f ~/.zsh_history ]; then
  touch ~/.zsh_history
  echo "  ✅ ~/.zsh_history を作成しました"
fi

if [ ! -f ~/.gitconfig ]; then
  touch ~/.gitconfig
  echo "  ✅ ~/.gitconfig を作成しました"
fi

if [ ! -f ~/.claude.json ]; then
  echo '{}' >~/.claude.json
  echo "  ✅ ~/.claude.json を作成しました"
fi

echo "✅ devcontainer マウント用ファイル準備完了"
echo ""

# 基本パッケージの更新
echo "📦 システムパッケージを更新中..."
if sudo apt-get update >/dev/null; then
  echo "✅ システムパッケージ更新完了"
else
  echo "⚠️  システムパッケージの更新に失敗しました"
  echo "ℹ️  考えられる原因:"
  echo "    - ネットワーク接続の問題"
  echo "    - パッケージリポジトリの障害"
  echo "    - /etc/apt/sources.list の設定ミス"
  echo "ℹ️  手動で確認: sudo apt-get update"
  exit 1
fi

# 依存パッケージのインストール
echo ""
echo "🔧 依存パッケージをインストール中..."

# curl のインストール（mise, uv, AWS CLI 等に必要）
if ! command -v curl &>/dev/null; then
  sudo apt-get install -y curl
  echo "  ✅ curl インストール完了"
else
  echo "  ⏭️  curl は既にインストール済み"
fi

# git のインストール（最新安定版、後段でも install_git_tools が呼ばれるが
# 鍵 / source 設定を先に確立しておく）
echo ""
echo "🔧 Git（最新安定版）をインストール中..."

# PPA が当該 codename に未対応（Ubuntu devel 等）の場合、apt_add_ppa は登録せず
# 非 0 を返す。未対応 codename を登録すると以後の apt-get update が全滅するため、
# その場合は PPA を諦めて distro 標準の git にフォールバックする。
if ! apt_ppa_registered "git-core" "git-core"; then
  echo "  ℹ️  Git公式PPAを追加しています..."
  if apt_add_ppa "git-core" "ppa" "F911AB184317630C59970973E363C90F8F1B6217" "git-core"; then
    sudo apt-get update >/dev/null
    echo "  ✅ Git公式PPAを追加しました"
  else
    echo "  ℹ️  distro 標準の git を使用します"
  fi
fi

if ! command -v git &>/dev/null; then
  sudo apt-get install -y git
  echo "✅ Git インストール完了"
else
  CURRENT_VERSION=$(git --version 2>/dev/null | awk '{print $3}')
  sudo apt-get install -y --only-upgrade git >/dev/null 2>&1
  NEW_VERSION=$(git --version 2>/dev/null | awk '{print $3}')

  if [ "$CURRENT_VERSION" != "$NEW_VERSION" ]; then
    echo "✅ Git を最新安定版にアップデートしました ($CURRENT_VERSION → $NEW_VERSION)"
  else
    echo "⏭️  Git は既に最新安定版です ($CURRENT_VERSION)"
  fi
fi

echo "✅ 依存パッケージインストール完了"

# ========================================
# 5. インストール処理（lib/install-*.sh の関数呼び出し）
# ========================================
# 注意: 依存関係の順序で実行されます
# 1. ビルド → 2. 基本CLI → 3. Git (git, gh) → 4. mise + 言語環境
# → 5. Git セキュリティ (gitleaks) → 6. コンテナ / サンドボックス → 7. クラウド
# → 8. Terminal multiplexer (opt-in) → 9. AIエージェント
# → 10. AI パワーツール → 11. 開発補助 → 12. Bun (opt-in)

install_build_tools
install_basic_cli_tools
install_git_tools
install_mise_and_languages
# install.sh が同梱する .mise.toml を信頼。これをやらないと末尾サマリで
# `node --version` 等の mise shim 呼び出しが "not trusted" で失敗する。
mise_trust_repo_config "$(dirname "$SCRIPT_DIR")"
install_git_security_tools
install_container_tools
install_cloud_tools
install_multiplexer_tools
install_ai_tools
install_ai_power_tools
install_dev_tools
# Bun (opt-in) は install_dev_tools の `chezmoi apply`（global mise config を上書き）
# より後に登録する必要がある。bun は global config テンプレートに意図的に
# 列挙していない真の opt-in のため、apply 前に登録すると wipe される。
# 詳細は scripts/lib/install-languages.sh の install_bun ヘッダを参照。
install_bun

# ========================================
# 6. 環境設定（PATH、Git設定等）
# ========================================
# 注意: mise activate は install_mise_and_languages で追加済みのため、
# ここでは ~/.local/bin と pnpm の PATH のみを設定する

# Git の追加設定
if command -v git &>/dev/null; then
  echo ""
  echo "🔧 Git のその他の設定を行っています..."

  if ! git config --global init.defaultBranch &>/dev/null || [ -z "$(git config --global init.defaultBranch)" ]; then
    git config --global init.defaultBranch main
    echo "  ✅ init.defaultBranch を main に設定しました"
  else
    echo "  ⏭️  init.defaultBranch は既に $(git config --global init.defaultBranch) に設定済み"
  fi

  if ! git config --global core.editor &>/dev/null || [ -z "$(git config --global core.editor)" ]; then
    git config --global core.editor vim
    echo "  ✅ core.editor を vim に設定しました"
  else
    echo "  ⏭️  core.editor は既に $(git config --global core.editor) に設定済み"
  fi

  if [ "$(git config --global core.autocrlf)" != "input" ]; then
    git config --global core.autocrlf input
    echo "  ✅ core.autocrlf を input に設定しました（コミット時にCRLF→LF変換）"
  else
    echo "  ⏭️  core.autocrlf は既に input に設定済み"
  fi

  if [ "$(git config --global core.fileMode)" != "true" ]; then
    git config --global core.fileMode true
    echo "  ✅ core.fileMode を true に設定しました（実行権限追跡）"
  else
    echo "  ⏭️  core.fileMode は既に true に設定済み"
  fi

  if [ "$(git config --global pull.rebase)" != "false" ]; then
    git config --global pull.rebase false
    echo "  ✅ pull.rebase を false に設定しました"
  else
    echo "  ⏭️  pull.rebase は既に false に設定済み"
  fi

  # gitleaks はプロジェクト単位のフック（lefthook / pre-commit 等）で
  # 運用する前提のため、グローバルフックは設定しない

  echo "✅ Git 設定完了"
fi

# NOTE: BROWSER=wslview の自動設定は WSL2 専用のため agentyard の共通フローからは
# 除外している。WSL2 上で必要な場合は wslu インストール後に手動で追加する:
#   echo 'export BROWSER=wslview' >> ~/.zshrc

# PATH 環境変数の設定
echo ""
echo "🔧 PATH 環境変数を設定中..."

add_to_shell_config ~/.zshrc "PATH.*\.local/bin" "# ローカルユーザー向けバイナリ（mise, uv, just, codex, gemini 等）
export PATH=\"\$HOME/.local/bin:\$PATH\"" "~/.zshrc に ~/.local/bin の PATH を追加しました"
add_to_shell_config ~/.bashrc "PATH.*\.local/bin" "# ローカルユーザー向けバイナリ（mise, uv, just, codex, gemini 等）
export PATH=\"\$HOME/.local/bin:\$PATH\"" "~/.bashrc に ~/.local/bin の PATH を追加しました"

add_to_shell_config ~/.zshrc "PNPM_HOME.*\.local/share/pnpm" "# pnpm グローバルパッケージ
export PNPM_HOME=\"\$HOME/.local/share/pnpm\"
export PATH=\"\$PNPM_HOME:\$PATH\"" "~/.zshrc に pnpm の PATH を追加しました"
add_to_shell_config ~/.bashrc "PNPM_HOME.*\.local/share/pnpm" "# pnpm グローバルパッケージ
export PNPM_HOME=\"\$HOME/.local/share/pnpm\"
export PATH=\"\$PNPM_HOME:\$PATH\"" "~/.bashrc に pnpm の PATH を追加しました"

echo "✅ PATH 環境変数設定完了"

# ========================================
# 7. セットアップ完了メッセージ
# ========================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 セットアップ結果"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🌏 システム設定:"
echo "  タイムゾーン: $(cat /etc/timezone 2>/dev/null || echo '不明')"
CONFIGURED_LANG=$(grep "^export LANG=" ~/.zshrc ~/.bashrc 2>/dev/null | head -n1 | cut -d'=' -f2 || echo "${LANG:-未設定}")
echo "  ロケール:     $CONFIGURED_LANG"
echo "  シェル:       $SHELL"

echo ""
echo "🔧 Git 設定:"
echo "  user.name:           $(git config --global user.name 2>/dev/null || echo '未設定')"
echo "  user.email:          $(git config --global user.email 2>/dev/null || echo '未設定')"
echo "  init.defaultBranch:  $(git config --global init.defaultBranch 2>/dev/null || echo '未設定')"
echo "  core.editor:         $(git config --global core.editor 2>/dev/null || echo '未設定')"
echo "  core.autocrlf:       $(git config --global core.autocrlf 2>/dev/null || echo '未設定')"
echo "  core.fileMode:       $(git config --global core.fileMode 2>/dev/null || echo '未設定')"

echo ""
echo "🔧 インストールされたツール:"
echo ""
echo "  🔨 ビルドツール:"
echo "    build-essential: $(dpkg -l | grep -q build-essential && echo 'インストール済み' || echo '未インストール')"
echo ""
echo "  📌 基本CLIツール:"
echo "    tree:           $(tree --version 2>/dev/null | head -n1 || echo '未インストール')"
echo "    fzf:            $(fzf --version 2>/dev/null || echo '未インストール')"
echo "    jq:             $(jq --version 2>/dev/null || echo '未インストール')"
echo "    ripgrep (rg):   $(rg --version 2>/dev/null | head -n1 || echo '未インストール')"
echo "    fd:             $(fd --version 2>/dev/null || echo '未インストール')"
echo ""
echo "  🔧 バージョン管理:"
echo "    Git:            $(git --version 2>/dev/null || echo '未インストール')"
echo "    GitHub CLI:     $(gh --version 2>/dev/null | head -n1 || echo '未インストール')"
echo "    gitleaks:       $(gitleaks version 2>/dev/null || echo '未インストール')"
echo ""
echo "  ⚡ バージョン管理:"
echo "    mise:           $("$MISE_BIN" --version 2>/dev/null | head -n1 || mise --version 2>/dev/null | head -n1 || echo '未インストール')"
echo ""
echo "  📦 Node.js エコシステム:"
echo "    Node.js:        $(node --version 2>/dev/null || echo '未インストール')"
echo "    pnpm:           $(pnpm --version 2>/dev/null || echo '未インストール')"
echo "    Bun:            $(bun --version 2>/dev/null || echo '未インストール (opt-in)')"
echo ""
echo "  🐍 Python エコシステム:"
echo "    Python:         $(python3 --version 2>/dev/null || echo '未インストール')"
echo "    uv:             $(uv --version 2>/dev/null | head -n1 || echo '未インストール')"
echo ""
echo "  🐳 コンテナ / サンドボックスツール:"
echo "    bubblewrap:     $(bwrap --version 2>/dev/null || echo '未インストール')"
echo "    Docker:         $(docker --version 2>/dev/null || echo '未インストール')"
echo "    Docker Compose: $(docker compose version 2>/dev/null || echo '未インストール')"
echo ""
echo "  ☁️ クラウドツール:"
echo "    AWS CLI:        $(aws --version 2>/dev/null || echo '未インストール')"
echo "    Azure CLI:      $(az --version 2>/dev/null | head -n1 || echo '未インストール')"
echo "    Google Cloud:   $(gcloud --version 2>/dev/null | head -n1 || echo '未インストール')"
echo ""
echo "  🪟 Terminal multiplexer:"
echo "    tmux:           $(tmux -V 2>/dev/null || echo '未インストール (opt-in)')"
echo "    Zellij:         $(zellij --version 2>/dev/null || echo '未インストール (opt-in)')"
echo ""
echo "  🤖 AIエージェント CLI:"
echo "    Claude Code:        $(claude --version 2>/dev/null || echo '未インストール')"
echo "    Codex CLI:          $(codex --version 2>/dev/null || echo '未インストール')"
echo "    GitHub Copilot CLI: $([[ "$(command -v copilot 2>/dev/null)" == *".vscode-server"* ]] && echo '未インストール' || copilot --version 2>/dev/null | head -n1 || echo '未インストール')"
echo "    Gemini CLI:         $(gemini --version 2>/dev/null || echo '未インストール')"
echo ""
echo "  🧠 AI パワーツール:"
echo "    markitdown:     $(markitdown --version 2>/dev/null || echo '未インストール')"
echo "    tesseract:      $(tesseract --version 2>&1 | head -n1 || echo '未インストール')"
echo "    ffmpeg:         $(ffmpeg -version 2>/dev/null | head -n1 | awk '{print $1, $2, $3}' || echo '未インストール')"
echo "    ast-grep:       $(ast-grep --version 2>/dev/null || sg --version 2>/dev/null || echo '未インストール')"
echo "    yq:             $(yq --version 2>/dev/null || echo '未インストール')"
echo ""
echo "  🛠️ 開発補助ツール:"
echo "    just:           $(just --version 2>/dev/null || echo '未インストール')"
echo "    zoxide:         $(zoxide --version 2>/dev/null || echo '未インストール')"
echo "    shellcheck:     $(shellcheck --version 2>/dev/null | awk '/^version:/{print $2}' || echo '未インストール')"
echo "    chezmoi:        $(chezmoi --version 2>/dev/null || echo '未インストール')"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🎉 セットアップ完了！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "次のステップ:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. ターミナルを完全に閉じて再ログイン:"
echo "   exit"
echo ""
echo "2. クラウド認証情報を設定（インストール済みのものだけ）:"
echo "   # AWS (どちらかを実行)"
echo "   aws configure      # IAM ユーザーの場合"
echo "   aws configure sso  # SSO の場合"
echo ""
echo "   # Azure (opt-in でインストールした場合)"
echo "   az login"
echo ""
echo "   # Google Cloud (opt-in でインストールした場合)"
echo "   gcloud init"
echo ""
echo "3. GitHub 認証:"
echo "   gh auth login"
echo ""
echo "4. AI ツール認証:"
echo "   claude auth login   # Claude Code"
echo "   codex auth login    # Codex CLI"
echo "   copilot             # GitHub Copilot CLI（初回起動時に /login で認証）"
echo "   gemini              # Gemini CLI（初回起動時に Google アカウントで認証）"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -n "${SETUP_LOG:-}" ]; then
  echo "ℹ️  セットアップログ: $LOG_FILE"
  echo ""
fi
