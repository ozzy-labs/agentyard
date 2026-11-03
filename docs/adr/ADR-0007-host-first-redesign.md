# ADR-0007: ホスト直接開発を基本とする構成とツール選定の全面見直し（v0.5.0）

## ステータス

承認済み（2026-11-04）

本 ADR は以下を置き換える（Superseded）:

- [ADR-0002](./ADR-0002-tool-selection.md)（ツール選定）
- [ADR-0003](./ADR-0003-config-management-policy.md)（chezmoi による設定管理）
- [ADR-0005](./ADR-0005-multiplexer-and-macos-policy.md)（multiplexer 方針と macOS mise-first）
- [ADR-0006](./ADR-0006-install-method-selection-policy.md)（インストール手段選定ポリシー、提案中のまま置き換え）

[ADR-0001](./ADR-0001-overall-architecture.md) と [ADR-0004](./ADR-0004-stay-bash-and-publish-readiness.md)（Bash のみで動かす）は維持する。

## コンテキスト

v0.4.x までの agentyard は、Dev Container 前提の「何でも入れる」構成だった。2026 年 11 月時点で次の問題がある。

- **既存設定の破壊**: `chezmoi apply --force` が `~/.claude/settings.json`、`~/.gemini/GEMINI.md` などを強制上書きする。テンプレートには存在しない設定キー（`permissions.autoAccept`）も含まれていた。
- **個人の好みの押し付け**: `LANG=ja_JP.UTF-8`、タイムゾーン、`pull.rebase=false`（既存値も上書き）、`core.editor=vim`、zsh プロンプトを既定で設定していた。
- **既定が過剰**: OCR / 音声処理（数百 MB）、lint ツール群、複数のクラウド CLI を全員に入れていた。lint ツールは各リポジトリの `mise.toml` で固定すべきもので、グローバルとの二重管理がバージョンずれを招いていた。
- **導入方法の不備**: Codex / Gemini を mise 管理の Node 配下に `npm -g` で入れていたため、Node の更新で消える。gcloud は `apt-key` に依存しており、26.04（apt 3.x）では入らない。
- **外部環境の変化**:
  - Ubuntu 26.04 LTS が現行。sudo-rs と uutils（Rust 版 coreutils）が既定になった。
  - Claude Code が v2.1.277 で AGENTS.md をネイティブに読むようになった。
  - Gemini CLI は 2026-06-18 以降、企業の Code Assist 契約者向けになり、個人は Antigravity CLI（`agy`）に移行した。brew の `gemini-cli` も非推奨。
- **CI の空白**: 26.04 が PR の CI に入っておらず、週次の canary は `disabled_inactivity` で停止していた。

AI エージェントを使った個人開発では、Dev Container の主な利点（チーム内での環境統一）は小さい。一方で、認証情報のマウントやツールの二重管理といった負担は常にかかる。エージェントの隔離は、各エージェントのサンドボックス（bubblewrap / Seatbelt）でホスト上でも実現できる。

## 決定

### 1. 目的

AI エージェントを使った開発のためのホストを構築する**公開ツール**とする。作業の主役はエージェントだが、人もターミナルで作業する。**ホストで直接開発するのを基本**とし、Dev Container は隔離や環境の再現が必要なときに使う。

### 2. 原則

1. エージェントがホストで安全に動けることを最優先にする（エージェント CLI、サンドボックス、認証）。
2. 既定は最小限、かつ実用的にする。好みが分かれるもの、リスクを伴うものは opt-in にする。例外として、主要なエージェント CLI は agentyard の目的そのものなので既定で入れる。
3. 個人の好みには触れない（プロンプト、エディタ、ロケール、エージェントの設定ファイル）。
4. パッケージは **① ツールの公式推奨の方法 → ② OS 標準のパッケージ管理（apt / Homebrew）→ ③ mise** の優先順で入れる。言語ランタイムは mise、Python 製アプリは uv tool。推奨と違う方法を選ぶ場合は理由を明記する。
5. プロジェクト固有のもの（lint ツール、言語、バージョン固定）は各リポジトリの `mise.toml` に任せる。
6. エージェントへの指示は AGENTS.md を標準とする。ユーザースコープの正本は `~/.agents/AGENTS.md`。リポジトリの AGENTS.md は作らない。
7. 既存のファイルや設定は上書きしない。ファイルがなければ作り、あれば目印で囲んだブロックを追記する。環境変数は既存の値の後ろに追加する。
8. agentyard が入れたもの・書き換えたものだけを扱う（記録し、update / uninstall の対象をそれに限る）。
9. 追加はするが削除はしない（選び直して再実行しても既存ツールは削除しない）。
10. ログインシェルかどうか、対話的かどうかにかかわらず、同じツールが見えるようにする。
11. 推測で実装しない。OS やツールの仕様に依存する処理は公式ドキュメントか実機で確認し、根拠の URL をコードに残す。
12. 依存を増やさない（ADR-0004 を維持）。

