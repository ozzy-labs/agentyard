# ADR-0005: Terminal multiplexer 採用方針と macOS mise-first 再確認

## ステータス

置き換え済み（[ADR-0007](./ADR-0007-host-first-redesign.md) により置き換え、2026-11-04。旧: 承認済み 2026-05-30）

## コンテキスト

AI エージェント駆動開発が常用フェーズに入り、以下の運用要件が顕在化した。

- **長時間 agent セッション**: 1 エージェント実行が数十分〜数時間に及ぶケースで、シェル接続が切れても継続実行できる土台が欲しい。
- **SSH detach / attach**: リモート開発機（EC2 / VPS）に SSH した状態で agent を流し、別端末から re-attach したい。
- **複数 agent の並列観測**: pane / window 分割で複数 agent の進捗を同時確認したい。

これらは **terminal multiplexer の典型ユースケース**である。一方で multiplexer の選好は強く割れる:

| multiplexer | 採用層 |
|---|---|
| tmux | 伝統派・SSH ヘビーユーザー |
| zellij | モダン派・キーバインド学習コストを嫌う層 |
| WezTerm built-in | WezTerm ユーザー |
| screen | 後方互換性のみ |
| なし | ローカル GUI ターミナル派 / Warp 等のモダンターミナルユーザー |

「全員に同じ multiplexer を強制」は明らかに不適。さらに、本リポは macOS で **mise-first 方針**（`brew install` を一切呼ばない）を採っており、tmux / zellij の配布チャネルもこの制約と両立する必要がある。

関連 PR:

