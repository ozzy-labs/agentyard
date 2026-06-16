# ADR-0006: インストール手段選定ポリシー

## ステータス

提案中（2026-06-16 ドラフト）

ADR-0001 / 0002 / 0004 / 0005 に分散していた「ツールをどの手段で入れるか」の判断基準を、単一の決定木として明文化する。新規方針の導入ではなく、**既存の de facto ポリシーの成文化**である。

## コンテキスト

agentyard は言語ランタイム・CLI・OS パッケージ・AI エージェント CLI など多様なツールを導入するが、その手段は複数に分かれている。

- **mise**（`mise use --global`）
- **apt**（Ubuntu/Debian パッケージ。ベンダー apt リポジトリ登録を含む）
- **uv tool**（Python 製アプリケーション）
- **npm install -g**（npm 配布パッケージ）
- **ベンダー公式インストーラ**（`curl | bash` / zip バイナリ）

各 `scripts/lib/install-*.sh` に実装が分散しており、選定基準は ADR-0001（依存最小化）・ADR-0002（mise 統一）・ADR-0004（Bash 維持）・ADR-0005（mise-first）に断片的に存在するものの、**単一の決定木として明文化されていなかった**。このため新ツール追加時に「どの手段で入れるべきか」の判断が属人的になりやすい。