### 3. サポート範囲

| OS | アーキテクチャ |
|---|---|
| Ubuntu 24.04 / 26.04（WSL2、Desktop、Server） | amd64、arm64 |
| macOS 26 / 27（最新と 1 つ前のメジャー） | Apple Silicon |

Ubuntu 22.04 以前、Debian を含むその他の Linux、WSL1、Intel Mac、古い macOS は非サポートとし、既定で終了する。`AGENTYARD_ALLOW_UNSUPPORTED=1` で自己責任の続行を許す。スクリプトは GNU 独自のオプションに頼らない。

### 4. ツール

**前提**: Linux は ca-certificates、curl、unzip、openssh-client。macOS は管理者ユーザーと Homebrew（Xcode CLT は Homebrew のインストーラが入れる）。

**既定**

| 区分 | Linux | macOS |
|---|---|---|
| ビルド | build-essential、pkgconf、libssl-dev | Xcode CLT |
| Git | git（Ubuntu 標準）、git-lfs、gh（公式 apt リポジトリ） | git（CLT）、git-lfs、gh（brew） |
| CLI | jq、ripgrep、tree、fzf、fd-find（`~/.local/bin/fd` にリンク） | jq、ripgrep、tree、fzf、fd（brew） |
| サンドボックス | bubblewrap、socat | 不要（Seatbelt） |
| ランタイム | mise（公式インストーラ）、node LTS、pnpm、uv | 同じ |

**エージェント CLI（選択式、常に最新）**: Claude Code、Codex、Copilot CLI、Antigravity CLI は既定でチェックあり、Gemini CLI は opt-in。Gemini 以外は Linux / macOS とも公式インストーラ、Gemini CLI は mise の npm バックエンド（`npm:@google/gemini-cli@latest`）で入れる。Antigravity CLI を既定にするのは、WSL でキーリングを用いたログインが成立することを実機で確認できた場合に限る。必要なアカウントや契約は選択画面の項目名に示す。各エージェントの規約への同意は最初のログイン時に行われるため個別の確認は設けず、インストール時点で規約が適用される Antigravity CLI を選んだ場合だけ注意を表示する。agentyard はエージェントを操作しない。

**opt-in**: Docker（Linux は Docker Engine。Docker Desktop を検出したら入れない。macOS は Docker Desktop / OrbStack / Colima）、zsh と oh-my-zsh、tmux、zellij、AWS CLI、Azure CLI、gcloud、ast-grep、yq、markitdown、Bun。

**削除**: git の PPA、mise の python、gitleaks、trivy、shellcheck、just、chezmoi、zoxide、tesseract-ocr、ffmpeg。

**バージョン**: node / uv / Bun は範囲指定、pnpm はメジャー指定。mise で入れる固定ツール（zellij、ast-grep、yq）は同梱の mise 形式ファイルにまとめ、Renovate で更新する。エージェント、apt、brew、公式インストーラは常に最新。

### 5. AGENTS.md

- ユーザースコープの正本 `~/.agents/AGENTS.md` を作る（なければ雛形、あれば触れない）。末尾に agentyard が構築した事実だけを書いた「ホスト環境」ブロックを追記し、update で作り直す。
- 各エージェントへの連携:

