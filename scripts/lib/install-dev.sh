#!/bin/bash
# shellcheck disable=SC2088  # チルダはログメッセージ内の表示用であり、パス展開は不要
# scripts/lib/install-dev.sh
# 開発補助ツール（just, zoxide, shellcheck, chezmoi）のインストールと dotfiles 適用。
# 前提: lib/mise.sh, lib/shell_config.sh, lib/detect.sh が事前に source されていること。
#       SCRIPT_DIR 変数が呼び出し元で設定されていること（chezmoi の dotfiles パス解決用）。

# 10. 開発補助ツールのインストール
install_dev_tools() {
  [ "$INSTALL_DEV_TOOLS" != "1" ] && return

  echo ""
  echo "🛠️ 開発補助ツールをインストール中..."

  ensure_mise_installed || return 1

  # just / zoxide / shellcheck / chezmoi をすべて mise 経由で導入
  # （公式インストーラは GitHub API レートリミットで詰まりやすいため mise に統一）
  mise_use_global "just@1.50.0" "just"
  mise_use_global "zoxide@0.9.9" "zoxide"
  mise_use_global "shellcheck@0.11.0" "shellcheck"
  mise_use_global "chezmoi@2.70.2" "chezmoi"

  # zoxide のシェル初期化を追加（初回のみ）
  add_to_shell_config ~/.bashrc "zoxide init bash" 'eval "$(zoxide init bash)"' "~/.bashrc に zoxide 初期化を追加しました"
  add_to_shell_config ~/.zshrc "zoxide init zsh" 'eval "$(zoxide init zsh)"' "~/.zshrc に zoxide 初期化を追加しました"

  # ~/.zshrc.d/ 方式のセットアップ
  echo "📁 ~/.zshrc.d/ を準備中..."
  mkdir -p ~/.zshrc.d
  add_to_shell_config ~/.zshrc "zshrc.d" '# OzzyLabs 推奨設定の読み込み（~/.zshrc.d/*.zsh）
if [ -d ~/.zshrc.d ]; then
  for file in ~/.zshrc.d/*.zsh; do
    [ -r "$file" ] && source "$file"
  done
  unset file
fi' "~/.zshrc に ~/.zshrc.d/ の読み込み設定を追加しました"

  # chezmoi による設定適用（ADR-0003）
  # SCRIPT_DIR は scripts/ ディレクトリなので、1つ上がプロジェクトルート
  local repo_root
  repo_root="$(dirname "$SCRIPT_DIR")"
  if [ -d "$repo_root/dotfiles" ]; then
    echo ""
    echo "🏠 chezmoi で推奨設定を適用中..."
    # chezmoi apply は対話モード/非対話モードを問わず常に --force（非対話）で実行する。
    # 以前は interactive モードで `--interactive` を使っていたが、これは適用ファイル
    # ごとに `Apply <file>?` と尋ねるため、curl|bash でカテゴリ選択を y で進めた
    # ユーザーが見慣れない prompt を「ハング」と誤認して停止する UX トラップになって
    # いた。インストーラのこのステップに到達した時点で「推奨 dotfiles を適用する」
    # 意思は確認済みとみなせること、既存 shell 設定は ~/.zshrc.d/ 機構で保護済みで
    # あること、適用後の差分は `./install.sh doctor`（check_chezmoi_drift）で確認可能
    # であることから、chezmoi apply 自体は常に非対話とする。ADR-0003 参照。
    # （スクリプトのカテゴリ選択プロンプトの対話性は従来どおり維持される）
    # --force: 既存ファイルを上書き / --source: リポジトリ内 dotfiles を指定
    _mise_at_home exec chezmoi -- chezmoi apply --force --source "$repo_root/dotfiles"
    echo "  ✅ chezmoi による設定適用完了"

    # chezmoi apply で書き出された ~/.config/mise/config.toml に宣言されているが
    # 未インストールのツール（trivy 等、install_* 関数で明示的に mise_use_global
    # していないもの）を実体化する。これをやらないと lefthook の trivy フック等が
    # mise shim 解決失敗で落ちる（dotfiles テンプレート追加ツールは全てここでカバー）。
    echo "📦 chezmoi apply 後の mise install で template 追加ツールを実体化中..."
    if _mise_at_home install; then
      echo "  ✅ mise install 完了"
    else
      echo "  ⚠️  mise install に失敗しました（手動で確認: cd \$HOME && mise install）"
    fi
  fi

  echo "✅ 開発補助ツールインストール完了"
}