[PR #179](https://github.com/ozzy-labs/agentyard/pull/179)（Bun を opt-in 追加）の検討で、手段選定・mise 内バックエンド方針・global config テンプレート列挙ルールを横断参照する必要が生じ、成文化の価値が確認された。

## 決定

### 0. 大原則

> **版ピンできる開発ツールは mise。それ以外（OS 統合 / ベンダー固有 / Python アプリ / npm 配布）だけ別手段。**

ADR-0001 / 0004 の依存最小化、ADR-0002 の mise 統一、ADR-0005 の mise-first を継承する。

### 1. 手段選定の決定木（上から順に当てはめ、最初に合致した手段を採用）

| # | 条件 | 手段 | 例 |
|---|---|---|---|
| 1 | 言語ランタイム、または版ピン可能な開発 CLI ツール | **mise** | node, python, bun, pnpm, uv, gitleaks, ast-grep, yq, just, zoxide, shellcheck, chezmoi, trivy, zellij |
| 2 | OS 統合パッケージ（root 必要 / distro 標準 / ベンダーが apt リポジトリで配布 / mise に安定エントリ無し） | **apt**（Linux のみ。macOS は手動案内） | build-essential, tree, fzf, jq, ripgrep, fd, unzip, git, gh, tmux, bubblewrap, docker, tesseract-ocr(+jpn), ffmpeg, azure-cli, gcloud |
| 3 | Python 製のアプリケーションツール | **uv tool** | markitdown[all] |
| 4 | 配布の正規経路が npm パッケージ | **npm install -g** | @openai/codex, @google/gemini-cli |
| 5 | ベンダー公式インストーラ/バイナリが正規（mise/apt/npm に無い、または自己更新型） | **ベンダー `curl \| bash` / zip** | mise 自身（`mise.run`）, AWS CLI v2（zip）, claude（`claude.ai/install.sh`）, copilot（`gh.io/copilot-install`） |

判定は #1 を最優先とする（mise-first）。#1 に乗らない理由が立つときだけ #2 以降に降りる。

### 2. mise を選んだ後のバックエンド / ピン方針（ADR-0002 を参照・再掲）

mise を採用したツールは、さらに 3 段階に分類する:

- **core backend**（node, python, **bun**）→ レンジ指定可（`lts` / `latest` / `1`）。aqua レジストリ追従ずれの影響を受けないため例外扱い。
- **aqua backend**（pnpm, gitleaks, ast-grep, yq, just, zoxide, shellcheck, chezmoi, zellij）→ **具体パッチ版にピン + Renovate（mise manager）で更新**。上流リリースと aqua レジストリの追従ずれで任意の新版が破綻し得るため。
- **github backend フォールバック**（uv, trivy）→ aqua の `signer_workflow` が上流の Immutable Release 移行に追従しないツールのみ `github:<owner>/<repo>` に切替えて回避する。

### 3. macOS の分岐（ADR-0005 を参照・再掲）

`setup-local-macos.sh` は **mise-first 方針**を維持し、`brew install` を一切呼ばない。

- 自動化されるのは **#1 mise + #3 uv tool** のツールのみ。
- **#2 apt 系**（tmux / Docker Desktop / クラウド CLI 等）と **#4 / #5**（AI エージェント CLI 等）は **自動化せず README で手動案内**する。
- 理由: 「tmux 1 個のために brew 例外を作ると ad-hoc 例外が連鎖する」（ADR-0005）。ポリシー優先。

### 4. global mise config テンプレート列挙と「真の opt-in」（ADR-0003 / PR #179）

mise で導入したツールを `chezmoi apply` 後も global に残すには `dotfiles/dot_config/mise/config.toml` への明示列挙が必要（ADR-0003 の trap）。ただし列挙すると `install_dev_tools` 末尾の `mise install` が**全ホストでそのツールを実体化する**（trivy がこの経路で全ホストに入る）。したがって:

- **既定 ON のツール**（trivy 等）→ テンプレートに列挙してよい（全ホスト導入が意図どおり）。
- **真の opt-in ツール**（Bun 等、既定 OFF で導入されたホストにだけ欲しい）→ テンプレートに**列挙しない**。代わりに `install_<tool>` を **`install_dev_tools` の `chezmoi apply` より後**に呼び、apply による wipe を回避しつつテンプレート非掲載を両立する（PR #179 の `install_bun`）。
- **opt-in だが「導入したら global に残ってほしい」ツール**（zellij）→ テンプレート列挙する（ADR-0005 #6）。この場合 #2 のトレードオフ（apply 時に全ホストで `mise install` 候補になる）を許容する。

### 5. opt-in 既定の扱い

OS 統合度が低く選好が割れるツール（multiplexer、Bun、Azure/GCP CLI 等）は **opt-in（既定 OFF）** とし、`INSTALL_<TOOL>` 環境変数または対話セレクタで明示有効化されたときのみ導入する。フラグ名は `INSTALL_<TOOL>` に揃える。opt-in ツールは doctor の必須ツールチェック（`check_mise_managed_tools` の node/pnpm/python/uv）には**含めない**（未導入ホストでの誤 warning を避けるため）。

## 理由

### mise を既定にする妥当性

mise は単一バイナリ・Rust 製で高速、版ピン + Renovate による再現性、root 不要、`.mise.toml` を SSOT にした cross-machine 一貫性を提供する（ADR-0002）。版管理が価値を持つ開発ツールは原則ここに寄せるのが、運用コストと説明の一貫性の両面で最適。

### mise に「乗せない」判断の妥当性

以下は mise が不適、または不可能:

- **OS 統合 / root 必要**: docker（daemon・apt リポジトリ・GPG 鍵）, git/gh（公式 apt リポジトリ）, locales, bubblewrap。
- **ベンダーが apt リポジトリで配布**: azure-cli, gcloud。apt が正規かつ更新も apt で完結。
- **mise に安定エントリが無い**: tmux（aqua レジストリに安定ビルド無し → macOS では案内のみ）。
- **ベンダー固有の自己更新インストーラが正規**: AWS CLI（公式 zip インストーラ）, claude / copilot（公式スクリプト、頻繁に自己更新）。
- **bootstrap の鶏卵**: mise 自身は `curl | sh` で入れるしかない。

### apt を Linux 限定にする妥当性

ADR-0005 の mise-first 方針。macOS で brew 例外を一度作ると ad-hoc 例外要求が連鎖するため、apt 系は Linux 自動化 + macOS 手動案内に統一する。

## 却下した代替案

### すべて mise に寄せる

docker / git / gh / cloud CLI は OS 統合（daemon、apt リポジトリ、root）が必須で mise では入らない。AWS CLI・AI エージェント CLI はベンダー配布が正規であり mise エントリが無い。全寄せは不可能。

### すべて apt / ベンダーインストーラに寄せる（mise を使わない）

版管理・cross-machine 一貫性・root 不要性・Renovate 連携を失う。aqua 追従ずれへの PR レビューだけでの回復（ADR-0002）も使えなくなる。macOS では apt が無く破綻する。ADR-0002 の決定に反する。

## 影響

### 新ツール追加時のチェックリスト

1. 決定木 §1 で手段を決める（#1 mise を最優先で検討）。
2. mise なら §2 でバックエンド/ピンを決める（core=レンジ可 / aqua=パッチ版ピン+Renovate / 追従ずれは github fallback）。
3. opt-in にするか（§5）。する場合 `INSTALL_<TOOL>` フラグ + 対話プロンプト（Linux）/ env-var（macOS）を足す。
4. global に残すか（§4）。残す既定 ON → テンプレート列挙。真の opt-in → 非掲載 + `chezmoi apply` 後に登録。
5. macOS の扱い（§3）。apt/vendor 系は手動案内に回す。
6. CI: `tests/integration/assert-tools.sh` に（opt-in なら gated）assertion を足す。doctor 必須リストは既定 ON のみ。

### 現状マッピング（付録・実装スナップショット）

| ツール | 手段 | バックエンド/補足 | 既定 | OS |
|---|---|---|---|---|
| node / python | mise | core（レンジ） | ON | Linux+macOS |
| bun | mise | core（レンジ）。真の opt-in（テンプレ非掲載） | OFF | Linux+macOS |
| pnpm / gitleaks / ast-grep / yq / just / zoxide / shellcheck / chezmoi | mise | aqua（パッチ版ピン） | ON | Linux+macOS |
| uv / trivy | mise | github backend（aqua 追従ずれ回避） | ON | Linux+macOS |
| zellij | mise | aqua、opt-in、テンプレ列挙 | OFF | Linux+macOS |
| markitdown[all] | uv tool | — | ON | Linux+macOS |
| codex / gemini | npm -g | node 依存 | ON | Linux のみ自動 |
| claude / copilot | vendor `curl\|bash` | 公式スクリプト | ON | Linux のみ自動 |
| AWS CLI v2 | vendor zip | 公式インストーラ | ON | Linux のみ自動 |
| mise 自身 | vendor `curl\|sh` | bootstrap | — | Linux+macOS |
| git / gh | apt | 公式 PPA / apt リポジトリ | ON | Linux のみ |
| docker 一式 | apt | docker apt リポジトリ + GPG | ON | Linux のみ |
| azure-cli / gcloud | apt | ベンダー apt リポジトリ | OFF | Linux のみ |
| tmux | apt | distro パッケージ、opt-in | OFF | Linux 自動 / macOS 案内 |
| build-essential / tree / fzf / jq / ripgrep / fd / unzip / bubblewrap / tesseract(+jpn) / ffmpeg / locales | apt | distro パッケージ | ON | Linux のみ |

（このスナップショットは実装変更で陳腐化し得る。正は各 `scripts/lib/install-*.sh` と `.mise.toml` / `dotfiles/dot_config/mise/config.toml`。）

## 関連 ADR

- **ADR-0001** 全体アーキテクチャ（Bash ベース） — 依存最小化の前提
- **ADR-0002** ツール選定（mise, uv, Docker 等） — mise 採用とバックエンド/ピン運用の SSOT。本 ADR §2 はこれを参照・再掲する
- **ADR-0003** 設定管理方針（chezmoi） — global mise config テンプレート列挙ルールと `chezmoi apply` トラップ（本 ADR §4 の前提）
- **ADR-0004** Bash 維持と公開準備 — `curl | bash` 配布、ランタイム非依存の原則
- **ADR-0005** Terminal multiplexer 採用方針と macOS mise-first 再確認 — mise-first / opt-in / apt-Linux 限定の具体例