| エージェント | 方法 |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` にブロックで `@~/.agents/AGENTS.md` を追記（なければ作成） |
| Antigravity CLI | `~/.gemini/AGENTS.md` にブロックで `@[agentyard](~/.agents/AGENTS.md)` を追記（なければ作成） |
| Copilot CLI | `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` に `$HOME/.agents` を追加 |
| Codex | `~/.codex/AGENTS.md` がなければ正本へのシンボリックリンク、あれば参照をブロックで追記 |
| Gemini CLI | `~/.gemini/GEMINI.md` がなければシンボリックリンク、あれば参照をブロックで追記 |

- エージェントの設定ファイルは編集しない。`~/.claude/AGENTS.md` は作らない。Gemini CLI と Antigravity CLI を併用し `GEMINI.md` が正本へのリンクの場合は、Antigravity 用のブロックを追加しない（二重読み込み防止）。

### 6. 設定

- **シェル（2 段構成）**: 環境（PATH、mise の shim、`brew shellenv`、Copilot の環境変数）を `~/.config/agentyard/env.sh`（POSIX sh）に置き、ログイン時の設定ファイル（`~/.profile`、`~/.zprofile`、macOS の `~/.bash_profile`）から読む。対話用（`env.sh` の読み込み、`mise activate`、fzf のキーバインド）を `~/.config/agentyard/interactive.sh` に置き、`~/.bashrc`、`~/.zshrc` から読む。存在するシェルの設定ファイルにだけ書き、Ubuntu では `~/.bash_profile` を新規作成しない。
- **Git**: `init.defaultBranch=main`（未設定時）、`core.autocrlf=input`（WSL のみ）、名前とメールは include 先も見て未設定時のみ確認、`git lfs install --skip-repo`。
- **apt**: deb822 形式に統一し、鍵は配布形式のまま `/etc/apt/keyrings/` に置く（gpg で変換しない）。Ubuntu のアップグレードを検出して書き直す。
- **Docker**: docker グループへの追加は root 相当の権限になると説明して確認する。WSL では systemd を確認し、無効なら Docker のインストールだけ中断する。
- **AppArmor**: 通常の Linux の 24.04 だけ、bwrap 用の対処を opt-in で用意し、緩める内容と影響を明示する。
- **WSL**: ブラウザを開くラッパーと `BROWSER`（opt-in）。Windows 側の PATH は変更しない。
- **記録**: Homebrew は `~/.config/agentyard/Brewfile`、それ以外は `~/.config/agentyard/state`。
- **廃止**: chezmoi の dotfiles 一式、ロケール、タイムゾーン、`pull.rebase`、`core.editor`、`core.fileMode`、devcontainer 用の事前ファイル作成。

### 7. コマンド

- `install`: セットアップ。対話モードは番号一覧の選択（whiptail があればチェックボックス）。非対話モードは `AGENTYARD_AGENTS`、`AGENTYARD_WITH`、`AGENTYARD_DOCKER_GROUP`。環境変数は `AGENTYARD_*` に統一し、旧名は移行期間中受け付ける。
- `doctor`: ツールの有無（非ログイン・非対話シェルからも）、エージェントのバージョン・ログイン・サンドボックス要件、AGENTS.md の連携状況、WSL の推奨設定、PATH の重複、新しいリリース、apt リポジトリの Ubuntu バージョン。
- `doctor --repo <path>`: 各エージェントがリポジトリの AGENTS.md を読む状態か（公式ドキュメントの条件のみで判定）。
- `update`: 新しいリリースの確認と通知。agentyard が入れたものだけを更新する（`mise self-update`、`mise upgrade <tools>`、`uv tool upgrade markitdown`、自動更新しないエージェント、Brewfile による `brew bundle`）。apt はユーザーに任せる。
- `uninstall`: agentyard が書き換えた箇所だけを戻す。apt リポジトリはそこから入れたツールが残る限り残す。ツール本体などは残し、一覧を表示する。

### 8. 配布と改ざん防止

リリースごとに配布用アーカイブ、チェックサム、GitHub Artifact Attestations を作る。`install.sh` は添付アーカイブをダウンロードしてチェックサムを確かめてから展開する。README の推奨手順はタグ指定（`--ref vX.Y.Z`）とし、`gh attestation verify` で確かめる手順も示す。

### 9. CI

PR ごとに Ubuntu 24.04 / 26.04（amd64、arm64）。macOS は関係する変更時のみ。週次 canary（次期 Ubuntu、macOS 26 / 27）を再開し、自動停止しないようにする。WSL 専用処理、24.04 の AppArmor、Ubuntu のアップグレード、各エージェントのログイン、シンボリックリンクの指示ファイル、非ログインシェルの環境は、`docs/` の手動確認項目でリリース前に確認する。

## 結果

### 良い点

- 既存の個人設定を壊さなくなる。どこを書き換えたかが明確になり、元に戻せる。
- 既定の導入量が大幅に減り、セットアップが速く、失敗しにくくなる。
- エージェント 5 種を公式推奨の方法で入れるため、各エージェントの更新の仕組みと衝突しない。
- AGENTS.md を正本として、複数のエージェントに同じ指示を届けられる。
- 24.04 / 26.04、amd64 / arm64、macOS 26 / 27 を CI で継続的に検証できる。

### トレードオフ

- 破壊的変更（v0.5.0）。chezmoi の dotfiles、Docker、zsh、クラウド CLI、OCR 等に依存していた既存ユーザーは、opt-in で選び直す必要がある。
- macOS の導入経路を mise から Homebrew に変えるため、`setup-local-macos.sh` はほぼ作り直しになる。
- 実機でしか確認できない項目（WSL、AppArmor、エージェントのログイン）が残る。

### 移行

- chezmoi で配置済みのファイル、既定から外れたツールは削除しない。
- 旧バージョンが書いた `~/.config/mise/config.toml` の項目と、`.bashrc` / `.zshrc` に直接書いた行は、差分を見せて削除するか選んでもらう（opt-in）。
- npm で入れた Codex / Gemini、mise で入れた macOS 用 CLI からの切り替え方、Gemini CLI から Antigravity CLI への移行ガイドを CHANGELOG で案内する。
- v0.4.x は 22.04 で動く最後のバージョンとする。
