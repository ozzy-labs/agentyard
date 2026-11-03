# v0.4.x から v0.5.0 への移行

v0.5.0 は、ホストで直接 AI エージェントを動かす構成を基本に、ツールと設定を全面的に見直したリリースです（[ADR-0007](adr/ADR-0007-host-first-redesign.md)）。既存の環境で v0.5.0 を実行しても、**v0.4.x が入れたツールや設定は削除しません**。必要に応じて、以下の手順で整理してください。

## 1. サポート範囲

- Ubuntu 22.04 は非サポートになりました。22.04 では v0.4.x を使うか、24.04 以降にアップグレードしてください（`sudo do-release-upgrade`）。
- Debian などその他の Linux、Intel Mac も非サポートです。`AGENTYARD_ALLOW_UNSUPPORTED=1` で自己責任の続行はできます。

## 2. 既定で入らなくなったもの

次のものは opt-in になりました。必要なら `AGENTYARD_WITH` で指定するか、選択画面で選んでください。

| 以前 | v0.5.0 での指定 |
|---|---|
| Docker（`INSTALL_CONTAINER`） | `AGENTYARD_WITH=docker` |
| zsh + oh-my-zsh（`setup-zsh-linux.sh`） | `AGENTYARD_WITH=zsh` |
| AWS CLI（`INSTALL_AWS_CLI`） | `AGENTYARD_WITH=aws` |
| ast-grep / yq / markitdown（`INSTALL_AI_POWER_TOOLS`） | `AGENTYARD_WITH=power` |
| Gemini CLI | `AGENTYARD_AGENTS=...,gemini` |

次のものは agentyard の管理外になりました（入っているものはそのまま残ります）。

- gitleaks、trivy、shellcheck、just: 各リポジトリの `mise.toml` で固定してください。
- chezmoi、zoxide: 必要なら各自で入れてください。
- tesseract-ocr、ffmpeg: 必要なら `sudo apt install tesseract-ocr tesseract-ocr-jpn ffmpeg`。
- mise の python: プロジェクトの Python は uv で管理してください。

旧バージョンが `~/.config/mise/config.toml` に書いた項目は残ります。不要なものは `mise unuse -g <tool>` で外してください。

## 3. 設定の変更

- **chezmoi で配布していた dotfiles は廃止**しました。`~/.claude/settings.json`、`~/.gemini/`、`~/.zshrc.d/ozzylabs.zsh` などは残っているので、不要なら削除してください。
- **ロケール（`LANG=ja_JP.UTF-8`）とタイムゾーンは設定しなくなりました**。旧バージョンが `.bashrc` / `.zshrc` に書いた `export LANG=...` は残ります。
- **Git の `pull.rebase`、`core.editor`、`core.fileMode` は設定しなくなりました**。旧バージョンが書いた値は残ります。
- シェル設定は、目印で囲んだブロック（`# >>> agentyard >>>`）だけを追記する方式になりました。旧バージョンが直接書いた次の行は重複するので、削除して構いません。
  - `# mise（バージョン管理）` と `eval "$(... mise activate ...)"`
  - `# ローカルユーザー向けバイナリ` と `export PATH="$HOME/.local/bin:$PATH"`
  - `# pnpm グローバルパッケージ` と `PNPM_HOME` の行
  - `eval "$(zoxide init ...)"`、`~/.zshrc.d` の読み込み、fzf のキーバインドの行

## 4. AI エージェント

- Codex CLI は公式インストーラで入れるようになりました。npm で入れた Codex は、Node を更新すると消えます。切り替えるには:

  ```bash
  npm uninstall -g @openai/codex
  ./install.sh install
  ```

- Gemini CLI は企業の Gemini Code Assist 契約者向けの製品になり、opt-in になりました。個人利用（無料、Google AI Pro / Ultra）は Antigravity CLI に移行しています（[Google の移行ガイド](https://antigravity.google/docs/cli/gcli-migration)）。Antigravity CLI は `AGENTYARD_AGENTS=...,antigravity` で入れられます（opt-in）。npm で入れた Gemini CLI を使い続ける場合は、`npm uninstall -g @google/gemini-cli` のあと `AGENTYARD_AGENTS=...,gemini` で入れ直すと、Node の更新で消えなくなります。

### gh（v0.5.1 以降）

Ubuntu 標準のリポジトリの `gh`（24.04: 2.45、26.04: 2.46）が入っている場合、agentyard は GitHub 公式の apt リポジトリを登録し、公式版に更新します（対話モードでは確認します）。

## 5. 環境変数

| 以前 | v0.5.0 |
|---|---|
| `INSTALL_*=0/1` | `AGENTYARD_AGENTS` / `AGENTYARD_WITH`（`INSTALL_*` は移行期間中は受け付けます） |
| `./install.sh local` / `all` | `./install.sh install`（旧名も受け付けます） |
| `./install.sh zsh` | `AGENTYARD_WITH=zsh ./install.sh install` |

## 6. 入手方法

リリースのタグを指定して実行することを推奨します。リリースの配布物はチェックサムで検証され、GitHub Artifact Attestations で出どころを確認できます。

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh | bash
```
