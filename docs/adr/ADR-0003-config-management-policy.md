# ADR-0003: 設定管理方針（chezmoi, Auto/Interactive モード）

## ステータス

承認済み

## コンテキスト

OzzyLabs 推奨のドットファイル設定をユーザー環境に適用する際、既存の設定を上書きせず、かつ安全・確実に行う仕組みが必要です。

## 決定

設定管理ツールとして `chezmoi` を採用し、セットアップスクリプトに「オート」と「インタラクティブ」の 2 つのモードを実装します。

- **chezmoi**: テンプレートベースの設定管理。
- **Auto (-y)**: 質問なしで推奨設定を適用（CI や新規構築用）。
- **Interactive**: インストール対象カテゴリの選択をユーザーに確認（既存環境用）。

### chezmoi apply は常に非対話（`--force`）で実行する

> 改訂（2026-06-16）: 当初は Interactive モードで `chezmoi apply --interactive`（適用ファイルごとに `Apply <file>?` と確認）を使っていたが、これを廃し **モードを問わず常に `chezmoi apply --force`** とする。

- **理由**: `--interactive` の per-file prompt は、`curl … | bash` でカテゴリ選択を `y` で進めたユーザーにとって、スクリプト本体の `[Y/n]` プロンプトとは異なる見慣れない UI として現れ、「ハングした」と誤認させる UX トラップになっていた（インストーラがそこで停止したように見える）。
- 「Interactive モード」は引き続き有効だが、その対話性が支配するのは **インストール対象カテゴリの選択プロンプト**（`scripts/lib/prompts.sh` の `_prompt_*`）であり、`chezmoi apply` ステップ自体は対象外とする。
- **安全性の担保**: インストーラのこのステップに到達した時点で「推奨 dotfiles を適用する」意思は確認済みとみなせる。既存の `.zshrc` 等は `~/.zshrc.d/` 機構（下記「影響」）で破壊されない。適用後の差分は `./install.sh doctor`（`check_chezmoi_drift`）で随時確認・再適用できる。
- 個別レビューしながら適用したい上級者は、セットアップ後に手動で `chezmoi apply --interactive --source <dotfiles>` を実行すればよい。
- 実装: `scripts/lib/install-dev.sh`（Linux）/ `scripts/setup-local-macos.sh`（macOS）の両 `install_dev_tools`。

## 理由

1. **安全なマージ**: `chezmoi` は既存のファイルを自動でバックアップし、変更の差分を確認・適用する機能が充実しています。
2. **柔軟性**: テンプレート機能により、OS やユーザー名に応じた動的な設定生成が可能です。
3. **非対話実行**: オートモードにより、開発環境の自動構築フローに容易に組み込めます。

## 注意: `chezmoi apply` による global mise config の上書き

本方針の運用で繰り返し発火した設計トラップ。回避策とチェック手段を明文化する。

### 事象

- `install_dev_tools`（Linux: `scripts/lib/install-dev.sh` / macOS: `scripts/setup-local-macos.sh`）の **末尾** で `chezmoi apply --source dotfiles` を実行する。
- 同 apply は `~/.config/mise/config.toml` を `dotfiles/dot_config/mise/config.toml` で **無条件に上書き**する。
- その結果、`install_*` スクリプトが先行して `mise use --global <tool>@<ver>` で導入したツールであっても、`dotfiles/dot_config/mise/config.toml` の `[tools]` テーブルに記載が無いものは **apply 直後に config から消える**（インストール済みバイナリは残るが、`mise` の global 選択から外れるため `mise exec --` や PATH 反映が壊れる）。

### 再発防止

- **グローバルに残すツールはすべて** `dotfiles/dot_config/mise/config.toml` の `[tools]` テーブルに明示列挙する。
- `install_*` スクリプトのツール追加時に、必ず同テンプレートにも追記する（PR レビュー観点）。
- `dotfiles/dot_config/mise/config.toml` をツールリストの **single source of truth** として扱い、ピンバージョンも同期する（ADR-0002「ピン運用ポリシー」参照）。

### 過去の発火例

- **PR #153** — `trivy` がテンプレートから漏れており、`chezmoi apply` 後に `mise exec -- trivy ...`（lefthook pre-commit）が壊れた。
- **PR #156** — `zellij`（PR #149 で opt-in 導入）が同じ理由で apply 後に消え、CI integration test が 4 連続失敗。

どちらも **同一の根本原因**であり、ツール追加時のチェック漏れで再発しうる。

### チェック手段

- `tests/integration/assert-tools.sh` の **post-chezmoi-apply assertion**（`trivy --version` / `zellij --version`）で回帰検出。
- `./install.sh doctor`（推奨：将来的に `check_trivy` / `check_zellij` などの個別チェッカーを追加）。

## 影響

- 推奨設定は `dotfiles/` ディレクトリにテンプレートとして集約します。
- 既存の `.zshrc` 等を破壊しないよう、`~/.zshrc.d/` などの独立した読み込み機構を併用します。
- `dotfiles/dot_config/mise/config.toml` はツール追加・ピン更新時に必ず同期更新する。

## 関連 ADR

- **ADR-0002** ツール選定（mise, uv, Docker 等） — グローバルに残すべきツールリストとピン運用ポリシー
- **ADR-0005** Terminal multiplexer 採用方針と macOS mise-first 再確認 — opt-in ツール（zellij）の dotfiles 列挙ルール適用例
