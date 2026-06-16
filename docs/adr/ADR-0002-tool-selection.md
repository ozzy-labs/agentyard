# ADR-0002: ツール選定（mise, uv, Docker 等）

## ステータス

承認済み

## コンテキスト

多種多様な開発ツールやプログラミング言語ランタイムを、一貫した方法で管理し、環境間の差異を最小化する必要があります。

## 決定

以下のツールを標準管理ツールとして選定します。

1. **mise**: バージョン管理および実行環境の切り替え。
2. **uv**: Python ランタイムおよびツールの管理。
3. **Docker**: 開発環境のコンテナ化（Dev Container）およびサンドボックス化。

## 理由

1. **mise**: `asdf` 互換でありながら、Rust 製で高速かつ単一バイナリで動作するため、ブートストラップに適しています。
2. **uv**: 従来の `pip` や `venv` よりも劇的に高速で、ツール単体でのインストール管理（`uv tool`）も優れています。
3. **Docker**: ホスト環境を汚染せず、再現可能な開発環境を構築するための業界標準です。

## 拡張ツール群（mise 経由でピン管理）

本 ADR 制定後の運用で、AI エージェント駆動開発・セキュリティ監査・docs ワークフローを支えるために、以下のツールを追加で標準採用している。すべて mise でバージョン管理し、リポジトリ全体で共有する。

### 基本 runtime / package

- `node@lts` — Node.js LTS（core バックエンド、レンジ指定例外）
- `pnpm@<pinned>` — pnpm（aqua バックエンド、具体パッチ版にピン）
- `python@latest` — Python（core バックエンド、レンジ指定例外）

### JS ランタイム（opt-in）

- `bun@1` — Bun（core バックエンド、レンジ指定。**既定 OFF**、`INSTALL_BUN=1` で有効化）
  - **採用理由**: Bun-native な MCP サーバ（`bun:sqlite` を使うアプリは `npx`/Node では動かない）をホスト直で動かす需要がある。エコシステムの主流は依然 Node + `npx` のため Bun を **既定 ON にはせず**、AI-first ツール群を動かしたいユーザー向けの opt-in に留める（Node + pnpm の置き換えではなく追加の選択肢）。
  - **ピン運用**: bun は mise の core バックエンド扱いのため、node / python と同じ **レンジ指定例外**に乗る（aqua レジストリ追従ずれ・具体パッチ版ピン・Renovate churn の対象外）。
  - **真の opt-in 設計（global config テンプレート非掲載）**: `dotfiles/dot_config/mise/config.toml` に列挙すると `install_dev_tools` 末尾の `mise install` で **全ホストに入り opt-in でなくなる**（trivy が同経路で全員に入るのと同じ挙動）。これを避けるため bun はテンプレートに**意図的に列挙しない**。一方 `chezmoi apply` は global config を上書きするため、apply より前に `mise use --global bun@1` すると登録が消える（ADR-0003 / #153・#156 の wipe 罠）。対策として `install_bun` を **`install_dev_tools`（＝最後の `chezmoi apply`）より後**に呼び、apply 後に登録することで wipe を回避しつつテンプレート非掲載を両立する。
  - **doctor 非対象**: opt-in のため `check_mise_managed_tools` の必須リスト（node/pnpm/python/uv）には**含めない**（zellij と同様。含めると未導入ホストで誤 warning になる）。

### Git / security

- `gitleaks` — シークレットスキャン（lefthook pre-commit で実行）
- `trivy` — 依存・コンテナの脆弱性監査（lefthook pre-commit で実行）
  - 注意: aqua レジストリの `signer_workflow` が `aquasecurity/trivy` の Immutable Release 移行に追従しないため、**github バックエンド** (`github:aquasecurity/trivy`) に切替えて回避している。同様の追従ずれは `astral-sh/uv` でも発生しており、こちらも `github:astral-sh/uv` を採用する。

### AI power tools

- `ast-grep` — AST ベースの構造検索・置換
- `yq` — YAML 操作（`jq` の YAML 版）
- `markitdown` — Microsoft 製ドキュメント変換器（`uv tool` で導入）

### Dev helpers

- `just` — タスクランナー
- `zoxide` — `cd` 拡張（学習型ジャンプ）
- `shellcheck` — Bash 静的解析
- `chezmoi` — ドットファイル適用（ADR-0003 参照）

### Shell experience (opt-in)

- `zellij` — Terminal multiplexer（既定 OFF、`INSTALL_ZELLIJ=1` で導入）。詳細は ADR-0005 を参照。
- なお `tmux` も opt-in multiplexer として用意しているが、Linux では apt 経由・macOS では手動案内のみで、mise 管理対象外。これも ADR-0005 で扱う。

### ピン運用ポリシー

- **aqua バックエンド経由のツール**（pnpm / gitleaks / ast-grep / yq / chezmoi / just / zoxide / shellcheck / zellij 等）は、上流リリースと aqua レジストリの追従ずれで任意の新版が破綻し得るため、**具体パッチ版に明示ピン**する。
- 更新は **Renovate の mise manager** が自動 PR 化し、CI で検証する。
- **core バックエンド**（node, python）はレンジ指定（`lts` / `latest`）を許容する例外扱い。
- **github バックエンド回避策**: aqua の `signer_workflow` 不整合が出たツール（uv / trivy）は `github:<owner>/<repo>` バックエンドへ切替える。

### グローバル mise config の単一情報源

`dotfiles/dot_config/mise/config.toml` を **chezmoi apply 後も生き残るグローバル mise config** として運用する。`install_*` スクリプトが `mise use --global` で導入したツールも、このテンプレートに列挙されていない限り `chezmoi apply` 直後に config から消える。この設計上の罠と対策は ADR-0003 を参照。

## 影響

- 各ツールの設定ファイル（`.mise.toml`, `uv.toml` 等）をリポジトリで管理し、プロジェクト全体で共有します。
- mise ピン運用と Renovate 連携により、aqua レジストリの追従ずれに対する回復は **PR レビューだけで完結**する。
- `dotfiles/dot_config/mise/config.toml` への列挙漏れは過去 2 度の回帰（trivy / zellij）の原因となったため、ツール追加時のチェックリストに含める（ADR-0003 参照）。

## 関連 ADR

- **ADR-0001** 全体アーキテクチャ（Bash ベース） — ツール選定の前提となる依存最小化方針
- **ADR-0003** 設定管理方針（chezmoi, Auto/Interactive モード） — `chezmoi apply` による global mise config 上書きの設計トラップ
- **ADR-0005** Terminal multiplexer 採用方針と macOS mise-first 再確認 — multiplexer のピンと配布形態