- [#149](https://github.com/ozzy-labs/agentyard/pull/149) — feat(install): add zellij as opt-in multiplexer
- [#150](https://github.com/ozzy-labs/agentyard/pull/150) — feat(install): add tmux as opt-in + sensible .tmux.conf (Linux)
- [#156](https://github.com/ozzy-labs/agentyard/pull/156) — fix(dotfiles): include zellij in mise global config
- [#157](https://github.com/ozzy-labs/agentyard/pull/157) — refactor(scripts): unify Linux/macOS mise helpers via lib/mise.sh

## 決定

### 1. tmux / zellij は opt-in（default-off）

Azure / GCP CLI と同じパターン。`INSTALL_TMUX` / `INSTALL_ZELLIJ` 環境変数、または対話セレクタで明示有効化されたときのみ導入する。デフォルトでは何もしない。

### 2. tmux / zellij は独立フラグ（排他ではない）

`INSTALL_TMUX` と `INSTALL_ZELLIJ` は独立に on/off できる。両方有効にして併用するユーザーも実在する（用途別に使い分け）ため、ラジオボタン式の排他選択にはしない。

### 3. Linux: tmux=apt、zellij=mise pinned

- `tmux` は Ubuntu/Debian の apt パッケージで導入する（`apt_install_or_upgrade "tmux"`）。バージョンはディストリ依存だが、3.x 系であれば必要機能はすべて揃う。
- `zellij` は `mise use --global zellij@<pinned>`（aqua バックエンド）で導入する。ピンバージョンは ADR-0002 のポリシーに従う。

### 4. macOS: zellij=mise のみ自動化、tmux=README 案内に基づく手動

`setup-local-macos.sh` は **mise-first 方針** を維持する（`brew install` は一切呼ばない）。

- `zellij` は mise（aqua バックエンド）で自動導入できるため、Linux と同じ挙動。
- `tmux` は **mise から導入可能なビルドが無い**（aqua レジストリにも安定したエントリ無し）。よって `INSTALL_TMUX=1` を渡されても **自動インストールはせず、`ℹ️ macOS では tmux は手動インストール対象 (brew install tmux)` の案内のみ表示してスキップ**する。README にも手動案内のセクションを置く（PR #150）。

これは「macOS で brew を呼ばない」という mise-first 方針を曲げないための妥協で、tmux ユーザーが macOS で完全自動化を望む場合は別途 brew 導入を手元で実施する必要がある。

### 5. `~/.tmux.conf` は install スクリプトが直書き（chezmoi 経由にしない）

PR #150 の design decision #5。

- 既存ファイルが無い場合のみ、`install_multiplexer_tools()` 内で `cat > "$HOME/.tmux.conf"` する。
- 既存ファイルがある場合は **触らない**（`⏭️  ~/.tmux.conf は既に存在（上書きしません）` と表示してスキップ）。
- `dotfiles/dot_tmux.conf` テンプレートは作らない。理由: chezmoi 経由にすると `chezmoi apply` が non-opt-in ユーザーにも `.tmux.conf` を撒いてしまい、`INSTALL_TMUX=1` を渡していないユーザーへの汚染になる。

バンドルする `~/.tmux.conf` は意図的に最小・非主張。prefix 変更なし、vi/emacs mode-keys なし、tpm なし。truecolor / mouse / 1-base index / config reload bind のみ。

### 6. zellij は dotfiles テンプレートに列挙（chezmoi apply 後も残るため）

ADR-0003 の「グローバルに残すツールは `dotfiles/dot_config/mise/config.toml` に明示列挙」ルールを適用する。

- `zellij` は opt-in だが、有効化されたユーザーにとっては global mise config に残り続けるべき。
- `dotfiles/dot_config/mise/config.toml` に `zellij = "<pinned>"` を載せていなかった結果、PR #149 直後の CI が apply 後に zellij を失う回帰を起こした（PR #156 で修正）。
- 一方 `tmux` は apt パッケージなので mise の管理対象外であり、テンプレートには列挙しない。

## 理由

### opt-in 既定の妥当性

multiplexer 未使用ユーザー（モダンターミナル派、ローカル GUI 派）への配慮として、デフォルトでは導入しない。`INSTALL_*` フラグ + 対話セレクタという既存パターン（cloud CLI 等で確立済）に揃えることで、運用と説明の一貫性も担保する。

### 独立フラグの妥当性

zellij と tmux は **競合しない**。同一マシン上で「ローカル作業は zellij、SSH 先は tmux」のような併用は普通にあり得る。排他選択を強制すると、こうした実態と乖離する。

### macOS の tmux 手動対応の妥当性

mise-first 方針は本リポの中核ポリシーであり、tmux 1 ツールのために `brew install` への部分例外を作ると、以後 ad-hoc な例外要求が連鎖する。手動案内 + README ドキュメント化で十分回避可能なため、ポリシー優先とした。

### `.tmux.conf` を chezmoi に乗せない妥当性

chezmoi のスコープは「ユーザーが明示的に opt-in した dotfile セット」であり、multiplexer に opt-in していないユーザーに `.tmux.conf` が撒かれるのは想定外の副作用。install スクリプトが「ツールを入れたついでに最小 conf を直書きする」方が、副作用の境界がツール導入と一致して理解しやすい。

### zellij を dotfiles に列挙する妥当性

ADR-0003 で詳述した `chezmoi apply` による global mise config 上書きの帰結。opt-in ツールでも「有効化されたら apply 後も残る」ことを保証するには、テンプレート列挙が必須。

## 影響

### 新規 multiplexer 追加時のパターン

将来 fish-shell 用 multiplexer や別の opt-in シェル拡張を追加する際、本 ADR の決定群が共通テンプレートとして使える。

- 新ツールは原則 opt-in、フラグ名は `INSTALL_<TOOL>` で揃える。
- mise から導入可能 → `dotfiles/dot_config/mise/config.toml` に列挙してピン。
- apt のみ → Linux 自動化、macOS は手動案内（mise-first 方針）。
- 個別 conf を撒く場合は「既存尊重」「install スクリプトが直書き」「chezmoi 不使用」を原則とする。

### CI への影響

- `tests/integration/assert-tools.sh` の opt-in 系 assertion（`zellij --version` / `tmux -V`）が回帰検出ラインとして機能する。
- `tests/integration/entrypoint.sh` の 3rd run（`INSTALL_TMUX=1 INSTALL_ZELLIJ=1`）が両ツールの end-to-end カバレッジ。

### ドキュメントへの影響

- README に opt-in 手順、macOS の tmux 手動案内、`~/.tmux.conf` の既存ファイル尊重挙動を記述する（PR #149 / #150 で対応済み）。

## 関連 ADR

- **ADR-0002** ツール選定（mise, uv, Docker 等） — zellij のピン運用、mise 拡張ツール群の位置付け
- **ADR-0003** 設定管理方針（chezmoi, Auto/Interactive モード） — opt-in ツールを dotfiles テンプレートに列挙する根拠（`chezmoi apply` トラップ）
