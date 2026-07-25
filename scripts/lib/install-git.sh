#!/bin/bash
# scripts/lib/install-git.sh
# Git および GitHub CLI のインストール。gitleaks は languages.sh で mise 経由で導入。

# 3. Gitツールのインストール
install_git_tools() {
  [ "$INSTALL_GIT_TOOLS" != "1" ] && return

  echo ""
  echo "🔧 バージョン管理ツールをインストール中..."

  # Git公式PPAが既に追加されているかチェック（.list / .sources 両形式を網羅）
  # PPA が当該 codename に未対応（Ubuntu devel 等）の場合、apt_add_ppa は登録せず
  # 非 0 を返す。その場合は distro 標準の git にフォールバックする（最新安定版では
  # なくなるが、apt 全体を巻き込んで停止させるよりはるかに望ましい）。
  if ! apt_ppa_registered "git-core" "git-core"; then
    if apt_add_ppa "git-core" "ppa" "F911AB184317630C59970973E363C90F8F1B6217" "git-core"; then
      sudo apt-get update >/dev/null
    else
      echo "  ℹ️  distro 標準の git を使用します"
    fi
  fi

  # Git のインストール・アップデート
  if ! command -v git &>/dev/null; then
    sudo apt-get install -y git
    echo "  ✅ Git インストール完了"
  else
    sudo apt-get install -y --only-upgrade git >/dev/null 2>&1
    echo "  ⏭️  Git は最新安定版です"
  fi

  # GitHub CLI のインストール・アップデート
  if ! command -v gh &>/dev/null; then
    # GitHub CLI公式リポジトリを追加
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null 2>&1
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y gh
    echo "  ✅ GitHub CLI インストール完了"
  else
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y --only-upgrade gh >/dev/null 2>&1
    echo "  ⏭️  GitHub CLI は最新安定版です"
  fi

  # gitleaks は mise 経由で導入（install_git_security_tools で実行）
  # シークレットスキャンはプロジェクト単位で lefthook 等のフックに組み込む運用を想定

  echo "✅ バージョン管理ツールインストール完了"
}
