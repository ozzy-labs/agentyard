# agentyard

**開発ホストを AI エージェント駆動開発向けにワンコマンド構築 — WSL2 / Linux (Ubuntu/Debian-based) / macOS、Dev Container / 直接開発の両対応**

[![Lint](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml)
[![Unit](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml)
[![Smoke](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml)
[![Integration](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml)
[![License: MIT](https://img.shields.io/github/license/ozzy-labs/agentyard)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/ozzy-labs/agentyard?include_prereleases&label=release)](https://github.com/ozzy-labs/agentyard/releases/latest)

**[English](README.md) | 日本語**

開発ホスト（WSL2 / Linux (Ubuntu/Debian-based) / macOS）を、モダンな AI エージェント駆動開発の前提が揃った状態にする包括的なセットアップスクリプト集です。**Dev Container 前提（推奨）**でも **直接ホストで開発**でも同じ基盤で動作します。AI エージェント CLI（Claude Code / Codex / Copilot / Gemini）と、エージェントが文書を読み・コードを検索し・構造化データを操作するための AI パワーツール（markitdown / ast-grep / yq / OCR / 音声処理）を標準搭載しています。

> **なぜ Bash + `curl | bash` なのか?** 本プロジェクトは意識的に **Node.js / npm / コンパイル済みバイナリに依存しない単一の Bash スクリプト** として配布しています。ランタイムを *インストールする* ツールがランタイムを *要求する* のは設計上不自然だからです。トレードオフ（リッチな TUI を持たない）と引き換えに得られるのは、**まっさらなマシンで初日から動くワンライナーインストール** という強い資産。詳しい意思決定は [ADR-0004](./docs/adr/ADR-0004-stay-bash-and-publish-readiness.md) を参照。

## 目次

- [1. リポジトリ背景](#1-リポジトリ背景)
- [2. リポジトリ構成](#2-リポジトリ構成)
- [3. 機能](#3-機能)
- [4. クイックスタート](#4-クイックスタート)
- [5. 前提条件](#5-前提条件)
- [6. スクリプト](#6-スクリプト)
  - [6.1 setup-zsh-linux.sh](#61-setup-zsh-linuxsh)
  - [6.2 setup-local-linux.sh](#62-setup-local-linuxsh)
  - [6.3 setup-local-macos.sh](#63-setup-local-macossh)
  - [6.4 update-tools.sh](#64-update-toolssh)
  - [6.5 doctor.sh](#65-doctorsh)
- [7. トラブルシューティング](#7-トラブルシューティング)
- [8. コントリビューション](#8-コントリビューション)
- [9. 変更履歴](#9-変更履歴)

## 1. リポジトリ背景

- **Dev Container / 直接開発の両方**に対応した、開発ホスト初期化の単一ソース（WSL2 / Linux (Ubuntu/Debian-based) / macOS）。
- **AI ファースト**: AI エージェント CLI と AI パワーツール（文書変換 / OCR / 構造的コード検索 / YAML / 音声処理）を一級カテゴリとして提供。
- **mise** を中核にランタイム・CLI ツールを統一管理、Python パッケージは **uv**、Node は Corepack 互換の **pnpm**。
- 冪等性・詳細ログ・2026 年時点のアクティブなデフォルト（gitleaks / markitdown / ast-grep 等）を重視。
- アプリケーションリポジトリとは独立してバージョン管理し、ホスト要件のアップデートを機動的に行えます。

## 2. リポジトリ構成

```
agentyard/
├── install.sh                      # OS 自動判定で dispatch（Linux → linux, Darwin → macos）
├── README.md
├── README.ja.md
└── scripts/
    ├── setup-local-linux.sh       # Ubuntu/Debian（WSL2 + 非 WSL Linux）の包括セットアップ
    ├── setup-local-macos.sh        # macOS（mise を入口にした軽量フロー）
    ├── setup-zsh-linux.sh         # zsh + oh-my-zsh（Ubuntu/Debian）
    └── update-tools.sh             # クロス OS の一括更新
```

## 3. 機能

- 🤖 **AI エージェント CLI** - Claude Code / Codex CLI / GitHub Copilot CLI / Gemini CLI（個別選択可）
- 🧠 **AI パワーツール** - markitdown（PDF/Office → Markdown）/ tesseract-ocr(+jpn) / ffmpeg / ast-grep（構造的コード検索）/ yq
- 🐳 **コンテナ / サンドボックス基盤** - Docker Engine + Docker Compose（Dev Container の前提）+ bubblewrap
- ⚡ **統一バージョン管理** - mise で Node.js LTS / pnpm / Python / uv / gitleaks / shellcheck / ast-grep / yq を一元管理（opt-in: Bun-native ツール向けに Bun）
- 🐍 **Python エコシステム** - mise 管理の Python + uv（パッケージ・venv・CLI ツール）
- ☁️ **クラウド CLI** - AWS CLI v2（デフォルト ON）/ Azure CLI, Google Cloud CLI（opt-in）
- 🔒 **モダンなシークレット / 脆弱性スキャン** - gitleaks（2026 デファクト シークレットスキャナ）+ trivy（ファイルシステム脆弱性スキャナ。本リポの lefthook pre-commit で利用）を mise で導入、プロジェクト側の lefthook と連携
- 🎨 **シェル体験** - zsh + oh-my-zsh + プラグイン（Ubuntu/Debian）、fzf / ripgrep / fd / jq / tree（opt-in: tmux / zellij multiplexer）
- 🔄 **ワンショット更新** - `install.sh update` で mise / uv / npm 管理ツールを一括更新
- 🐧 **Ubuntu LTS 幅広くサポート** - 22.04 / 24.04 を PR / main push で CI 検証、**次期 LTS 26.04 Resolute Raccoon** も週次 canary で先行検証済み。LTS 切替直後も動作する
- 🍎 **macOS サポート** - 専用 `setup-local-macos.sh` で同じ mise を入口にしたフローを提供。週次 canary で `macos-latest` を検証
- 🖥️ **非 WSL Linux サポート** - 週次 canary で `ubuntu-latest` 上の bare-metal インストール（Ubuntu Server / EC2 / GCE 等）を検証
- ✅ **冪等性保証** - 複数回実行しても安全
- 📝 **詳細なログ機能** - トラブルシューティング用のログ出力（オプション）
- 🛠️ **統一的なエラーハンドリング** - わかりやすいエラーメッセージと対処法

## 4. クイックスタート

> **推奨呼び出し** には `--proto '=https' --tlsv1.2` を付けて TLS バージョンを明示的に固定します。これにより HTTP へのリダイレクトや TLS 1.1 以下のフォールバックを拒否できます（`rustup` / `mise` と同じパターン）。

```bash
# 1. zsh セットアップ（推奨：最初に実行）
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- zsh

# 2. ターミナルを再起動
exit
# 新しいターミナルを開く

# 3. 開発ツールをセットアップ（mise, 言語環境, Docker, AI CLI, AI パワーツール等）
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- local

# 4. インストール済みのものだけ認証を完了
aws configure      # または aws configure sso
gh auth login
claude auth login
codex auth login
copilot             # 初回起動時に /login で認証
gemini              # 初回起動時に Google アカウントで認証

# 5. 後日: mise / uv / npm 管理ツールをまとめて最新化
./install.sh update

# 6. 環境の整合性を診断（任意のタイミング）
./install.sh doctor
```

### 4.1 内容を確認してから実行（本番ホスト推奨）

実行前にスクリプトを読みたい場合は、ダウンロードして検査してから実行できます。

```bash
# 一時ファイルにダウンロード
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh \
  -o /tmp/agentyard-install.sh

# 内容を確認
less /tmp/agentyard-install.sh

# 実行
bash /tmp/agentyard-install.sh local
```

### 4.2 SHA256 でリリース版を検証する

ピン留めした再現可能なインストールには、タグ付きリリースを使ってください。各 GitHub Release には `install.sh` と `install.sh.sha256` が同梱されています。

```bash
# 特定リリースに固定（v0.3.0 を最新タグに置き換える）
TAG=v0.3.0
BASE="https://github.com/ozzy-labs/agentyard/releases/download/${TAG}"

# スクリプトとチェックサムをダウンロード
curl --proto '=https' --tlsv1.2 -fsSL "${BASE}/install.sh" -o install.sh
curl --proto '=https' --tlsv1.2 -fsSL "${BASE}/install.sh.sha256" -o install.sh.sha256

# 検証（"install.sh: OK" と出れば成功）
sha256sum -c install.sh.sha256

# 検証成功後にのみ実行
bash install.sh local
```

### 4.3 clone して実行（コントリビュータ / fork 利用者向け）

```bash
git clone https://github.com/ozzy-labs/agentyard.git
cd agentyard
./install.sh zsh
./install.sh local
```

### 4.4 環境変数 / CLI オプション

#### `install.sh` の CLI オプション

| 引数 | 説明 |
|---|---|
| `zsh` \| `local` \| `all` \| `update` \| `doctor` | サブコマンド（既定: `all`）。各々の動作は [§6](#6-スクリプト) を参照 |
| `--ref <git-ref>` | リモート実行時にダウンロードするブランチ / タグ / コミット（既定: `main`） |
| `-y`, `--auto` | 推奨設定を確認なしで適用（`AGENTYARD_ASSUME_YES=1` を設定） |
| `--interactive` | 対話プロンプトを強制（`AGENTYARD_ASSUME_YES=0` を設定）。`CI=true` を上書きしたい場合に使用 |
| `-h`, `--help` | ヘルプ表示 |

#### トップレベルの環境変数

| 変数 | 既定値 | 効果 |
|---|---|---|
| `AGENTYARD_REF` | `main` | `curl \| bash` 実行時にダウンロードする既定 git ref。旧名 `AGENTIC_BOOTSTRAP_REF` / `BOOTSTRAP_REF` もフォールバック |
| `AGENTYARD_ASSUME_YES` | `0` | `1` = 非対話モード。「既定 Y」プロンプトを自動承認し、「既定 N」プロンプトをスキップ。旧名 `AGENTIC_BOOTSTRAP_ASSUME_YES` / `BOOTSTRAP_ASSUME_YES` もフォールバック。`CI=true` でも自動で ON |
| `SETUP_LOG` | 未設定 | セットアップ / 更新の全出力をログファイルに tee する。`1` / `true` で既定パス（`~/setup-local-<os>-YYYYMMDD-HHMMSS.log`）を使用。それ以外の値はカスタムパスとして扱う |

#### `INSTALL_*` カテゴリフラグ（Linux: `setup-local-linux.sh`）

各フラグは `1`（インストール）/ `0`（スキップ）を取る。既定値は `scripts/setup-local-linux.sh` に対応。対話モードでは各カテゴリで確認、`AGENTYARD_ASSUME_YES=1` ではここの既定値が使われる。

| 変数 | 既定値 | カテゴリ |
|---|---|---|
| `INSTALL_BUILD_TOOLS` | `1` | build-essential |
| `INSTALL_BASIC_CLI` | `1` | tree, fzf, jq, ripgrep, fd, unzip |
| `INSTALL_GIT_TOOLS` | `1` | Git, GitHub CLI, gitleaks |
| `INSTALL_NODE` | `1` | mise + Node.js LTS + pnpm |
| `INSTALL_PYTHON` | `1` | mise + Python + uv |
| `INSTALL_BUN` | `0` | Bun（mise、opt-in）— JS ランタイム / パッケージマネージャ / バンドラ |
| `INSTALL_CONTAINER` | `1` | Docker Engine, Docker Compose, bubblewrap |
| `INSTALL_AWS_CLI` | `1` | AWS CLI v2 |
| `INSTALL_AZURE_CLI` | `0` | Azure CLI（opt-in） |
| `INSTALL_GCLOUD_CLI` | `0` | Google Cloud CLI（opt-in） |
| `INSTALL_CLAUDE_CODE` | `1` | Claude Code |
| `INSTALL_CODEX_CLI` | `1` | Codex CLI |
| `INSTALL_COPILOT_CLI` | `1` | GitHub Copilot CLI |
| `INSTALL_GEMINI_CLI` | `1` | Gemini CLI |
| `INSTALL_AI_POWER_TOOLS` | `1` | markitdown, tesseract-ocr(+jpn), ffmpeg, ast-grep, yq |
| `INSTALL_TMUX` | `0` | tmux（apt、opt-in） |
| `INSTALL_ZELLIJ` | `0` | Zellij（mise、opt-in） |
| `INSTALL_DEV_TOOLS` | `1` | just, zoxide, shellcheck, chezmoi |

#### `INSTALL_*` カテゴリフラグ（macOS: `setup-local-macos.sh`）

macOS 版は意図的に軽量化されている — Docker Desktop / AI エージェント CLI / クラウド CLI は自動インストール対象外（§6.3.2 参照）。

| 変数 | 既定値 | カテゴリ |
|---|---|---|
| `INSTALL_MISE_LANGUAGES` | `1` | mise + Node.js LTS + pnpm + Python + uv |
| `INSTALL_GIT_TOOLS` | `1` | gitleaks（mise 経由） |
| `INSTALL_AI_POWER_TOOLS` | `1` | ast-grep, yq, markitdown |
| `INSTALL_DEV_TOOLS` | `1` | just, zoxide, shellcheck, chezmoi |
| `INSTALL_TMUX` | `0` | macOS では notice のみ表示。必要なら `brew install tmux` |
| `INSTALL_ZELLIJ` | `0` | Zellij（mise 経由、opt-in） |
| `INSTALL_BUN` | `0` | Bun（mise 経由、opt-in）— JS ランタイム / パッケージマネージャ / バンドラ |

例 — Linux で非対話・Azure CLI 追加・AI エージェント CLI を全部スキップ:

```bash
AGENTYARD_ASSUME_YES=1 \
INSTALL_AZURE_CLI=1 \
INSTALL_CLAUDE_CODE=0 INSTALL_CODEX_CLI=0 INSTALL_COPILOT_CLI=0 INSTALL_GEMINI_CLI=0 \
SETUP_LOG=1 \
./install.sh local
```

## 5. 前提条件

これらのスクリプトは **開発ホスト**のセットアップを目的とし、複数 OS と以下 2 つのワークフローに対応します。

### 5.1 サポート対象 OS

| OS / ディストリビューション | スクリプト | 状態 |
|---|---|---|
| **Linux (Ubuntu 22.04 LTS)** | \`setup-local-linux.sh\` | ✅ 全 PR / main push で CI 検証 |
| **Linux (Ubuntu 24.04 LTS)** | \`setup-local-linux.sh\` | ✅ 全 PR / main push で CI 検証 |
| **Linux (Ubuntu Server 等)** | \`setup-local-linux.sh\` | ✅ 週次 canary で \`ubuntu-latest\` 上の bare-metal インストールを検証 |
| **macOS (latest)** | \`setup-local-macos.sh\` | ✅ 週次 canary で \`macos-latest\` を検証（mise を入口にした軽量フロー） |
| **Linux (Ubuntu 25.10)** | \`setup-local-linux.sh\` | ✅ 週次 canary（\`ubuntu:rolling\` Docker タグ） |
| **Linux (Ubuntu 26.04 LTS)** | \`setup-local-linux.sh\` | ✅ 週次 canary（\`ubuntu:devel\` Docker タグ） — 次期 LTS 切替直後から動作 |

`install.sh` は OS を自動判定し `local` を適切なスクリプト（Linux → `setup-local-linux.sh`、Darwin → `setup-local-macos.sh`）に dispatch します。週次 Canary は `ubuntu:devel` / `ubuntu:rolling` Docker タグ・素の `ubuntu-latest` ランナー（非 WSL Linux）・`macos-latest` の 3 系統で統合 harness を回し、上流破壊的変更を全サポート OS で早期検知します。

### 5.2 Dev Container ワークフロー（推奨）

- ホストには最小限の基盤（Docker / mise / git / AI CLI / AI パワーツール）のみ配置
- プロジェクト固有のランタイム・リンター・フォーマッターは各 `.devcontainer/` 内で管理
- 複数プロジェクトで dev container を使い分けるチームに最適

### 5.3 直接開発ワークフロー

- Node.js LTS / pnpm / Python / uv も mise でホストに導入し、WSL2 / 非 WSL Linux / macOS 上で直接開発可能
- プロジェクト固有のツールはプロジェクトの `.mise.toml` で管理
- 小規模プロジェクト・探索的作業・dev container がオーバースペックな場合に便利

両モードとも **mise + uv + Docker** の共通基盤の上で動作するため、ホストを再構築せずにモードを行き来できます。

## 6. スクリプト

### 6.1 setup-zsh-linux.sh

Ubuntu/Debian 環境（WSL2 + 非 WSL Linux）で zsh + oh-my-zsh + プラグインをセットアップするスクリプトです。macOS では本ステップは自動的にスキップされ、`install.sh zsh` は通知だけ出して正常終了します（macOS は zsh が標準シェル）。

`install.sh` 経由でも、`scripts/setup-zsh-linux.sh` を直接実行しても使えます。

**6.1.1 インストールされる内容**

- **curl** - oh-my-zsh のインストールに必要
- **git** - プラグインのインストールに必要
- **zsh** - シェル本体
- **oh-my-zsh** - zsh フレームワーク
- **zsh-completions** - 追加の補完定義
- **zsh-autosuggestions** - コマンドの自動補完
- **zsh-history-substring-search** - 履歴検索の強化
- **zsh-syntax-highlighting** - コマンドのシンタックスハイライト
- `.zshrc` の plugins 設定自動修正
- インタラクティブなプラグイン選択（すべてインストールまたは個別選択）

**6.1.2 主な機能**

- ✅ **冪等性保証** - 複数回実行しても安全
  - プラグイン設定の堅牢な検出（既存の`plugins=(git docker)`などに対応）
  - 既存プラグインを保持しながら新しいプラグインを追加
- ✅ **実行環境チェック** - Ubuntu/Debian 系のみ実行可能
- ✅ **依存関係の自動解決** - curl, git を事前インストール
- ✅ **設定の自動更新** - .zshrc のプラグイン設定を自動追加
  - 任意のプラグイン構成に対応（スペース区切りのバリエーションも可）
- ✅ **デフォルトシェル変更** - zsh をデフォルトシェルに設定（失敗時は代替案を提示）
- ✅ **エラーハンドリング** - すべての重要な操作でエラーチェック
- ✅ **ログ記録機能** - トラブルシューティング用のログ出力（オプション）
- ✅ **詳細なコメント** - 複雑な処理には説明コメントを付与

**6.1.3 使用方法**

```bash
# install.sh 経由で実行（初回セットアップ向け）
curl -fsSL https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- zsh

# clone 済みリポジトリから実行
./install.sh zsh

# スクリプトを直接実行
./scripts/setup-zsh-linux.sh

# ログを記録する場合
SETUP_LOG=1 ./install.sh zsh

# カスタムログファイルパスを指定
SETUP_LOG=/path/to/setup.log ./install.sh zsh

# シェル再起動（zsh が有効化されます）
exec zsh
```

**6.1.4 セットアップ後の確認**

```bash
# zsh が動作しているか確認
echo $SHELL

# oh-my-zsh のバージョン確認
omz version

# プラグインが有効か確認
echo $plugins
```

**6.1.5 注意事項**

- Dev Container **外**の Ubuntu/Debian 環境（WSL2 / 非 WSL Linux）用
- macOS では本スクリプトは自動的にスキップされます（前述の通知）
- Dev Container 内では Dockerfile で自動セットアップされます
- 複数回実行しても安全です（冪等性保証）
- デフォルトシェル変更が失敗した場合は手動設定の手順が表示されます

---

### 6.2 setup-local-linux.sh

Ubuntu/Debian 環境（WSL2 + 非 WSL Linux：Ubuntu Server / EC2 / GCE / コンテナ系 VM 等）に必要な開発ツールをインストールする包括的なセットアップスクリプトです。WSL2 専用の `wslu` / `BROWSER=wslview` は意図的に**自動化対象から外し**、必要な場合の手動コマンドはスクリプト内コメントに記載しています。

`install.sh` 経由でも、`scripts/setup-local-linux.sh` を直接実行しても使えます。

**6.2.1 インストールされるツール**

1. **システム設定**
   - **Locale/Timezone** - ja_JP.UTF-8 と Asia/Tokyo を自動設定
   - **devcontainer マウント用ディレクトリ** - `~/.aws`, `~/.claude`, `~/.gemini`, `~/.config/gh`, `~/.local/share/pnpm` など
2. **基本 CLI ツール**
   - **build-essential** - C/C++ コンパイラとビルドツール
   - **tree** - ディレクトリ構造の可視化
   - **fzf** - ファジーファインダー（Ctrl+R で履歴検索）
   - **jq** - JSON 処理
   - **ripgrep** - 高速なテキスト検索ツール
   - **fd-find** - find の高速でユーザーフレンドリーな代替
   - **unzip** - アーカイブ展開（AWS CLI に必要）
   - WSL2 専用の `wslu` / `BROWSER=wslview` は自動化対象外（必要時はスクリプト内コメント参照）
3. **バージョン管理（基盤）**
   - **mise** - ランタイム・CLI ツールの統一マネージャ（Volta を置換）
4. **Node.js エコシステム（mise 経由）**
   - **Node.js LTS** - JavaScript ランタイム
   - **pnpm** - 高速なパッケージマネージャー
   - **Bun**（mise 経由、opt-in）- オールインワンの JS ランタイム / パッケージマネージャ / バンドラ（`INSTALL_BUN=1` または対話セレクタで選択）。`bun:sqlite` を使う MCP サーバ等、Node/`npx` では動かない Bun-native ツールを動かすために必要。Node + pnpm の置き換えではなく**追加**の選択肢で、`bun@1` メジャーにピン（mise core backend、Node/Python と同じレンジ運用）。global mise config テンプレートには**意図的に列挙しない**真の opt-in のため、既定ホストには入らない。
5. **Python エコシステム（mise 経由）**
   - **Python** - mise 管理の最新安定版
   - **uv** - パッケージ・仮想環境・CLI ツール導入
6. **バージョン管理ツール**
   - **Git** - バージョン管理システム
   - **GitHub CLI** - GitHub 操作
   - **gitleaks**（mise 経由）- モダンなシークレットスキャナ。プロジェクト側の lefthook / pre-commit に組み込む運用
   - **Git 基本設定** - user.name, user.email, core.editor などの自動設定
7. **コンテナ / サンドボックスツール**
   - **bubblewrap** - モダンな CLI / デスクトップツールが利用する軽量な非特権サンドボックス基盤
   - **Docker Engine** - コンテナ実行環境
   - **Docker Compose** - 複数コンテナの管理ツール（Dev Container に必須）
   - **Docker サービス自動起動** - WSL2 でのサービス起動
8. **クラウドツール**
   - **AWS CLI v2** - AWS リソース操作（デフォルト ON）
   - **Azure CLI** - Microsoft Azure リソース操作（opt-in）
   - **Google Cloud CLI** - Google Cloud Platform リソース操作（opt-in）
9. **Terminal multiplexer**（opt-in）
   - **tmux**（apt 経由）- 定番のターミナルマルチプレクサ（Linux 限定。`INSTALL_TMUX=1` または対話セレクタで選択）。`~/.tmux.conf` が存在しない場合のみ最小構成（truecolor / mouse / 50k scrollback / 1 始まり index / `prefix r` でリロード）を直書きする
   - **Zellij**（mise 経由）- モダンなターミナルマルチプレクサ（opt-in。`INSTALL_ZELLIJ=1` または対話セレクタで選択）
10. **AI エージェント CLI**（個別選択可）
    - **Claude Code** - Claude AI との対話型開発ツール
    - **Codex CLI** - OpenAI Codex CLI（コード生成AI）
    - **GitHub Copilot CLI** - GitHub Copilot コーディングエージェント（ターミナル版）
    - **Gemini CLI** - Google Gemini AI エージェント（ターミナル版）
    - マルチエージェント対応: `.agents/skills/`（Agent Skills 標準）に共通スキル、`AGENTS.md` を共通エントリーポイント、`.claude/skills/` に Claude Code overlay
11. **AI パワーツール**（エージェントの能力強化）
    - **markitdown[all]**（uv tool 経由）- PDF / Word / Excel / PowerPoint / 画像 / 音声 を Markdown に変換
    - **tesseract-ocr** + **tesseract-ocr-jpn**（apt）- OCR 基盤（markitdown の画像/スキャン PDF 対応を有効化）
    - **ffmpeg**（apt）- 音声・動画処理基盤（markitdown の音声転写・動画処理で利用）
    - **ast-grep**（mise 経由）- 構造的（AST ベース）コード検索・置換
    - **yq**（mise 経由）- YAML クエリツール（jq の YAML 版）
12. **開発補助ツール**
    - **just** - タスクランナー
    - **zoxide** - ディレクトリジャンプ機能を持つスマートな cd コマンド
    - **shellcheck**（mise 経由）- シェルスクリプトの静的解析（AI 生成スクリプトの品質担保にも有用）
    - **chezmoi**（mise 経由）- リポジトリの `dotfiles/` テンプレートを `$HOME` に適用するドットファイル管理ツール（ADR-0003 参照）
    - **trivy**（mise + dotfiles テンプレート経由）- ファイルシステム脆弱性スキャナ。本リポの lefthook pre-commit に組み込み済み（`mise exec -- trivy fs --scanners vuln`）

**6.2.2 主な機能**

- ✅ **対話的なツール選択** - インストールするツールを選択可能（すべてインストール or 個別選択）
- ✅ **冪等性保証** - 複数回実行しても安全
- ✅ **実行環境チェック** - Ubuntu/Debian 系のみ実行可能
- ✅ **統一的なエラーハンドリング** - すべての重要な操作でエラーチェック
  - 統一フォーマット（原因分析 + 対処法 + 手動コマンド）
  - トラブルシューティングが容易
- ✅ **詳細なエラーメッセージ** - トラブルシューティングのヒントを表示
- ✅ **入力バリデーション** - Git メールアドレスの形式チェック
- ✅ **ログ記録機能** - トラブルシューティング用のログ出力（オプション）
- ✅ **DRY原則の適用** - コードの重複を最小化
  - `add_to_shell_config` 関数の一貫使用
  - シェル設定の統一的な管理
- ✅ **インタラクティブ設定** - Git ユーザー名/メールアドレスの対話的設定
- ✅ **セキュリティ機能** - git-secrets のグローバル設定を自動化
- ✅ **詳細なサマリー表示** - インストール結果の確認が容易
- ✅ **明確な変数管理** - グローバル変数の明示的な初期化とスコープ管理
- ✅ **詳細なコメント** - 複雑な処理（パイプライン、正規表現等）に説明を付与

**6.2.3 使用方法**

```bash
# install.sh 経由で実行（初回セットアップ向け）
curl -fsSL https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- local

# clone 済みリポジトリから実行
./install.sh local

# スクリプトを直接実行
./scripts/setup-local-linux.sh

# ログを記録する場合（デフォルトパス: ~/setup-local-linux-YYYYMMDD-HHMMSS.log）
SETUP_LOG=1 ./install.sh local

# カスタムログファイルパスを指定
SETUP_LOG=/var/log/setup.log ./install.sh local

# ターミナルを完全に閉じて再ログイン
# （パスを確実に通すため、exec では不十分です）
exit
```

**6.2.4 セットアップ後の推奨手順**

1. **AWS 認証情報を設定**:

   ```bash
   aws configure      # IAM ユーザーの場合
   aws configure sso  # SSO の場合
   ```

2. **GitHub 認証**:

   ```bash
   gh auth login
   ```

3. **AI ツール認証**:

   ```bash
   claude auth login   # Claude Code
   codex auth login    # Codex CLI
   copilot             # GitHub Copilot CLI（初回起動時に /login で認証）
   gemini              # Gemini CLI（初回起動時に Google アカウントで認証）
   ```

4. **各ツールの動作確認**:

   ```bash
   # バージョン管理 + ランタイム
   mise --version
   node --version
   pnpm --version
   python3 --version
   uv --version

   # Git / クラウド / AI エージェント
   gh --version
   gitleaks version
   aws --version
   claude --version
   codex --version
   copilot --version
   gemini --version

   # AI パワーツール
   markitdown --version
   tesseract --version
   ffmpeg -version | head -n1
   ast-grep --version
   yq --version

   # コンテナ + 開発補助
   bwrap --version
   docker --version
   docker compose version
   just --version
   shellcheck --version | head -n2
   ```

5. **すべてのツールを一括更新**:

   ```bash
   ./install.sh update           # 通常実行
   ./scripts/update-tools.sh -n  # dry-run で対象を事前確認
   ```

**6.2.5 Git 設定について**

スクリプト実行時に以下が対話的に設定されます：

- `user.name` - Git ユーザー名（デフォルト: 現在のユーザー名）
- `user.email` - Git メールアドレス（形式バリデーション付き）
- `core.editor` - デフォルトエディタ（vim）
- `init.defaultBranch` - デフォルトブランチ（main）
- `core.autocrlf` - 改行コード設定（input）
- `core.fileMode` - 実行権限の追跡（true）
- `pull.rebase` - pull 時のマージ戦略（false。`git pull` でマージコミットを作る）

**6.2.6 エラーハンドリングについて**

すべての重要な操作でエラーチェックを実施し、統一的なフォーマットで詳細な情報を提供：

**統一エラーメッセージフォーマット**:

```
⚠️  エラーメッセージ
ℹ️  考えられる原因:
    - 原因1
    - 原因2
ℹ️  対処法:
    1. 手順1
    2. 手順2
ℹ️  手動で確認/実行: コマンド
```

**例1: apt update の失敗時**

```bash
⚠️  システムパッケージの更新に失敗しました
ℹ️  考えられる原因:
    - ネットワーク接続の問題
    - パッケージリポジトリの障害
    - /etc/apt/sources.list の設定ミス
ℹ️  手動で確認: sudo apt update
```

**例2: mise のインストール失敗**

```bash
⚠️  mise のインストールに失敗しました
ℹ️  考えられる原因:
    - ネットワーク接続の問題
    - curl が利用できない
ℹ️  対処法:
    1. ネットワーク接続を確認
    2. curl のインストール状態を確認: command -v curl
ℹ️  手動で確認: curl -fsSL https://mise.run | sh
```

**例3: Docker サービス起動失敗**

```bash
⚠️  Docker サービスの起動に失敗しました
ℹ️  考えられる原因:
    - Docker のインストールが不完全
    - システムのサービス管理に問題がある
    - カーネルモジュールが読み込まれていない
ℹ️  対処法:
    1. Docker のインストール状態を確認: dpkg -l | grep docker
    2. サービスの詳細なステータスを確認: sudo service docker status
ℹ️  手動で起動する場合: sudo service docker start
```

**6.2.7 ログファイルについて**

`SETUP_LOG` 環境変数を設定すると、すべての出力がログファイルに記録されます：

```bash
# デフォルトパスに記録（~/setup-local-linux-YYYYMMDD-HHMMSS.log）
SETUP_LOG=1 ./install.sh local

# カスタムパスに記録
SETUP_LOG=/tmp/setup.log ./install.sh local
```

ログには以下が記録されます：

- すべての出力メッセージ
- エラーメッセージ
- ユーザー入力（Git 設定など）
- インストール結果

**6.2.8 注意事項**

- Dev Container **外**の Ubuntu/Debian 環境（WSL2 / 非 WSL Linux）用です
- Dev Container 内ではすでに必要なツールがインストール済みです
- 複数回実行しても安全です（冪等性保証）
- Ubuntu/Debian 系以外では警告が表示され、続行を確認されます
- Git ユーザー名/メールアドレスが未設定の場合、対話的に設定を求められます
- 空白文字のみの入力や無効なメールアドレスはバリデーションされます
- WSL2 専用ユーティリティ（`wslu` / `BROWSER=wslview`）は自動インストールしません（必要時の手順はスクリプト内コメント参照）

---

### 6.3 setup-local-macos.sh

`setup-local-linux.sh` の macOS 版。意図的に軽量化しており、**mise を入口にした共通フロー**でランタイム/CLI を導入します。OS 統合（Docker Desktop、認証 UI が必要な AI エージェント CLI、クラウド CLI）は手動セットアップに任せます。

**6.3.1 インストールされるツール**

- **mise** — `curl -fsSL https://mise.run | sh`（Linux と同一の正規パス）
- **Node.js LTS / pnpm / Python / uv**（`mise use -g` 経由）
- **gitleaks**（mise 経由）— モダンなシークレットスキャナ
- **trivy**（mise + dotfiles テンプレート経由）— ファイルシステム脆弱性スキャナ（lefthook pre-commit で使用。Linux と同じ `github:aquasecurity/trivy` ピン）
- **ast-grep / yq**（mise 経由）— AI パワーツール
- **markitdown[all]**（`uv tool install` 経由）
- **just / zoxide / shellcheck / chezmoi**（mise 経由）— 開発補助（chezmoi は `dotfiles/` テンプレートを適用、ADR-0003 準拠）
- **zellij**（mise 経由）— ターミナルマルチプレクサ（opt-in。`INSTALL_ZELLIJ=1` を設定）

**6.3.2 自動化対象外（macOS では手動）**

- **Docker Desktop** — ライセンス + 対話インストーラが必要。<https://www.docker.com/products/docker-desktop> から導入
- **AI エージェント CLI**（Claude Code / Codex / Copilot / Gemini）— 対話認証が必要なため各 vendor doc を参照
- **クラウド CLI**（`aws` / `az` / `gcloud`）— `brew install awscli azure-cli google-cloud-sdk` を推奨
- **tmux** — 必要であれば `brew install tmux` で手動導入（macOS は mise-first 方針のため、`INSTALL_TMUX=1` を指定しても notice のみ表示し brew は呼ばない）

**6.3.3 使用方法**

```bash
# install.sh が Darwin 上で自動 dispatch
./install.sh local

# スクリプトを直接実行
./scripts/setup-local-macos.sh

# 非対話モード（CI / スクリプト実行）
AGENTYARD_ASSUME_YES=1 ./scripts/setup-local-macos.sh
```

**6.3.4 注意事項**

- 冪等性保証 — 再実行しても安全。重い処理は mise に委譲
- `~/.zshrc`, `~/.bash_profile`, `~/.bashrc` に `mise activate` を追記
- 週次 canary で `macos-latest` を検証

---

### 6.4 update-tools.sh

セットアップスクリプトで導入した全てのツールを、バックエンド横断で一括更新するエントリーポイントです。

**6.4.1 更新対象**

| バックエンド | 更新内容 |
|---|---|
| **mise** | `mise self-update` + `mise upgrade` + `mise reshim`（gitleaks / trivy / ast-grep / yq / chezmoi / just / shellcheck 等を一括） |
| **uv tool** | `uv tool upgrade --all`（markitdown 等） |
| **npm global** | `@openai/codex` / `@google/gemini-cli` |
| **独自インストーラ** | `claude update` / `copilot update`（タイムアウト付き） |

**6.4.2 使用方法**

```bash
# install.sh 経由（ローカル / curl|bash 両対応）
./install.sh update

# スクリプトを直接実行
./scripts/update-tools.sh

# dry-run で対象を事前確認
./scripts/update-tools.sh --dry-run

# ログに記録
SETUP_LOG=1 ./install.sh update
SETUP_LOG=/tmp/update.log ./install.sh update
```

**6.4.3 挙動**

- 冪等性: 未インストールツールは `⏭️` でスキップ
- 耐障害性: 個別コマンドの失敗は警告表示のみで、全体処理は継続
- ログ対応: `setup-local-linux.sh` と同じ `SETUP_LOG` 規約に従う
- クロス OS: Linux（WSL2 / 非 WSL）と macOS で同等に動作

---

### 6.5 doctor.sh

セットアップ済みの環境の整合性を診断するコマンド（変更は加えない）。OS アップデート後に動作が怪しい時や、新しいプロジェクトのセットアップでつまずいた際の状態確認に使えます。

**6.5.1 診断項目**

- **システム基本ツール** — `curl`, `git`, `unzip`, `xz`, `tar` の存在確認
- **mise** — `~/.local/bin/mise` のバイナリ、`~/.local/bin` および mise shims の PATH 設定
- **mise 管理ツール** — `node`, `pnpm`, `python`, `uv` が mise グローバル管理下か
- **chezmoi drift** — リポジトリ内 `dotfiles/` との差分（`chezmoi diff`）を検出
- **`~/.zshrc.d/`** — ディレクトリの存在と `~/.zshrc` からの読み込み設定

**6.5.2 終了コード**

| Code | 意味 |
|---|---|
| `0` | 健全（warning / error なし） |
| `1` | 警告のみ（推奨ツール未インストール、drift 検出） |
| `2` | エラーあり（必須システムツール欠落） |

このため CI / ヘルスチェックパイプラインで `./install.sh doctor || echo "needs attention"` のように使えます（実問題がある時のみ非 0 で抜ける）。

**6.5.3 使い方**

```bash
# install.sh dispatcher 経由
./install.sh doctor

# 直接実行
./scripts/doctor.sh
```

`✅` 以外の各項目には対処コマンドがコピペ可能な形で併記されます。Doctor は **修復を実行しません** — コマンドを提示するだけで、実行判断はユーザーに委ねます。

**6.5.4 出力例**

```
🩺 agentyard doctor を実行中...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 診断結果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ [system-tools] curl: 利用可能
✅ [system-tools] git: 利用可能
✅ [mise] mise が利用可能 (2026.4.20 linux-x64)
⚠️  [mise] PATH に mise shims が含まれていない（mise activate が必要）
   ↳ 対処: eval "$(mise activate bash)"  # または zsh
✅ [mise-tools] node は mise 管理下 (current: 24.15.0)
⚠️  [chezmoi] ドットファイルに drift あり (12 行の差分)
   ↳ 対処: chezmoi apply --source /path/to/agentyard/dotfiles

サマリー: ✅ 11  ⚠️  2  ❌ 0
```

---

## 7. トラブルシューティング

### 7.1 よくある問題

**7.1.1 apt update が失敗する**

```bash
# エラーメッセージ例
⚠️  システムパッケージの更新に失敗しました

# 対処法
1. ネットワーク接続を確認
2. sudo apt update を手動で実行してエラー詳細を確認
3. /etc/apt/sources.list の設定を確認
```

**7.1.2 mise / uv / node が見つからない**

```bash
# エラーメッセージ例
⚠️  mise のインストールに失敗しました
ℹ️  考えられる原因:
    - mise のインストールが完了していない
    - インストール直後で PATH が反映されていない
    - 現在のシェルが .zshrc / .bashrc を読み込み直していない
ℹ️  対処法:
    1. ターミナルを完全に閉じて再ログイン（exit）
    2. このスクリプトを再実行
ℹ️  手動で確認: ~/.local/bin/mise --version

# 追加の確認手順
1. ターミナルを完全に閉じる（exit）
2. 新しいターミナルセッションを開く
3. echo $PATH で PATH が更新されているか確認
4. ls -la ~/.local/bin/mise で mise がインストールされているか確認
5. 手動で activate: eval "$(~/.local/bin/mise activate bash)"
```

**7.1.3 Docker が起動しない**

```bash
# エラーメッセージ例
⚠️  Docker サービスの起動に失敗しました
ℹ️  考えられる原因:
    - Docker のインストールが不完全
    - システムのサービス管理に問題がある
    - カーネルモジュールが読み込まれていない
ℹ️  対処法:
    1. Docker のインストール状態を確認: dpkg -l | grep docker
    2. サービスの詳細なステータスを確認: sudo service docker status
ℹ️  手動で起動する場合: sudo service docker start

# 追加の確認手順
sudo service docker status  # 状態確認
sudo service docker start   # 手動起動
sudo docker run hello-world # 動作確認
```

**7.1.4 Docker Compose が見つからない**

```bash
# エラーメッセージ例
⚠️  Docker Compose のインストールに失敗しました
ℹ️  考えられる原因:
    - パッケージリポジトリに docker-compose-plugin がない
    - Docker Engine のインストールが不完全
ℹ️  対処法:
    1. Docker のインストール状態を確認: dpkg -l | grep docker
    2. 手動でインストール: sudo apt-get install -y docker-compose-plugin
ℹ️  手動で確認: docker compose version

# 追加の確認手順
docker compose version              # バージョン確認
dpkg -l | grep docker-compose       # パッケージ確認
sudo apt-get update                 # リポジトリ更新後に再試行
sudo apt-get install -y docker-compose-plugin
```

**7.1.5 Git メールアドレスが無効**

```bash
# エラーメッセージ例
⚠️  無効なメールアドレス形式です

# 対処法
有効な形式で入力: user@example.com
または後で設定: git config --global user.email "you@example.com"
```

**7.1.6 既存の `~/.tmux.conf` が上書きされない**

```bash
# 挙動
INSTALL_TMUX=1 を指定すると、~/.tmux.conf が「存在しない場合のみ」
最小構成を直書きする。既に存在する場合はスキップし、以下を表示する:

  ⏭️  ~/.tmux.conf は既に存在（上書きしません）

# 同梱の設定を適用したい場合
mv ~/.tmux.conf ~/.tmux.conf.bak
INSTALL_TMUX=1 ./install.sh local

# 同梱の設定内容
- truecolor + 256color（tmux-256color terminfo）
- mouse on、50k スクロールバック
- window / pane index を 1 始まり、renumber-windows on
- `prefix r` で ~/.tmux.conf をリロード
- prefix キーはデフォルト（C-b）維持、vi/emacs mode-keys / プラグインマネージャは入れない
```

**7.1.7 `curl ... | bash` で対話プロンプトが表示されない場合**

一部の環境（特定の WSL2 構成、controlling terminal を持たないコンテナ、ネストした subshell など）では、`curl ... | bash` で起動した bash サブシェルから `/dev/tty` が open できないことがある。この場合、対話プロンプトを表示できないため、隠れたプロンプトに既定値で勝手に進むのではなく、明示的なエラーで中断するようになっている。

```bash
# エラーメッセージ例
⚠️  対話プロンプト用の TTY を確保できませんでした
ℹ️  考えられる原因:
    - stdin が pipe で、/dev/tty へのフォールバックも失敗した
    - curl ... | bash 実行時に /dev/tty が利用不可（WSL2 の一部環境 / コンテナ / サブシェル）
ℹ️  対処法:
    1. ファイル経由で実行する（推奨）: ...
    2. プロセス置換で実行する: ...
    3. 非対話モードで実行する: ...
```

以下のいずれかの対処法を選ぶ:

```bash
# (a) ファイル経由実行（最も確実。事前にスクリプトを目視レビューも可能）
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh \
  -o /tmp/install.sh
bash /tmp/install.sh local

# (b) プロセス置換（ワンライナーの形を保ちつつ、stdin に実 TTY が戻る）
bash <(curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh) local

# (c) 非対話モード（既定値で全カテゴリをインストール）
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh \
  | AGENTYARD_ASSUME_YES=1 bash -s -- local
```

### 7.2 ログの確認方法

```bash
# ログ記録付きで実行した場合
SETUP_LOG=1 ./install.sh local

# ログファイルの場所が表示されます
ℹ️  ログを /home/user/setup-local-linux-20250109-123456.log に記録します

# ログを確認
cat /home/user/setup-local-linux-20250109-123456.log
```

---

## 8. コントリビューション

コントリビューションを歓迎します！Pull Request をお気軽に送ってください。

詳細なレビュープロセスについては、以下を参照してください：

- [レビュープロセスガイド](docs/review-process.md)
- [レビューチェックリスト](docs/review-checklist.md)

---

## 9. 変更履歴

プロジェクトの変更履歴は [CHANGELOG.md](CHANGELOG.md) で自動管理されています（[release-please](https://github.com/googleapis/release-please) が Conventional Commits から生成）。各リリースの詳細は [GitHub Releases](https://github.com/ozzy-labs/agentyard/releases) を参照してください。
