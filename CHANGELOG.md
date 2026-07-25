# Changelog

## [0.4.0](https://github.com/ozzy-labs/agentyard/compare/v0.3.1...v0.4.0) (2026-07-25)


### Features

* add opt-in Bun runtime (INSTALL_BUN) via mise ([#179](https://github.com/ozzy-labs/agentyard/issues/179)) ([2e76ad5](https://github.com/ozzy-labs/agentyard/commit/2e76ad5248e5e905afa95f2419ac6b4549bdd51c))


### Bug Fixes

* gate pre-commit trivy on high/critical severity ([#189](https://github.com/ozzy-labs/agentyard/issues/189)) ([4fd7c8c](https://github.com/ozzy-labs/agentyard/commit/4fd7c8c728c9c872bf046262fbf5c8a5c61a8e9b))
* make canary green (trivy attestation 403, PPA codename fallback, issue dedup) ([#196](https://github.com/ozzy-labs/agentyard/issues/196)) ([21ec11c](https://github.com/ozzy-labs/agentyard/commit/21ec11cf6d1fa5bdec0b69acbf45112db4eac684))
* run chezmoi apply non-interactively (--force) in all modes ([#182](https://github.com/ozzy-labs/agentyard/issues/182)) ([e68cdb9](https://github.com/ozzy-labs/agentyard/commit/e68cdb9b4aaa35a90c9c79d09120bf9096af9418))


### Documentation

* add ADR-0006 install method selection policy ([#181](https://github.com/ozzy-labs/agentyard/issues/181)) ([d2b6c7e](https://github.com/ozzy-labs/agentyard/commit/d2b6c7e0632c807c6c18decec5817e567d8f30d0))


### Continuous Integration

* fix MISE_DISABLE_TOOLS to actually exclude trivy ([#188](https://github.com/ozzy-labs/agentyard/issues/188)) ([f4f4085](https://github.com/ozzy-labs/agentyard/commit/f4f408580f8fe52a24164fe2ac9fac34e15f483d))

## [0.3.1](https://github.com/ozzy-labs/agentic-bootstrap/compare/v0.3.0...v0.3.1) (2026-05-31)


### Bug Fixes

* **docs:** align README with v0.3.0 implementation + add trivy to root .mise.toml ([#162](https://github.com/ozzy-labs/agentic-bootstrap/issues/162)) ([56ac3ba](https://github.com/ozzy-labs/agentic-bootstrap/commit/56ac3baeab5fa17a5fcbb4697e64ecdd99586eb5))
* **prompts:** fail-loud when /dev/tty attach fails (silent prompt-invisibility bug) ([#159](https://github.com/ozzy-labs/agentic-bootstrap/issues/159)) ([a8a66bd](https://github.com/ozzy-labs/agentic-bootstrap/commit/a8a66bd91c70243513b3ed1a4c06dfb0d28a4543))


### Documentation

* **adr:** modernize ADR-0002 / ADR-0003 and add ADR-0005 (multiplexer + macOS policy) ([#164](https://github.com/ozzy-labs/agentic-bootstrap/issues/164)) ([66f5fe3](https://github.com/ozzy-labs/agentic-bootstrap/commit/66f5fe361c29a1e877683c527aa6c3b2bd68c25b))


### Tests

* automate PR [#150](https://github.com/ozzy-labs/agentic-bootstrap/issues/150) manual cases (.tmux.conf respect, macOS skip) + smoke lib syntax loop + doctor exit code ([#163](https://github.com/ozzy-labs/agentic-bootstrap/issues/163)) ([4a6fdcf](https://github.com/ozzy-labs/agentic-bootstrap/commit/4a6fdcfac11424f8b2a76ac951c3d4a3fd22aba9))
* **smoke:** widen doctor exit code acceptance to spec {0,1,2} ([#165](https://github.com/ozzy-labs/agentic-bootstrap/issues/165)) ([c3b9254](https://github.com/ozzy-labs/agentic-bootstrap/commit/c3b92541ddc48db26177e8024b7a968743fad222))

## [0.3.0](https://github.com/ozzy-labs/agentic-bootstrap/compare/v0.2.0...v0.3.0) (2026-05-30)


### Features

* **install:** add tmux as opt-in + sensible .tmux.conf (Linux) ([#150](https://github.com/ozzy-labs/agentic-bootstrap/issues/150)) ([25f29e2](https://github.com/ozzy-labs/agentic-bootstrap/commit/25f29e280a3b7873f3acb7ebd2ecb672798042c4))
* **install:** add zellij as opt-in multiplexer ([#149](https://github.com/ozzy-labs/agentic-bootstrap/issues/149)) ([c6d7044](https://github.com/ozzy-labs/agentic-bootstrap/commit/c6d70448d7cef40d98471d908418fec778d5e7b0))


### Bug Fixes

* **dotfiles:** include trivy in mise global config ([#153](https://github.com/ozzy-labs/agentic-bootstrap/issues/153)) ([20fbabc](https://github.com/ozzy-labs/agentic-bootstrap/commit/20fbabc107efe271394ff4b4dd233d570763003b)), closes [#144](https://github.com/ozzy-labs/agentic-bootstrap/issues/144)
* **dotfiles:** include zellij in mise global config ([#156](https://github.com/ozzy-labs/agentic-bootstrap/issues/156)) ([fba52f0](https://github.com/ozzy-labs/agentic-bootstrap/commit/fba52f08c1d82c83cc95ca99801ec8f39efa28bb))
* **install:** legacy PPA .sources detection and bundled .mise.toml auto-trust ([#140](https://github.com/ozzy-labs/agentic-bootstrap/issues/140)) ([1036805](https://github.com/ozzy-labs/agentic-bootstrap/commit/10368051c9106f8c099369daa794a09c03e56178))


### Refactoring

* **scripts:** unify Linux/macOS mise helpers via lib/mise.sh ([#157](https://github.com/ozzy-labs/agentic-bootstrap/issues/157)) ([7804715](https://github.com/ozzy-labs/agentic-bootstrap/commit/78047150e64da56b361cc810a028c19f55b70ba5))


### Tests

* **integration:** add upgrade-from-prior-version scenario matrix ([#154](https://github.com/ozzy-labs/agentic-bootstrap/issues/154)) ([e27cd7f](https://github.com/ozzy-labs/agentic-bootstrap/commit/e27cd7f86772487aea8ca6bb3113907425ce831c)), closes [#142](https://github.com/ozzy-labs/agentic-bootstrap/issues/142)

## [0.2.0](https://github.com/ozzy-labs/agentic-bootstrap/compare/v0.1.4...v0.2.0) (2026-05-06)


### Refactoring

* rename BOOTSTRAP_* env vars to AGENTIC_BOOTSTRAP_* with fallback ([#136](https://github.com/ozzy-labs/agentic-bootstrap/issues/136)) ([69146d6](https://github.com/ozzy-labs/agentic-bootstrap/commit/69146d66f2a4546557fee146a2c40b577a4d7957))

## [0.1.4](https://github.com/ozzy-labs/bootstrap/compare/v0.1.3...v0.1.4) (2026-05-06)


### Bug Fixes

* **install:** pin pnpm to 10.33.2 to avoid aqua-registry mismatch ([#123](https://github.com/ozzy-labs/bootstrap/issues/123)) ([2f6f0e5](https://github.com/ozzy-labs/bootstrap/commit/2f6f0e520543bd974c4bc270ffcd01aad713ad4f))
* **lefthook:** unpin base; override via skip+replacement in lefthook.yaml ([#130](https://github.com/ozzy-labs/bootstrap/issues/130)) ([7106f17](https://github.com/ozzy-labs/bootstrap/commit/7106f17b549b8e15fdb95b75f809466f70b654e7))

## [0.1.3](https://github.com/ozzy-labs/bootstrap/compare/v0.1.2...v0.1.3) (2026-05-04)


### Bug Fixes

* **install:** apply git-core/ppa 4096R fingerprint in setup-local-linux too ([#117](https://github.com/ozzy-labs/bootstrap/issues/117)) ([fbf3c4f](https://github.com/ozzy-labs/bootstrap/commit/fbf3c4f03a2257354bb95c1a6adcac99c662bcbc))
* **install:** bump git-core/ppa key fingerprint to 4096R rotation ([#112](https://github.com/ozzy-labs/bootstrap/issues/112)) ([36135e2](https://github.com/ozzy-labs/bootstrap/commit/36135e2c3305947c3215b5269528231caa5f181e)), closes [#110](https://github.com/ozzy-labs/bootstrap/issues/110) [#111](https://github.com/ozzy-labs/bootstrap/issues/111)


### Documentation

* **apt:** update apt_add_ppa fingerprint example to 4096R rotation key ([#114](https://github.com/ozzy-labs/bootstrap/issues/114)) ([b96de26](https://github.com/ozzy-labs/bootstrap/commit/b96de26065ffdc12b2fc7fff23a65924b71d22af))

## [0.1.2](https://github.com/ozzy-labs/bootstrap/compare/v0.1.1...v0.1.2) (2026-05-02)


### Bug Fixes

* **install:** replace add-apt-repository with direct PPA registration ([#109](https://github.com/ozzy-labs/bootstrap/issues/109)) ([6cc7c6b](https://github.com/ozzy-labs/bootstrap/commit/6cc7c6be9cc6454984b4135adc7fe13468b0711b))
* **install:** retry add-apt-repository on Launchpad failures ([#107](https://github.com/ozzy-labs/bootstrap/issues/107)) ([40f14c8](https://github.com/ozzy-labs/bootstrap/commit/40f14c829b6bd6e98a03dbd2e484fc2d62abfa53))

## [0.1.1](https://github.com/ozzy-labs/bootstrap/compare/v0.1.0...v0.1.1) (2026-05-02)


### Bug Fixes

* **lint:** exclude CHANGELOG.md from markdownlint ([#104](https://github.com/ozzy-labs/bootstrap/issues/104)) ([f2b5e12](https://github.com/ozzy-labs/bootstrap/commit/f2b5e12ac5a2fa7302fb02986455f6e1966f2be6))


### Documentation

* **rules:** clarify fix vs ci commit type boundary ([#106](https://github.com/ozzy-labs/bootstrap/issues/106)) ([8be60ee](https://github.com/ozzy-labs/bootstrap/commit/8be60ee2941acd522ae0440547219b1dda7119e0))

## 0.1.0 (2026-04-29)


### Features

* add AI power tools (markitdown, tesseract, ffmpeg, ast-grep, yq) ([#23](https://github.com/ozzy-labs/bootstrap/issues/23)) ([94304fd](https://github.com/ozzy-labs/bootstrap/commit/94304fdcd218ad6928e9ad04f17b4416c99c80b8)), closes [#16](https://github.com/ozzy-labs/bootstrap/issues/16) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* add GitHub Copilot CLI and Gemini CLI support ([#5](https://github.com/ozzy-labs/bootstrap/issues/5)) ([b9a4021](https://github.com/ozzy-labs/bootstrap/commit/b9a4021ba5aa884ae58cdd1121042b26d6aa422b))
* add non-interactive mode and BATS tests for shell config logic ([#35](https://github.com/ozzy-labs/bootstrap/issues/35)) ([9ed2945](https://github.com/ozzy-labs/bootstrap/commit/9ed294560a0e69c51ca519366acf77f0a8860d4a)), closes [#30](https://github.com/ozzy-labs/bootstrap/issues/30) [#28](https://github.com/ozzy-labs/bootstrap/issues/28)
* add scripts/update-tools.sh for batch tool updates ([#26](https://github.com/ozzy-labs/bootstrap/issues/26)) ([0501ac8](https://github.com/ozzy-labs/bootstrap/commit/0501ac89e21f2dca4b4c7e4c1b1b235028859ae8)), closes [#19](https://github.com/ozzy-labs/bootstrap/issues/19) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* add shellcheck to dev helper tools ([#24](https://github.com/ozzy-labs/bootstrap/issues/24)) ([706b20f](https://github.com/ozzy-labs/bootstrap/commit/706b20fd1bd05ba835caee7c5ee5cf097efc0d19)), closes [#17](https://github.com/ozzy-labs/bootstrap/issues/17) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* **doctor:** add doctor subcommand for environment diagnostics ([#92](https://github.com/ozzy-labs/bootstrap/issues/92)) ([2b37eeb](https://github.com/ozzy-labs/bootstrap/commit/2b37eebc7cbea3b19cc6edba42d1a3df155c05be))
* generalize OS support (mise-first, macOS + non-WSL Linux canary) ([#55](https://github.com/ozzy-labs/bootstrap/issues/55)) ([9077ba0](https://github.com/ozzy-labs/bootstrap/commit/9077ba0dd7766a85cf0b27b1fd2677df2a5b2e89))
* install.sh エントリーポイントの追加とブランチ参照の修正 ([#3](https://github.com/ozzy-labs/bootstrap/issues/3)) ([0246976](https://github.com/ozzy-labs/bootstrap/commit/02469768c1949c5d0b72009f7ea5efe66a1ca84d))
* **install:** add bubblewrap to bootstrap tools ([f87e2b3](https://github.com/ozzy-labs/bootstrap/commit/f87e2b3b9c121824d033b1558ec1e8c6b3320bb4))
* integrate dev-config multi-agent architecture ([#8](https://github.com/ozzy-labs/bootstrap/issues/8)) ([73cc9c1](https://github.com/ozzy-labs/bootstrap/commit/73cc9c142c78cc8f41d72695b535e45690d48b37))
* replace git-secrets with gitleaks via mise ([#22](https://github.com/ozzy-labs/bootstrap/issues/22)) ([eca6538](https://github.com/ozzy-labs/bootstrap/commit/eca6538e6fde01888593b27286d3d527e3502889)), closes [#15](https://github.com/ozzy-labs/bootstrap/issues/15) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* replace Volta with mise for unified runtime management ([#21](https://github.com/ozzy-labs/bootstrap/issues/21)) ([63ed0ca](https://github.com/ozzy-labs/bootstrap/commit/63ed0cad8682935997ab6e0b4cb1bdadef0fe1c5)), closes [#14](https://github.com/ozzy-labs/bootstrap/issues/14) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* **skills-sync:** migrate to adapter-aware sync via @ozzylabs/skills ([#61](https://github.com/ozzy-labs/bootstrap/issues/61)) ([64ae78b](https://github.com/ozzy-labs/bootstrap/commit/64ae78bea6c0b3bf9fe404b1b4e9583c5a48ed45))
* WSL2/Ubuntu開発環境セットアップスクリプトの初回リリース ([#2](https://github.com/ozzy-labs/bootstrap/issues/2)) ([c5575e6](https://github.com/ozzy-labs/bootstrap/commit/c5575e61f13b787b580352cd81cbbb51cac3287a))


### Bug Fixes

* add || true to npm update commands to prevent set -e exit ([#9](https://github.com/ozzy-labs/bootstrap/issues/9)) ([d764967](https://github.com/ozzy-labs/bootstrap/commit/d76496741e3b129f433cd1e91b92625c8bd1ea3b))
* add timeout to copilot CLI commands to prevent shim hangs ([#11](https://github.com/ozzy-labs/bootstrap/issues/11)) ([bb9c6bf](https://github.com/ozzy-labs/bootstrap/commit/bb9c6bfdd3f43c34b6c0afd86e5dad6a915a249b))
* **copilot:** restore @ozzylabs/skills markers in copilot-instructions.md ([#101](https://github.com/ozzy-labs/bootstrap/issues/101)) ([1f1a0ac](https://github.com/ozzy-labs/bootstrap/commit/1f1a0ac36f13c8cd510259fbafa1cbf908aa57e2))
* curl|bash 経由実行時の unbound variable / read EOF を修正 ([#48](https://github.com/ozzy-labs/bootstrap/issues/48)) ([139b018](https://github.com/ozzy-labs/bootstrap/commit/139b018f9b94b356fbb3b26a01a0b40d88f75559))
* detect VS Code copilot shim and skip it ([#12](https://github.com/ozzy-labs/bootstrap/issues/12)) ([4e7f6c9](https://github.com/ozzy-labs/bootstrap/commit/4e7f6c9f940e693b95f2fa03f3966a38a58a4c21))
* **install:** avoid set -e exit when no cloud / AI agent CLIs install ([#100](https://github.com/ozzy-labs/bootstrap/issues/100)) ([86d2029](https://github.com/ozzy-labs/bootstrap/commit/86d20296e8c625310d41a31fbeab76b8bf6a0116))
* **install:** pin pnpm to v10 to work around aqua registry lag ([#98](https://github.com/ozzy-labs/bootstrap/issues/98)) ([a40c92f](https://github.com/ozzy-labs/bootstrap/commit/a40c92f6b4260ff4425c0e2469cfb08611404419))
* mise --global 操作の override WARN を抑制 ([#50](https://github.com/ozzy-labs/bootstrap/issues/50)) ([59f8a0b](https://github.com/ozzy-labs/bootstrap/commit/59f8a0b831c8ed3f16fe36a497c29f6c90a630f1))
* prevent update commands from hanging on interactive prompts ([#10](https://github.com/ozzy-labs/bootstrap/issues/10)) ([61bc15b](https://github.com/ozzy-labs/bootstrap/commit/61bc15b026283cf8d4175cfb5f03cf55675ec390))
* setup-local-ubuntu.sh も pipe 経由で対話プロンプトを受け付ける ([#49](https://github.com/ozzy-labs/bootstrap/issues/49)) ([798f2e6](https://github.com/ozzy-labs/bootstrap/commit/798f2e61a6d8002a13794f30b2367392a00d887b))
* wslu が Ubuntu 26.04 で見つからない問題にフォールバック実装 ([#44](https://github.com/ozzy-labs/bootstrap/issues/44)) ([55c13c5](https://github.com/ozzy-labs/bootstrap/commit/55c13c5e827104a668750fc78aee6ffdb926d504)), closes [#39](https://github.com/ozzy-labs/bootstrap/issues/39)


### Refactoring

* make Azure CLI and Google Cloud CLI opt-in ([#25](https://github.com/ozzy-labs/bootstrap/issues/25)) ([ab9ec39](https://github.com/ozzy-labs/bootstrap/commit/ab9ec3946e05f75c9a458180a20a3f33f8383b27)), closes [#18](https://github.com/ozzy-labs/bootstrap/issues/18) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* **scripts:** split setup-local-linux.sh into lib modules ([#91](https://github.com/ozzy-labs/bootstrap/issues/91)) ([9524225](https://github.com/ozzy-labs/bootstrap/commit/9524225fa5e850b3098f4fd81230fab954f600e3))


### Documentation

* add multi-agent instruction files for Codex, Copilot, and Gemini ([#7](https://github.com/ozzy-labs/bootstrap/issues/7)) ([56bfd66](https://github.com/ozzy-labs/bootstrap/commit/56bfd669cdb7eed2ef7730c1ec855d29f3a3e261))
* **adr:** add ADR-0004 to reaffirm Bash-based architecture ([#90](https://github.com/ozzy-labs/bootstrap/issues/90)) ([776eac9](https://github.com/ozzy-labs/bootstrap/commit/776eac9e6a1bdcab9538775094ea23e077f66850))
* modernize README and changelog for dual-mode AI-driven setup ([#27](https://github.com/ozzy-labs/bootstrap/issues/27)) ([15544bf](https://github.com/ozzy-labs/bootstrap/commit/15544bfb9d9178a30bcafd2b5464e93c61165322)), closes [#20](https://github.com/ozzy-labs/bootstrap/issues/20) [#13](https://github.com/ozzy-labs/bootstrap/issues/13)
* **readme:** publish-readiness — TLS hardening, SHA256 verification, doctor section ([#95](https://github.com/ozzy-labs/bootstrap/issues/95)) ([8192e7b](https://github.com/ozzy-labs/bootstrap/commit/8192e7b3918ffe0643950f4fb9bb973fa8caa68f))
* サポート Ubuntu 一覧（26.04 対応状況含む）を README に明記 ([#47](https://github.com/ozzy-labs/bootstrap/issues/47)) ([0e94822](https://github.com/ozzy-labs/bootstrap/commit/0e94822f30b7177d4906fdcbc6b617a48090ed58))
* 内部成果物を日本語優先にする言語ポリシーを明文化 ([#40](https://github.com/ozzy-labs/bootstrap/issues/40)) ([2165c6f](https://github.com/ozzy-labs/bootstrap/commit/2165c6f27d20efb0d95991b72e25d82a78be2fb0))


### Continuous Integration

* add GitHub Actions workflows for lint / smoke / unit / integration ([#37](https://github.com/ozzy-labs/bootstrap/issues/37)) ([a66c44e](https://github.com/ozzy-labs/bootstrap/commit/a66c44e8a7bb3a6c4b737ee3d8ce602929c347c7)), closes [#32](https://github.com/ozzy-labs/bootstrap/issues/32) [#28](https://github.com/ozzy-labs/bootstrap/issues/28)
* add weekly canary workflow against ubuntu:devel and rolling ([#38](https://github.com/ozzy-labs/bootstrap/issues/38)) ([d9463a7](https://github.com/ozzy-labs/bootstrap/commit/d9463a761508d5513a64af65bff7b38360c93be1)), closes [#33](https://github.com/ozzy-labs/bootstrap/issues/33) [#28](https://github.com/ozzy-labs/bootstrap/issues/28)
* apply mise canonical pattern per handbook[#84](https://github.com/ozzy-labs/bootstrap/issues/84) ([#69](https://github.com/ozzy-labs/bootstrap/issues/69)) ([a43db63](https://github.com/ozzy-labs/bootstrap/commit/a43db6306dd80635b2456b7592b0cd454b7b1b1a))
* canary の重複起票防止と ci:integration ラベル自動付与を導入 ([#46](https://github.com/ozzy-labs/bootstrap/issues/46)) ([faef46b](https://github.com/ozzy-labs/bootstrap/commit/faef46b99e76e1280bb10d681c972ac7c9591189))
* **infra:** apply canonical pattern to CI workflows ([#70](https://github.com/ozzy-labs/bootstrap/issues/70)) ([87a4d5c](https://github.com/ozzy-labs/bootstrap/commit/87a4d5cc10724f8c6c789149ecdf406c32beb98e)), closes [#68](https://github.com/ozzy-labs/bootstrap/issues/68)
* **release:** add release-please for CHANGELOG + GitHub Release automation ([#93](https://github.com/ozzy-labs/bootstrap/issues/93)) ([5086075](https://github.com/ozzy-labs/bootstrap/commit/5086075588ca445f518ebf73644686f4b3c327af))
* ワークフロー使用 actions を Node.js 24 対応版へ更新 ([#45](https://github.com/ozzy-labs/bootstrap/issues/45)) ([248fbca](https://github.com/ozzy-labs/bootstrap/commit/248fbcaefc6893eb794fe53252027cee2d9504a6))


### Tests

* 22.04 統合テストを修正し L1 のローカル実行手順を追記 ([#43](https://github.com/ozzy-labs/bootstrap/issues/43)) ([353ea30](https://github.com/ozzy-labs/bootstrap/commit/353ea302f7658a6d400fc0b3403272117c81aee4))
* add Docker-based integration tests for Ubuntu 22.04 / 24.04 ([#36](https://github.com/ozzy-labs/bootstrap/issues/36)) ([0743bff](https://github.com/ozzy-labs/bootstrap/commit/0743bff9c2adb8ed4ddc1789024dcbd9c698798e)), closes [#31](https://github.com/ozzy-labs/bootstrap/issues/31) [#28](https://github.com/ozzy-labs/bootstrap/issues/28)
* add smoke tests for CLI entry points ([#34](https://github.com/ozzy-labs/bootstrap/issues/34)) ([94b0f76](https://github.com/ozzy-labs/bootstrap/commit/94b0f7601b99dd551c383d6abea8b9a711b0f9d9)), closes [#29](https://github.com/ozzy-labs/bootstrap/issues/29) [#28](https://github.com/ozzy-labs/bootstrap/issues/28)

## Changelog

All notable changes to this project are documented in this file.

This file is **automatically generated by [release-please](https://github.com/googleapis/release-please)**
based on Conventional Commits. Manual edits made directly to this file will be
overwritten on the next release. To influence the next release, write
Conventional Commits in your PR titles / commit messages.

The full pre-v0.1.0 history is preserved in the [git log](https://github.com/ozzy-labs/bootstrap/commits/main)
and the v0.1.0 release notes (which include every Conventional Commit since
the project's first commit).
