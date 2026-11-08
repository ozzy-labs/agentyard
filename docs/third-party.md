# agentyard が入れるもの（ライセンス・規約・データ収集）

agentyard が導入する第三者ソフトウェアの一覧です。**確認日: 2026-11-08**（根拠 URL 付き。各ベンダーの条件は変わるため、リリース前に[手動確認項目](manual-checklist.md)で見直します）。

実行中に告知は出しません。選択画面の項目名に書くのは次の 2 つだけで、それ以外（テレメトリの既定など）はこの表と「[テレメトリを無効にする](#テレメトリを無効にする)」に集約します。方針と理由は [ADR-0007](adr/ADR-0007-host-first-redesign.md) §4 を参照してください。

- **インストール時点で規約が適用される**もの（agentyard がその install を代行するため）
- **商用利用に有償ライセンスが必要**なもの

表の ★ がその対象です。

## AI エージェント CLI

| 項目 | 入手元 | ライセンス | 規約の同意 | データ収集（既定） | 商用の条件 | 根拠 |
|---|---|---|---|---|---|---|
| Claude Code | 公式インストーラ | 独自（Consumer / Commercial Terms） | 初回サインイン時 | 利用メトリクスは Claude API 利用時 ON（`DISABLE_TELEMETRY=1`）。エラー報告は Pro / Max / Ultra サインインで ON（`DISABLE_ERROR_REPORTING=1`） | 契約に従う | [data usage](https://code.claude.com/docs/en/data-usage) |
| Codex CLI | 公式インストーラ | Apache-2.0 | 初回ログイン時（OpenAI の規約） | 公式ドキュメントに記述なし（`docs/config.md` 確認） | ChatGPT プラン または API 課金 | [docs/license.md](https://github.com/openai/codex/blob/main/docs/license.md) |
| GitHub Copilot CLI | 公式インストーラ | 独自（非公開） | ログイン時（GitHub の Copilot 条項）。**有効な Copilot 契約が前提** | Copilot のプライバシー方針に従う。CLI 固有の既定は公式ドキュメントに明記なし | 有償契約が必要 | [install-copilot-cli](https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli) |
| ★ Antigravity CLI | 公式インストーラ | 独自 | **ダウンロード / インストール時**（"BY DOWNLOADING, INSTALLING, OR OTHERWISE ACCESSING OR USING ... YOU AGREE TO BE BOUND BY"） | テレメトリ ON。設定で変更できるが、off でもサービス提供・安全確保のための利用は継続 | 18 歳以上・対応国 | [terms](https://antigravity.google/terms) |
| Gemini CLI | mise（npm バックエンド） | Apache-2.0 | 初回ログイン時（Gemini Code Assist / Gemini API の規約） | **usage statistics が ON**（`privacy.usageStatisticsEnabled: false` で無効） | Gemini Code Assist 契約者向け | [configuration.md](https://github.com/google-gemini/gemini-cli/blob/main/docs/reference/configuration.md) |

## ベンダーの apt リポジトリ

| 項目 | ライセンス | 規約の同意 | データ収集（既定） | 商用の条件 | 根拠 |
|---|---|---|---|---|---|
| gh (GitHub CLI) | MIT | 該当なし | なし | 無償 | [cli/cli](https://github.com/cli/cli) |
| Docker Engine (docker-ce ほか) | Apache-2.0 | 該当なし | なし | 無償 | [moby/moby](https://github.com/moby/moby), [docker/cli](https://github.com/docker/cli) |
| Azure CLI | MIT | **使用した時点**（"Your use of the software operates as your consent to these practices."） | **ON**（`az config set core.collect_telemetry=no`） | 無償 | [README](https://github.com/Azure/azure-cli#telemetry-configuration) |
| Google Cloud CLI | Apache-2.0（一部コンポーネントは別ライセンス。未検証） | Google Cloud の規約（利用時） | **OFF（opt-in）**: "Unless you opt-in during Google Cloud CLI installation, gcloud CLI software does not collect usage statistics." | 無償（API の利用料は別） | [usage statistics](https://docs.cloud.google.com/sdk/docs/usage-statistics) |

## 公式インストーラ

| 項目 | ライセンス | 規約の同意 | データ収集（既定） | 商用の条件 | 根拠 |
|---|---|---|---|---|---|
| mise | MIT | 該当なし | 記述なし（OpenTelemetry の機能はユーザーのタスク計測用） | 無償 | [jdx/mise](https://github.com/jdx/mise) |
| AWS CLI v2 | Apache-2.0 | 該当なし | 公式ドキュメントに記述なし | 無償 | [LICENSE.txt](https://github.com/aws/aws-cli/blob/v2/LICENSE.txt) |
| oh-my-zsh | MIT | 該当なし | なし | 無償 | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) |

## mise で入れるツール

| 項目 | ライセンス | 規約の同意 | データ収集（既定） | 商用の条件 | 根拠 |
|---|---|---|---|---|---|
| node | Node.js のライセンス（MIT ベース + 同梱物） | 該当なし | なし | 無償 | [nodejs/node](https://github.com/nodejs/node) |
| pnpm | MIT | 該当なし | なし | 無償 | [pnpm/pnpm](https://github.com/pnpm/pnpm) |
| uv | Apache-2.0（MIT とのデュアル） | 該当なし | なし | 無償 | [astral-sh/uv](https://github.com/astral-sh/uv) |
| Bun | MIT（同梱物は別ライセンス） | 該当なし | クラッシュレポートの自動送信が **macOS / Windows で ON、Linux は OFF**（`DO_NOT_TRACK=1` で無効。他のテレメトリは送らない） | 無償 | [environment-variables](https://github.com/oven-sh/bun/blob/main/docs/runtime/environment-variables.mdx) |
| zellij | MIT | 該当なし | なし | 無償 | [zellij-org/zellij](https://github.com/zellij-org/zellij) |
| ast-grep | MIT | 該当なし | なし | 無償 | [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) |
| yq | MIT | 該当なし | なし | 無償 | [mikefarah/yq](https://github.com/mikefarah/yq) |

## uv tool で入れるもの

| 項目 | ライセンス | 規約の同意 | データ収集（既定） | 商用の条件 | 根拠 |
|---|---|---|---|---|---|
| markitdown | MIT | 該当なし | なし | 無償 | [microsoft/markitdown](https://github.com/microsoft/markitdown) |

## macOS 固有

| 項目 | ライセンス | 規約の同意 | データ収集（既定） | 商用の条件 | 根拠 |
|---|---|---|---|---|---|
| Homebrew | BSD-2-Clause | 該当なし | **ON**（`brew analytics off` または `HOMEBREW_NO_ANALYTICS=1`。パッケージ名・OS・アーキテクチャなど。利用者 ID と IP は含まない） | 無償 | [Analytics](https://docs.brew.sh/Analytics) |
| ★ Docker Desktop | 独自（Docker Subscription Service Agreement） | インストール / 利用時 | 未確認 | **従業員 250 人以上 または 年商 1,000 万ドル以上の組織、および政府機関は有償** | [desktop-license](https://docs.docker.com/subscription/desktop-license/) |
| ★ OrbStack | 独自 | 利用時 | 未確認 | **商用・業務利用は有償（$8 / user / 月）。無償は個人の非商用のみ** | [pricing](https://orbstack.dev/pricing) |
| Colima | MIT | 該当なし | なし | 無償 | [abiosoft/colima](https://github.com/abiosoft/colima) |

## Ubuntu 標準リポジトリのパッケージ

ca-certificates, curl, unzip, openssh-client, build-essential, pkgconf, libssl-dev, git, git-lfs, jq, ripgrep, tree, fzf, fd-find, bubblewrap, socat, zsh, tmux, gnupg（19 件）。

いずれも Ubuntu が配布する OSS で、ディストリビューションのライセンスに従います。インストールが同意トリガーになるもの、データ収集を行うもの、商用利用に有償ライセンスが必要なものはありません。

## テレメトリを無効にする

既定で有効なものをまとめて切る場合:

```bash
# Claude Code（利用メトリクス・エラー報告・フィードバック送信をまとめて無効化）
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# Gemini CLI（~/.gemini/settings.json）
#   { "privacy": { "usageStatisticsEnabled": false } }

# Azure CLI
az config set core.collect_telemetry=no

# Homebrew（macOS）
brew analytics off

# Bun（macOS のクラッシュレポート送信）
export DO_NOT_TRACK=1
```

`DO_NOT_TRACK=1` は [do-not-track.dev](https://do-not-track.dev/) の共通規約で、Bun のほか対応ツールに効きます。Antigravity CLI は CLI 側の設定で変更します（off でもサービス提供目的の利用は続きます）。
