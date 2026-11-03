# AGENTS.md

このファイルは AI エージェント向けの共通 instructions です。

## 基本方針

- 日本語で応答する
- 推奨案とその理由を提示する
- `.env` ファイルは読み取り・ステージングしない
- 破壊的な Git 操作を避ける
- ユーザーへの確認は、エージェントが提供する対話的な質問機能（Claude Code の `AskUserQuestion` など）を使う
- 作業完了時のネクストアクションは提案にとどめ、ユーザーの確認なく実行しない

## プロジェクト概要

`agentyard`: Bash 製の開発ホストプロビジョナ（Ubuntu 24.04 / 26.04、WSL2、macOS 26 / 27）。AI エージェントを使った開発のためのホストを構築する。設計方針は [ADR-0007](docs/adr/ADR-0007-host-first-redesign.md) を参照。

## Tech Stack

- Language: Bash (POSIX-friendly, bash 3.2+ compat on macOS, 4+ on Linux)
- Hooks: lefthook
- Tests: bats (unit), shell (smoke), Docker (integration)
- Lint: shellcheck, shfmt, markdownlint, yamllint, actionlint, gitleaks, trivy, commitlint
- Version management: mise（このリポジトリの開発ツールは `.mise.toml`、agentyard がホストに入れる固定バージョンは `config/tools.toml`）

## 主要コマンド

```bash
./install.sh install       # ホストのセットアップ
./install.sh update        # agentyard が入れたものだけを更新
./install.sh doctor        # 環境の診断（--repo <path> でリポジトリの AGENTS.md 診断）
./install.sh uninstall     # agentyard が書き換えた設定を元に戻す
lefthook run pre-commit    # 全 lint + format チェック
bats tests/unit            # unit テスト
bash tests/smoke/run.sh    # smoke テスト
```

## 検証（必須）

コード変更後、報告前に以下を通すこと:

1. `lefthook run pre-commit` — 全 lint pass
2. `bash tests/smoke/run.sh` — smoke green
3. `bats tests/unit` — unit green
4. （shell/yaml/Dockerfile を変更した場合）integration test も推奨: `bash tests/integration/run.sh`

## コーディング規約

- インデント: 2 スペース
- 改行コード: LF
- ファイル末尾: 改行あり

## 規約

言語・コミット・ブランチ・PR のルールは README.md を参照すること。

<!-- begin: @ozzylabs/skills -->

## Available Skills

- `commit` — 変更をステージし、Conventional Commits でコミットする。プッシュや PR 作成は行わない。
- `commit-conventions` — Conventional Commits のメッセージ生成ルール（Type/Scope 判定表、フォーマット）。他スキルから参照される。
- `drive` — Issue または指示から実装・PR 作成・セルフレビュー・修正を自動で回し、merge-ready な PR を出す。単一/複数の Issue/PR と明示依存記法に対応。オプションでマージまで実行可能。
- `health` — リポジトリ改修中に意図せず残る状態（working tree, stash, branch, worktree, PR, issue, actions など）と skill catalog 整合性を一発で確認し、16 領域のステータス表で俯瞰しつつ各項目に固定語彙の推奨アクションを inline で付与して報告する。`--deep` 指定時は `要確認` 項目を read-only コマンドで追加調査し、機械判定可能な範囲でラベルを格上げする。検査と提示のみで、削除・close 等の実行は行わない。
- `implement` — Issue または指示をもとに、ブランチ作成・実装計画・コード変更を行う。Issue 番号またはテキスト指示を受け取る。
- `lint` — 全リンターを自動修正付きで実行し、結果を報告する。コード品質チェック、フォーマット、型チェック、セキュリティスキャンを含む。
- `lint-rules` — 拡張子別リンター・フォーマッターのコマンド対応表と型チェックルール。他スキルから参照される。
- `phase-issue` — Phase-N tracking issue を生成する。cross-session handoff context、決定事項表、PR ごとのタスク、DoD、Phase N+1 outlook を含む構造化された issue body を組み立てて gh issue create で起票する。引数で全項目を渡す非対話モードと、不足分を補う対話モード（Claude Code companion）に対応する。
- `pr` — コミット済みの変更をリモートにプッシュし、PR を作成・更新する。
- `review` — コード変更や PR を 11 観点（perspectives）でレビューし、JSON 構造化出力 + 人間可読レポートで報告する。quick / deep モードを切替可能。PR 番号またはワーキングツリー差分を入力に取る。
- `ship` — lint・コミット・PR 作成を一括実行する。変更に対して lint → コミット → PR 作成を順に実行する統合パイプライン。
- `sync-consumers` — skills / commons の更新を sync-targets.yaml に記載された 14 consumer リポへ並列に push し、PR auto-merge まで完結させる。drive の Phase Final 仕様（worktree drift 検出 + cleanup）を踏襲する push 型同期スキル。
- `test` — ビルド・テスト・型チェックを実行し、結果を報告する。
- `topics` — GitHub topics 候補を制約検証・人気度測定・broad+narrow / 単数複数比較・ozzy-labs 慣行ハードコードで選定し、`gh repo edit --add-topic` で適用する。スコープは ozzy-labs 内利用のみ。

<!-- end: @ozzylabs/skills -->

## Adapter Files

指示ファイルは本 `AGENTS.md` に一本化している（ADR-0007）。`CLAUDE.md` を置くと Claude Code は `AGENTS.md` を読まなくなるため、作らないこと。

| Agent | Configuration |
|-------|---------------|
| Claude Code | `AGENTS.md`（v2.1.277 以降はネイティブに読む）, `.claude/` |
| Codex CLI | `AGENTS.md` + `.agents/skills/` |
| GitHub Copilot | `AGENTS.md` |
| Antigravity CLI | `AGENTS.md` + `.agents/skills/` |
| Gemini CLI | `.gemini/settings.json` → `AGENTS.md` |
