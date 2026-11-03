# agentyard

**Set up a host for AI-agent-driven development — Ubuntu 24.04 / 26.04 (incl. WSL2) and macOS**

[![Lint](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml)
[![Unit](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml)
[![Smoke](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml)
[![Integration](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml)
[![License: MIT](https://img.shields.io/github/license/ozzy-labs/agentyard)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/ozzy-labs/agentyard?label=release)](https://github.com/ozzy-labs/agentyard/releases/latest)

**English | [日本語](README.ja.md)**

agentyard prepares a development host so AI coding agents (Claude Code, Codex, Copilot CLI, Antigravity CLI, Gemini CLI) can work on it directly and safely, and so humans can work in the same terminal. Defaults are minimal; everything opinionated is opt-in. It never overwrites your files: it only adds marked blocks, records what it changed, and can revert them.

Design decisions: [ADR-0007](docs/adr/ADR-0007-host-first-redesign.md). Upgrading from v0.4.x: [migration guide](docs/migration-v0.5.md).

> **Why Bash?** A tool that installs runtimes should not require one. agentyard is plain Bash with no runtime dependencies ([ADR-0004](docs/adr/ADR-0004-stay-bash-and-publish-readiness.md)).

## Quick start

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh | bash
```

You choose agents and opt-in items on a selection screen. To pin a release, add `-s -- --ref vX.Y.Z` after `bash`.

Non-interactive example:

```bash
curl --proto '=https' --tlsv1.2 -fsSL \
  https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh |
  AGENTYARD_ASSUME_YES=1 AGENTYARD_WITH=docker,agents-md bash
```

### Verify before running (optional)

Releases ship `agentyard.tar.gz` (verified by `install.sh` with SHA-256) and `install.sh`, both with [GitHub Artifact Attestations](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations):

```bash
curl -fsSLO https://github.com/ozzy-labs/agentyard/releases/latest/download/install.sh
gh attestation verify install.sh --repo ozzy-labs/agentyard
bash install.sh
```

## Supported platforms

| OS | Architectures |
|---|---|
| Ubuntu 24.04 / 26.04 (WSL2, Desktop, Server) | amd64, arm64 |
| macOS 26 / 27 | Apple Silicon |

Other platforms (Ubuntu 22.04 and older, Debian and other distributions, WSL1, Intel Macs) stop with a message. Set `AGENTYARD_ALLOW_UNSUPPORTED=1` to continue at your own risk. For Ubuntu 22.04, use agentyard v0.4.x.

## What gets installed

Install order of preference: the tool's official method → the OS package manager (apt / Homebrew) → mise.

### Default

| Category | Linux | macOS |
|---|---|---|
| Build | build-essential, pkgconf, libssl-dev | Xcode Command Line Tools |
| Git | git (Ubuntu), git-lfs, gh (official apt repo) | git (CLT), git-lfs, gh (brew) |
| CLI | jq, ripgrep, tree, fzf, fd | same, via Homebrew |
| Sandbox | bubblewrap, socat | built in (Seatbelt) |
| Runtimes | mise, Node.js LTS, pnpm, uv | same |

### AI agents (selectable)

| Agent | Default | Install method |
|---|---|---|
| Claude Code | ✓ | official installer |
| Codex CLI | ✓ | official installer |
| GitHub Copilot CLI | ✓ | official installer (Copilot subscription required) |
| Antigravity CLI | ✓ | official installer (18+, supported countries) |
| Gemini CLI | opt-in | npm package via mise (for Gemini Code Assist customers) |

agentyard only installs agents; it never drives them. Each agent asks you to accept its terms at the first login, except Antigravity CLI, whose terms apply from installation (agentyard shows a notice when it is selected).

### Opt-in (`AGENTYARD_WITH`)

| ID | What |
|---|---|
| `docker` | Linux: Docker Engine (skipped when Docker Desktop's WSL integration is detected). macOS: Docker Desktop / OrbStack / Colima |
| `zsh` | zsh + oh-my-zsh (an existing `~/.zshrc` is kept) |
| `tmux`, `zellij` | terminal multiplexers |
| `aws`, `azure`, `gcloud` | cloud CLIs |
| `ast-grep`, `yq`, `markitdown` (`power` = all three) | agent helper tools |
| `bun` | Bun runtime |
| `agents-md` | user-scope `~/.agents/AGENTS.md` wired to every installed agent |
| `mise-trust` | trust mise configs under directories you choose |
| `wsl-browser` | WSL: open login pages in the Windows browser |
| `apparmor` | Ubuntu 24.04 (non-WSL): let bubblewrap create user namespaces |

Project-specific tools (linters, hooks, language versions, Go / Rust) belong in each repository's `mise.toml`; mise installs them on demand.

## Commands

```bash
./install.sh install          # set up this host (default)
./install.sh update           # update only what agentyard installed
./install.sh doctor           # diagnose the host (exit 0 ok / 1 warnings / 2 errors)
./install.sh doctor --repo .  # do the installed agents read this repo's AGENTS.md?
./install.sh uninstall        # revert what agentyard wrote (tools are kept)
```

`update` upgrades mise and the tools agentyard added to it, uv tools, agents that do not auto-update, and items in agentyard's Brewfile (macOS). Upgrade apt packages with `sudo apt update && sudo apt upgrade`.

## Environment variables

| Variable | Meaning |
|---|---|
| `AGENTYARD_ASSUME_YES=1` (or `-y`, `CI=true`) | non-interactive mode |
| `AGENTYARD_AGENTS` | agents to install (default `claude,codex,copilot,antigravity`) |
| `AGENTYARD_WITH` | opt-in items (comma separated, see above) |
| `AGENTYARD_DOCKER_GROUP=1` | add the user to the `docker` group in non-interactive mode |
| `AGENTYARD_MISE_TRUSTED_PATHS` | directories for `mise-trust` (comma separated) |
| `AGENTYARD_MACOS_DOCKER` | `docker-desktop`, `orbstack`, or `colima` |
| `AGENTYARD_ALLOW_UNSUPPORTED=1` | continue on unsupported platforms |
| `AGENTYARD_UI=plain` | numbered list instead of the whiptail checklist |
| `AGENTYARD_REF` | release tag to download (same as `--ref`) |
| `SETUP_LOG=1` | write a log to `~/agentyard-setup-*.log` |

Legacy `INSTALL_*` variables are still mapped during the migration period.

## How agentyard changes your host

- **Shell**: `~/.config/agentyard/env.sh` (POSIX sh: PATH, mise shims, Homebrew) is sourced from login profiles (`~/.profile`, `~/.zprofile`), and `~/.config/agentyard/interactive.sh` (`mise activate`, fzf key bindings) from `~/.bashrc` / `~/.zshrc`. Only a marked block is added to each file.
- **Git**: sets `init.defaultBranch=main` if unset, `core.autocrlf=input` on WSL, and runs `git lfs install --skip-repo`. Asks for `user.name` / `user.email` only when unset (include files are honored).
- **apt**: installs only missing packages; vendor repositories use deb822 `.sources` files with keys as distributed.
- **Records**: `~/.config/agentyard/state` (and `Brewfile` on macOS) list what agentyard installed or changed; `update` and `uninstall` act only on those.

## User-scope AGENTS.md

With `agents-md`, `~/.agents/AGENTS.md` becomes the single place for your personal instructions. agentyard creates a template if it is missing, appends a generated "host environment" block, and wires each installed agent to it:

| Agent | How |
|---|---|
| Claude Code | `@~/.agents/AGENTS.md` import in `~/.claude/CLAUDE.md` |
| Antigravity CLI | `@[agentyard](~/.agents/AGENTS.md)` include in `~/.gemini/AGENTS.md` |
| Copilot CLI | `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` includes `~/.agents` |
| Codex CLI | `~/.codex/AGENTS.md` symlink (or a reference line if the file exists) |
| Gemini CLI | `~/.gemini/GEMINI.md` symlink (or a reference line if the file exists) |

Agent settings files are never edited.

## Development

```bash
mise install                 # dev tools pinned in .mise.toml
lefthook run pre-commit      # lint
bats tests/unit              # unit tests
bash tests/smoke/run.sh      # smoke tests
bash tests/integration/run.sh 24.04 26.04   # Docker integration tests
```

Before a release, go through the [manual checklist](docs/manual-checklist.md). See [CONTRIBUTING.md](CONTRIBUTING.md) for conventions.

## License

[MIT](LICENSE)
