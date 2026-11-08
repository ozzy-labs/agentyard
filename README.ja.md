# agentyard

**AI エージェントを使った開発のためのホストを構築する — Ubuntu 24.04 / 26.04（WSL2 を含む）と macOS**

[![Lint](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml)
[![Unit](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml)
[![Smoke](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml)
[![Integration](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml)
[![License: MIT](https://img.shields.io/github/license/ozzy-labs/agentyard)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/ozzy-labs/agentyard?label=release)](https://github.com/ozzy-labs/agentyard/releases/latest)

**[English](README.md) | 日本語**

agentyard は、AI エージェント（Claude Code、Codex、Copilot CLI、Antigravity CLI、Gemini CLI）がホスト上で直接、安全に作業でき、人も同じターミナルで作業できる開発ホストを構築します。既定は最小限で、好みが分かれるものはすべて opt-in です。既存のファイルは上書きしません。目印で囲んだブロックを追記するだけで、何を変えたかを記録し、元に戻せます。

設計方針: [ADR-0007](docs/adr/ADR-0007-host-first-redesign.md)。v0.4.x からの移行: [移行ガイド](docs/migration-v0.5.md)。

> **なぜ Bash か？** ランタイムを入れるツールが、ランタイムを必要とするべきではないからです。agentyard は依存のない Bash だけで動きます（[ADR-0004](docs/adr/ADR-0004-stay-bash-and-publish-readiness.md)）。

## クイックスタート

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh | bash
```

エージェントと opt-in の項目は選択画面で選びます。リリースを固定するには、`bash` の後ろに `-s -- --ref vX.Y.Z` を付けてください。

非対話モードの例:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh |
  AGENTYARD_ASSUME_YES=1 AGENTYARD_WITH=docker,agents-md bash
```

### 実行前に確かめる（任意）

GitHub CLI 2.49 以降が必要です（Ubuntu 標準の `gh` パッケージはそれより古いため、agentyard は公式版に置き換えます）。

リリースには `agentyard.tar.gz`（`install.sh` が SHA-256 で検証します）と `install.sh` が添付され、どちらにも [GitHub Artifact Attestations](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations) が付いています。

```bash
curl -fsSLO https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh
gh attestation verify install.sh --repo ozzy-labs/agentyard
bash install.sh
```

## サポート範囲

| OS | アーキテクチャ |
|---|---|
| Ubuntu 24.04 / 26.04（WSL2、Desktop、Server） | amd64、arm64 |
| macOS 26 / 27 | Apple Silicon |

それ以外（Ubuntu 22.04 以前、Debian などその他のディストリビューション、WSL1、Intel Mac）では、メッセージを出して終了します。`AGENTYARD_ALLOW_UNSUPPORTED=1` を指定すると自己責任で続行できます。Ubuntu 22.04 では agentyard v0.4.x を使ってください。

## インストールするもの

入れ方の優先順: ツールの公式推奨の方法 → OS のパッケージ管理（apt / Homebrew）→ mise。

### 既定

| 区分 | Linux | macOS |
|---|---|---|
| ビルド | build-essential、pkgconf、libssl-dev | Xcode Command Line Tools |
| Git | git（Ubuntu 標準）、git-lfs、gh（公式 apt リポジトリ） | git（CLT）、git-lfs、gh（brew） |
| CLI | jq、ripgrep、tree、fzf、fd | 同じものを Homebrew で |
| サンドボックス | bubblewrap、socat | macOS 標準（Seatbelt） |
| ランタイム | mise、Node.js LTS、pnpm、uv | 同じ |

### AI エージェント（選択式）

| エージェント | 既定 | 入れ方 |
|---|---|---|
| Claude Code | ✓ | 公式インストーラ |
| Codex CLI | ✓ | 公式インストーラ |
| GitHub Copilot CLI | ✓ | 公式インストーラ（Copilot の契約が必要） |
| Antigravity CLI | opt-in | 公式インストーラ（18 歳以上、対応国。インストール時点で規約が適用） |
| Gemini CLI | opt-in | npm パッケージを mise で管理（Gemini Code Assist 契約者向け） |

agentyard はエージェントをインストールするだけで、操作はしません。各エージェントの利用規約には最初のログイン時に同意します。ただし Antigravity CLI はインストールした時点で規約が適用されるため、選択画面の項目名にそう書いてあります。agentyard が入れるものすべてのライセンス・規約の適用時点・データ収集の既定・商用の条件は [docs/third-party.md](docs/third-party.md) に根拠付きでまとめてあります。

### opt-in（`AGENTYARD_WITH`）

| ID | 内容 |
|---|---|
| `docker` | Linux: Docker Engine（Docker Desktop の WSL 連携を検出したら入れない）。macOS: Docker Desktop / OrbStack / Colima |
| `zsh` | zsh + oh-my-zsh（既存の `~/.zshrc` は残す） |
| `docker-group` | 自分を `docker` グループに追加する。`sudo` なしで docker を使えるが実質 root 権限で、シェルを使えるエージェントはサンドボックスを抜け出せる（[理由](https://docs.docker.com/engine/install/linux-postinstall/)） |
| `zsh-login-shell` | ログインシェルを zsh にする |
| `tmux`、`zellij` | ターミナルの分割ツール |
| `aws`、`azure`、`gcloud` | クラウド CLI |
| `ast-grep`、`yq`、`markitdown`（`power` で 3 つすべて） | エージェント補助ツール |
| `bun` | Bun ランタイム |
| `agents-md` | ユーザースコープの `~/.agents/AGENTS.md` と、各エージェントへの連携 |
| `mise-trust` | 作業ディレクトリ配下の mise 設定を信頼し、エージェントが `mise trust` で止まらないようにする（自動検出、または `AGENTYARD_MISE_TRUSTED_PATHS` で指定。`$HOME` とその上位は拒否） |
| `wsl-browser` | WSL: ログイン画面を Windows のブラウザで開く |
| `apparmor` | Ubuntu 24.04（WSL 以外）: bubblewrap がユーザー名前空間を作れるようにする |

プロジェクト固有のツール（lint、フック、言語のバージョン、Go / Rust）は、各リポジトリの `mise.toml` で管理してください。mise がその場で入れます。

## コマンド

```bash
./install.sh install          # ホストのセットアップ（既定）
./install.sh update           # agentyard が入れたものだけを更新
./install.sh doctor           # ホストの診断（終了コード 0: 正常 / 1: 警告 / 2: エラー）
./install.sh doctor --repo .  # 入れたエージェントがこのリポジトリの AGENTS.md を読むか
./install.sh uninstall        # agentyard が書き換えた設定を元に戻す（ツール本体は残す）
```

入力が必要なことは、インストールを始める前にすべて聞きます。選択画面で項目を選び、そこから決められないもの（Git の名前とメールアドレス、ホストの状態によって変わる確認）に答えると、あとは止まらずに進みます。

`update` は、mise と agentyard が mise に追加したツール、uv tool、自動更新しないエージェント、agentyard の Brewfile にあるもの（macOS）を更新します。apt のパッケージは `sudo apt update && sudo apt upgrade` で更新してください。

## 環境変数

| 変数 | 意味 |
|---|---|
| `AGENTYARD_ASSUME_YES=1`（または `-y`、`CI=true`） | 非対話モード |
| `AGENTYARD_AGENTS` | 入れるエージェント（既定 `claude,codex,copilot`） |
| `AGENTYARD_WITH` | opt-in の項目（カンマ区切り、上表参照） |
| `AGENTYARD_DOCKER_GROUP=1` | `AGENTYARD_WITH=docker-group` と同じ |
| `AGENTYARD_MISE_TRUSTED_PATHS` | `mise-trust` で信頼するディレクトリ（カンマ区切り） |
| `AGENTYARD_MACOS_DOCKER` | `docker-desktop`、`orbstack`、`colima` のいずれか |
| `AGENTYARD_ALLOW_UNSUPPORTED=1` | 非サポートの環境でも続行する |
| `AGENTYARD_UI=plain` | whiptail の画面の代わりに番号入力で選ぶ |
| `AGENTYARD_REF` | ダウンロードするリリースのタグ（`--ref` と同じ） |
| `SETUP_LOG=1` | ログを `~/agentyard-setup-*.log` に書き出す |

旧来の `INSTALL_*` 変数は、移行期間中は引き続き受け付けます。

## ホストに加える変更

- **シェル**: `~/.config/agentyard/env.sh`（POSIX sh。PATH、mise の shim、Homebrew）をログイン時の設定ファイル（`~/.profile`、`~/.zprofile`）から、`~/.config/agentyard/interactive.sh`（`mise activate`、fzf のキーバインド）を `~/.bashrc` / `~/.zshrc` から読み込みます。各ファイルには目印で囲んだブロックを 1 つ追加するだけです。
- **Git**: `init.defaultBranch=main`（未設定のとき）、WSL では `core.autocrlf=input`、`git lfs install --skip-repo`。`user.name` / `user.email` は未設定のときだけ尋ねます（include 先も確認します）。
- **apt**: 入っていないパッケージだけを入れます。公式 apt リポジトリは deb822 形式の `.sources` で登録し、鍵は配布されている形式のまま置きます。
- **記録**: `~/.config/agentyard/state`（macOS では `Brewfile` も）に、agentyard が入れたもの・変えたものを記録します。`update` と `uninstall` はその範囲だけを扱います。

## ユーザースコープの AGENTS.md

`agents-md` を選ぶと、`~/.agents/AGENTS.md` が個人の指示を書く唯一の場所になります。agentyard は、ファイルがなければ雛形を作り、自動生成の「ホスト環境」ブロックを追記し、入れたエージェントそれぞれから読ませます。

| エージェント | 読ませ方 |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` に `@~/.agents/AGENTS.md` を追記 |
| Antigravity CLI | `~/.gemini/AGENTS.md` に `@[agentyard](~/.agents/AGENTS.md)` を追記 |
| Copilot CLI | `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` に `~/.agents` を追加 |
| Codex CLI | `~/.codex/AGENTS.md` をシンボリックリンクにする（既にあれば参照を追記） |
| Gemini CLI | `~/.gemini/GEMINI.md` をシンボリックリンクにする（既にあれば参照を追記） |

エージェントの設定ファイルは編集しません。

## 開発

```bash
mise install                 # .mise.toml で固定した開発ツール
lefthook run pre-commit      # lint
bats tests/unit              # 単体テスト
bash tests/smoke/run.sh      # smoke テスト
bash tests/integration/run.sh 24.04 26.04   # Docker による統合テスト
```

リリース前に [手動確認項目](docs/manual-checklist.md) を確認してください。規約は [CONTRIBUTING.md](CONTRIBUTING.md) を参照してください。

## ライセンス

[MIT](LICENSE)
