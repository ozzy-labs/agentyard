# リリース前の手動確認項目

CI（Docker コンテナ、GitHub ホストランナー）では確認できない項目です。リリース前に実機で確認し、結果をリリース PR に記録してください。根拠は [ADR-0007](adr/ADR-0007-host-first-redesign.md) §9 です。

## WSL2（Ubuntu 24.04 / 26.04）

- [ ] `./install.sh install`（対話モード）が最後まで完了する
- [ ] 選択画面（whiptail と、`AGENTYARD_UI=plain` の番号入力）で選択と確定ができる
- [ ] Docker を選択し、systemd が無効な場合: `wsl.conf` の書き換えの確認が出て、Docker のインストールだけが中断される
- [ ] systemd を有効にして再実行すると、Docker Engine が入り、`docker run hello-world` が動く
- [ ] Docker Desktop の WSL 連携を有効にした環境では、Docker Engine を入れずにスキップする
- [ ] `wsl-browser` を選択すると、`gh auth login --web` で Windows のブラウザが開く
- [ ] 新しいターミナル（ログインシェル）と VS Code の統合ターミナル（非ログインシェル）の両方で、`claude`、`codex`、`node`、`uv` が見える
- [ ] `./install.sh doctor` の WSL セクションが妥当な内容を表示する
- [ ] インストール中にベンダーのインストーラが質問を出さない（例: Codex の `Start Codex now?`）。CI は TTY なしで動くため検出できない

## AI エージェントのログイン

- [ ] Claude Code: `claude` でログインできる
- [ ] Codex CLI: `codex` でログインできる
- [ ] Copilot CLI: `copilot` で `/login` できる（Copilot 契約のあるアカウント）
- [ ] Antigravity CLI（opt-in）: WSL でキーリングを用いたログインが成立する（成立すれば既定に戻すかを判断する。ADR-0007 §4）
- [ ] Gemini CLI（opt-in）: 起動でき、自動更新と mise による更新が衝突しない

## AGENTS.md の連携

- [ ] 各エージェントで、`~/.agents/AGENTS.md` に書いた指示が反映される（例: 「返答の最後に ✅ を付ける」と書いて確認）
  - Claude Code: `/memory` に `~/.agents/AGENTS.md` が表示される
  - Codex: シンボリックリンクの `~/.codex/AGENTS.md` を読む
  - Gemini CLI: シンボリックリンクの `~/.gemini/GEMINI.md` を読む
  - Copilot CLI: `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` 経由で読み、`~/.agents/skills/` 配下を誤って読み込まない
  - Antigravity CLI: `~/.gemini/AGENTS.md` の `@[agentyard](~/.agents/AGENTS.md)` で読む
- [ ] `CLAUDE_CONFIG_DIR` を設定した環境で、ユーザー全体の CLAUDE.md がその配下で読まれる

## 通常の Linux（Ubuntu Desktop / Server）

- [ ] 24.04: `./install.sh doctor` が bwrap の失敗を検出し、`AGENTYARD_WITH=apparmor` で解消する
- [ ] 26.04: AppArmor の対処なしで bwrap のサンドボックスが動く
- [ ] 24.04 から 26.04 へ `do-release-upgrade` した後、再実行で Docker / Azure CLI の apt リポジトリが書き直される

## macOS

- [ ] macOS 26（Apple Silicon）: 対話モードで完了し、Homebrew がなければ導入される
- [ ] macOS 27（Apple Silicon）: 同上（GitHub ホストランナーが提供されるまでは手動で確認）
- [ ] Docker の選択（Docker Desktop / OrbStack / Colima）で、それぞれ入る
- [ ] `./install.sh update` が agentyard の Brewfile にあるものだけを更新する

## リリース

- [ ] release PR（`chore(main): release X.Y.Z`）の CI が、承認操作なしで走る（GitHub App トークンの設定が効いているか。未設定なら `Awaiting approval` のまま止まる）
- [ ] release PR のマージで tag と GitHub Release が作られ、`agentyard.tar.gz` / `install.sh` とその `.sha256` が添付される
- [ ] `curl ... releases/latest/download/install.sh | bash` が新しい版を取得する

## uninstall

- [ ] `./install.sh uninstall` の後、シェル設定ファイルと指示ファイルから agentyard のブロックが消え、ユーザーの内容は残る
- [ ] 残したもの（ツール本体、docker グループなど）が一覧で表示される
