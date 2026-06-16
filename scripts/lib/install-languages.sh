#!/bin/bash
# scripts/lib/install-languages.sh
# mise + 言語環境（Node.js + pnpm + Python + uv）と gitleaks のインストール。
# 前提: lib/mise.sh が事前に source されていること。
#
# バージョン方針:
# aqua レジストリ経由のツール (pnpm, gitleaks 等) は、上流リリースとレジストリ
# 追従のずれにより任意の新バージョンが破綻し得るため、すべて具体パッチ版に
# 明示ピンする。更新は Renovate (mise manager) が自動 PR 化し、CI で検証する。
# core バックエンド (node, python) は対象外。
# uv は aqua レジストリの signer_workflow が Immutable Release に追従していない
# ため github バックエンドに切替済み。

# 4. mise + 言語環境のインストール
# mise を土台として Node.js / pnpm / Python / uv を統一管理
install_mise_and_languages() {
  # Node または Python のいずれかが必要な場合のみ処理
  if [ "$INSTALL_NODE" != "1" ] && [ "$INSTALL_PYTHON" != "1" ]; then
    return
  fi

  ensure_mise_installed || return 1

  # Node.js + pnpm を mise で導入
  if [ "$INSTALL_NODE" = "1" ]; then
    echo ""
    echo "📦 Node.js と pnpm を mise でインストール中..."
    mise_use_global "node@lts" "Node.js LTS"
    mise_use_global "pnpm@10.33.2" "pnpm"
  fi

  # Python + uv を mise で導入
  if [ "$INSTALL_PYTHON" = "1" ]; then
    echo ""
    echo "🐍 Python と uv を mise でインストール中..."
    mise_use_global "python@latest" "Python"
    mise_use_global "github:astral-sh/uv@0.11.9" "uv"
  fi

  echo "✅ mise + 言語環境インストール完了"
}

# 4b. Bun（opt-in）のインストール
# Bun-native な MCP サーバ等（bun:sqlite を使うアプリは npx/Node では動かない）を
# ホスト直で動かすための opt-in ランタイム / パッケージマネージャ / バンドラ。
# 既定 OFF（INSTALL_BUN=1 で有効化）。Node + pnpm の代替ではなく追加の選択肢。
#
# バージョン方針: bun は mise の core backend 扱いのため、node / python と同じ
# レンジ指定の例外に乗る（aqua レジストリ追従ずれ・具体パッチ版ピンの対象外）。
#
# 重要（呼び出し順序の制約）: 本関数は install_dev_tools の `chezmoi apply` より
# 後に呼ぶこと。bun は真の opt-in であり global mise config テンプレート
# (dotfiles/dot_config/mise/config.toml) には**意図的に列挙しない**（列挙すると
# 末尾の `mise install` で全ホストに入り opt-in でなくなる）。一方 chezmoi apply は
# global config を上書きするため、apply より前に `mise use --global` すると bun の
# 登録が消える（ADR-0003 / #153・#156 と同じ罠）。apply 後に登録することで回避する。
install_bun() {
  [ "${INSTALL_BUN:-0}" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🍞 Bun を mise でインストール中..."
  mise_use_global "bun@1" "Bun"
  echo "✅ Bun インストール完了"
}

# 5. Git セキュリティツール（gitleaks）のインストール
# git-secrets（メンテ停滞）の後継として gitleaks を mise 経由で導入
install_git_security_tools() {
  [ "$INSTALL_GIT_TOOLS" != "1" ] && return

  ensure_mise_installed || return 1

  echo ""
  echo "🔒 Git セキュリティツールをインストール中..."
  mise_use_global "gitleaks@8.30.1" "gitleaks"
  echo "✅ Git セキュリティツールインストール完了"
}
