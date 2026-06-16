# agentyard

**One-shot host setup for AI-agent-driven development — WSL2 / Linux (Ubuntu/Debian-based) / macOS, Dev Container or direct host use**

[![Lint](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/lint.yaml)
[![Unit](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-unit.yaml)
[![Smoke](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-smoke.yaml)
[![Integration](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml/badge.svg)](https://github.com/ozzy-labs/agentyard/actions/workflows/test-integration.yaml)
[![License: MIT](https://img.shields.io/github/license/ozzy-labs/agentyard)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/ozzy-labs/agentyard?include_prereleases&label=release)](https://github.com/ozzy-labs/agentyard/releases/latest)

**English | [日本語](README.ja.md)**

A comprehensive collection of shell scripts that bootstraps a development host (WSL2, Linux (Ubuntu/Debian-based), or macOS) with everything needed for modern, AI-agent-driven development. Works equally well whether you develop **inside Dev Containers** (recommended) or **directly on the host**. Ships AI agent CLIs (Claude Code / Codex / Copilot / Gemini) alongside a curated set of AI power tools (markitdown, ast-grep, yq, OCR/audio backends) so agents can read documents, search code, and operate on structured data out of the box.

> **Why Bash + `curl | bash`?** This project consciously stays a single shell script with zero runtime dependencies — no Node.js, no npm, no compiled binary. Setup tools that *install* runtimes shouldn't *require* a runtime. The trade-off (no rich TUI) buys a strong asset: a one-line install that works on a fresh machine the day you provision it. See [ADR-0004](./docs/adr/ADR-0004-stay-bash-and-publish-readiness.md) for the full rationale.

## Table of Contents

- [1. Repository Background](#1-repository-background)
- [2. Repository Structure](#2-repository-structure)
- [3. Features](#3-features)
- [4. Quick Start](#4-quick-start)
- [5. Prerequisites](#5-prerequisites)
- [6. Scripts](#6-scripts)
  - [6.1 setup-zsh-linux.sh](#61-setup-zsh-linuxsh)
  - [6.2 setup-local-linux.sh](#62-setup-local-linuxsh)
  - [6.3 setup-local-macos.sh](#63-setup-local-macossh)
  - [6.4 update-tools.sh](#64-update-toolssh)
  - [6.5 doctor.sh](#65-doctorsh)
- [7. Troubleshooting](#7-troubleshooting)
- [8. Contributing](#8-contributing)
- [9. Changelog](#9-changelog)

## 1. Repository Background

- Provides a single source of truth for development-host provisioning (WSL2, Linux (Ubuntu/Debian-based), macOS) that works for **both Dev Container and direct-host workflows**.
- **AI-first**: AI agent CLIs and AI power tools (document conversion, OCR, structural code search, YAML/audio processing) are promoted to first-class install categories.
- Standardized on **mise** as the unified runtime/CLI version manager, with **uv** handling Python packages and **Corepack-compatible pnpm** for Node.
- Emphasizes idempotent execution, detailed diagnostics, and actively maintained 2026-era defaults.
- Versioned independently from application repositories so host requirements can evolve quickly.

## 2. Repository Structure

```
agentyard/
├── install.sh                      # OS-aware dispatcher (Linux → linux, Darwin → macos)
├── README.md
├── README.ja.md
└── scripts/
    ├── setup-local-linux.sh        # Linux (Ubuntu/Debian-based) full provisioning
    ├── setup-local-macos.sh        # macOS (mise-first, lightweight)
    ├── setup-zsh-linux.sh          # zsh + oh-my-zsh on Linux (Ubuntu/Debian-based)
    └── update-tools.sh             # Cross-OS batch update
```

## 3. Features

- 🤖 **AI Agent CLIs** - Claude Code, Codex CLI, GitHub Copilot CLI, Gemini CLI (choose individually)
- 🧠 **AI Power Tools** - markitdown (PDF/Office → Markdown), tesseract-ocr (+jpn), ffmpeg, ast-grep (structural code search), yq
- 🐳 **Container / Sandbox Foundation** - Docker Engine + Docker Compose (essential for Dev Containers) + bubblewrap
- ⚡ **Unified Version Manager** - mise manages Node.js LTS / pnpm / Python / uv / gitleaks / shellcheck / ast-grep / yq (opt-in: Bun for Bun-native tooling)
- 🐍 **Python Ecosystem** - mise-managed Python + uv for packages/venvs/CLI tools
- ☁️ **Cloud CLIs** - AWS CLI v2 (default) / Azure CLI, Google Cloud CLI (opt-in)
- 🔒 **Modern Secret / Vulnerability Scanning** - gitleaks (2026 de-facto secret scanner) + trivy (filesystem vuln scanner, used by this repo's lefthook pre-commit); pair with lefthook per project
- 🎨 **Shell Experience** - zsh + oh-my-zsh + plugins (Linux), fzf / ripgrep / fd / jq / tree (opt-in: tmux / zellij multiplexer)
- 🔄 **One-shot Upgrades** - `install.sh update` batch-refreshes mise/uv/npm-managed tools
- 🐧 **Linux (Ubuntu/Debian-based) LTS Coverage** - CI-verified on 22.04 + 24.04; canary-tested on **26.04 Resolute Raccoon** (next LTS) so the toolchain continues to work the day 26.04 lands on WSL2
- 🍎 **macOS Coverage** - Native `setup-local-macos.sh` keeps the same mise-first flow; canary-verified weekly on `macos-latest`
- 🖥️ **Non-WSL Linux Coverage** - Bare-metal install verified weekly on `ubuntu-latest` (Ubuntu Server, EC2, GCE, etc.)
- ✅ **Idempotency** - Safe to run multiple times
- 📝 **Detailed Logging** - Optional log output for troubleshooting
- 🛠️ **Unified Error Handling** - Clear error messages with actionable solutions

## 4. Quick Start

> **Recommended invocation** uses explicit TLS pinning (`--proto '=https' --tlsv1.2`) so the install pipeline rejects any redirect to plain HTTP and any TLS version below 1.2. This is the same pattern used by `rustup` and `mise`.

```bash
# 1. Set up zsh (recommended first)
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- zsh

# 2. Restart your terminal
exit
# Open a new terminal

# 3. Set up development tools (mise, languages, Docker, AI CLIs, AI power tools, ...)
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- local

# 4. Complete required authentications (for what you installed)
aws configure      # or: aws configure sso
gh auth login
claude auth login
codex auth login
copilot             # authenticate with /login on first launch
gemini              # authenticate with Google account on first launch

# 5. Later: upgrade every mise / uv / npm managed tool in one shot
./install.sh update

# 6. Verify environment health any time
./install.sh doctor
```

### 4.1 Inspect-before-run (recommended for production hosts)

If you prefer to read the script before running it, download first and review:

```bash
# Download to a temp file
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh \
  -o /tmp/agentyard-install.sh

# Review the contents
less /tmp/agentyard-install.sh

# Run it
bash /tmp/agentyard-install.sh local
```

### 4.2 Verify a release with SHA256

For pinned, reproducible installs, use a tagged release. Each GitHub Release ships `install.sh` and `install.sh.sha256`:

```bash
# Pin to a specific release (replace v0.3.0 with the latest tag)
TAG=v0.3.0
BASE="https://github.com/ozzy-labs/agentyard/releases/download/${TAG}"

# Download both the script and its checksum
curl --proto '=https' --tlsv1.2 -fsSL "${BASE}/install.sh" -o install.sh
curl --proto '=https' --tlsv1.2 -fsSL "${BASE}/install.sh.sha256" -o install.sh.sha256

# Verify (must print "install.sh: OK")
sha256sum -c install.sh.sha256

# Run only after verification succeeds
bash install.sh local
```

### 4.3 Clone-and-run (for contributors / forkers)

```bash
git clone https://github.com/ozzy-labs/agentyard.git
cd agentyard
./install.sh zsh
./install.sh local
```

### 4.4 Environment variables / CLI options

#### CLI options for `install.sh`

| Argument | Description |
|---|---|
| `zsh` \| `local` \| `all` \| `update` \| `doctor` | Subcommand (default `all`). See [§6](#6-scripts) for what each runs. |
| `--ref <git-ref>` | Branch / tag / commit to download when running remotely (default `main`) |
| `-y`, `--auto` | Apply recommended defaults without prompts (sets `AGENTYARD_ASSUME_YES=1`) |
| `--interactive` | Force interactive prompts (sets `AGENTYARD_ASSUME_YES=0`) — useful to override `CI=true` |
| `-h`, `--help` | Show usage |

#### Top-level environment variables

| Variable | Default | Effect |
|---|---|---|
| `AGENTYARD_REF` | `main` | Default git ref to download when running through `curl \| bash`. Legacy aliases `AGENTIC_BOOTSTRAP_REF`, `BOOTSTRAP_REF` are still honored as fallbacks. |
| `AGENTYARD_ASSUME_YES` | `0` | `1` = non-interactive, auto-accept "default Y" prompts and skip "default N" prompts. Legacy aliases `AGENTIC_BOOTSTRAP_ASSUME_YES`, `BOOTSTRAP_ASSUME_YES` are honored. `CI=true` also forces this on. |
| `SETUP_LOG` | unset | When set, tees all setup / update output into a log file. `1` or `true` uses the default path (`~/setup-local-<os>-YYYYMMDD-HHMMSS.log`); any other value is treated as a custom path. |

#### `INSTALL_*` category flags (Linux: `setup-local-linux.sh`)

Each flag accepts `1` (install) or `0` (skip). Defaults shown match `scripts/setup-local-linux.sh`. Interactive mode prompts for each category; `AGENTYARD_ASSUME_YES=1` uses these defaults.

| Variable | Default | Category |
|---|---|---|
| `INSTALL_BUILD_TOOLS` | `1` | build-essential |
| `INSTALL_BASIC_CLI` | `1` | tree, fzf, jq, ripgrep, fd, unzip |
| `INSTALL_GIT_TOOLS` | `1` | Git, GitHub CLI, gitleaks |
| `INSTALL_NODE` | `1` | mise + Node.js LTS + pnpm |
| `INSTALL_PYTHON` | `1` | mise + Python + uv |
| `INSTALL_BUN` | `0` | Bun (mise, opt-in) — JS runtime / package manager / bundler |
| `INSTALL_CONTAINER` | `1` | Docker Engine, Docker Compose, bubblewrap |
| `INSTALL_AWS_CLI` | `1` | AWS CLI v2 |
| `INSTALL_AZURE_CLI` | `0` | Azure CLI (opt-in) |
| `INSTALL_GCLOUD_CLI` | `0` | Google Cloud CLI (opt-in) |
| `INSTALL_CLAUDE_CODE` | `1` | Claude Code |
| `INSTALL_CODEX_CLI` | `1` | Codex CLI |
| `INSTALL_COPILOT_CLI` | `1` | GitHub Copilot CLI |
| `INSTALL_GEMINI_CLI` | `1` | Gemini CLI |
| `INSTALL_AI_POWER_TOOLS` | `1` | markitdown, tesseract-ocr(+jpn), ffmpeg, ast-grep, yq |
| `INSTALL_TMUX` | `0` | tmux (apt, opt-in) |
| `INSTALL_ZELLIJ` | `0` | Zellij (mise, opt-in) |
| `INSTALL_DEV_TOOLS` | `1` | just, zoxide, shellcheck, chezmoi |

#### `INSTALL_*` category flags (macOS: `setup-local-macos.sh`)

macOS is intentionally lighter — Docker Desktop / AI agent CLIs / cloud CLIs are not auto-installed (see §6.3.2).

| Variable | Default | Category |
|---|---|---|
| `INSTALL_MISE_LANGUAGES` | `1` | mise + Node.js LTS + pnpm + Python + uv |
| `INSTALL_GIT_TOOLS` | `1` | gitleaks (via mise) |
| `INSTALL_AI_POWER_TOOLS` | `1` | ast-grep, yq, markitdown |
| `INSTALL_DEV_TOOLS` | `1` | just, zoxide, shellcheck, chezmoi |
| `INSTALL_TMUX` | `0` | macOS prints a notice only — install via `brew install tmux` |
| `INSTALL_ZELLIJ` | `0` | Zellij (via mise, opt-in) |
| `INSTALL_BUN` | `0` | Bun (via mise, opt-in) — JS runtime / package manager / bundler |

Example — non-interactive Linux install with Azure CLI added and AI agent CLIs skipped:

```bash
AGENTYARD_ASSUME_YES=1 \
INSTALL_AZURE_CLI=1 \
INSTALL_CLAUDE_CODE=0 INSTALL_CODEX_CLI=0 INSTALL_COPILOT_CLI=0 INSTALL_GEMINI_CLI=0 \
SETUP_LOG=1 \
./install.sh local
```

## 5. Prerequisites

These scripts are designed to set up a **development host** across multiple operating systems, and support both workflows below.

### 5.1 Supported operating systems

| OS / Distribution | Script | Status |
|---|---|---|
| **Linux (Ubuntu 22.04 LTS)** | `setup-local-linux.sh` | ✅ CI-verified every PR / main push |
| **Linux (Ubuntu 24.04 LTS)** | `setup-local-linux.sh` | ✅ CI-verified every PR / main push |
| **Linux (Ubuntu Server etc.)** | `setup-local-linux.sh` | ✅ Canary-verified weekly on `ubuntu-latest` (bare-metal install, no Docker) |
| **macOS (latest)** | `setup-local-macos.sh` | ✅ Canary-verified weekly on `macos-latest` (mise-first lightweight flow) |
| **Linux (Ubuntu 25.10)** | `setup-local-linux.sh` | ✅ Canary-verified weekly via `ubuntu:rolling` Docker tag |
| **Linux (Ubuntu 26.04 LTS)** | `setup-local-linux.sh` | ✅ Canary-verified weekly via `ubuntu:devel` — ready for the next LTS the day it lands |

`install.sh` auto-detects the OS and dispatches `local` to the matching script (`setup-local-linux.sh` for Linux, `setup-local-macos.sh` for Darwin). The weekly canary runs the full integration harness against `ubuntu:devel` / `ubuntu:rolling` Docker tags, the bare `ubuntu-latest` runner (non-WSL Linux), and `macos-latest`, so upstream breaking changes are caught early on every supported platform.

### 5.2 Dev Container workflow (recommended)

- Host carries the bare minimum: Docker, mise, git, AI CLIs, AI power tools
- Project-specific runtimes, linters, and formatters live inside each `.devcontainer/`
- Matches the common team workflow where every project defines its own dev container

### 5.3 Direct-host workflow

- Host also installs Node.js LTS, pnpm, Python, uv via mise so you can develop directly on WSL2 / non-WSL Linux / macOS
- Per-project tools are managed via the project's own `.mise.toml`
- Great for small projects, scratch work, or when a dev container feels like overkill

Both workflows share the same foundation (`mise` + `uv` + Docker) so you can move between them without re-provisioning the host.

## 6. Scripts

### 6.1 setup-zsh-linux.sh

Sets up zsh + oh-my-zsh + plugins on Ubuntu/Debian (WSL2 + non-WSL Linux). On macOS this step is skipped — `install.sh zsh` prints a notice and exits cleanly because macOS already ships with zsh as the default shell.

You can run it either through `install.sh` or directly via `scripts/setup-zsh-linux.sh`.

**6.1.1 What Gets Installed**

- **curl** - Required for oh-my-zsh installation
- **git** - Required for plugin installation
- **zsh** - Shell itself
- **oh-my-zsh** - zsh framework
- **zsh-completions** - Additional completion definitions
- **zsh-autosuggestions** - Command auto-completion
- **zsh-history-substring-search** - Enhanced history search
- **zsh-syntax-highlighting** - Command syntax highlighting
- Automatic `.zshrc` plugins configuration
- Interactive plugin selection (install all or choose individually)

**6.1.2 Key Features**

- ✅ **Idempotency** - Safe to run multiple times
  - Robust plugin detection (handles existing `plugins=(git docker)` etc.)
  - Adds new plugins while preserving existing ones
- ✅ **Environment Check** - Only runs on Ubuntu/Debian systems
- ✅ **Automatic Dependency Resolution** - Pre-installs curl and git
- ✅ **Automatic Configuration** - Automatically updates .zshrc plugin settings
  - Supports various plugin configurations (handles different space-separated variations)
- ✅ **Default Shell Change** - Sets zsh as default shell (provides fallback instructions on failure)
- ✅ **Error Handling** - Error checking for all critical operations
- ✅ **Logging Feature** - Optional log output for troubleshooting
- ✅ **Detailed Comments** - Explanatory comments for complex processes

**6.1.3 Usage**

```bash
# Via install.sh (recommended for first-time setup)
curl -fsSL https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- zsh

# Basic execution from a cloned repository
./install.sh zsh

# Direct script execution
./scripts/setup-zsh-linux.sh

# With logging
SETUP_LOG=1 ./install.sh zsh

# Specify custom log file path
SETUP_LOG=/path/to/setup.log ./install.sh zsh

# Restart shell (activates zsh)
exec zsh
```

**6.1.4 Post-Setup Verification**

```bash
# Check if zsh is running
echo $SHELL

# Check oh-my-zsh version
omz version

# Verify plugins are enabled
echo $plugins
```

**6.1.5 Notes**

- For Ubuntu/Debian environments (WSL2 or non-WSL Linux) **outside** Dev Container
- On macOS the script is skipped automatically (see note above)
- Inside Dev Container, it's automatically set up via Dockerfile
- Safe to run multiple times (idempotent)
- If default shell change fails, manual setup instructions will be displayed

---

### 6.2 setup-local-linux.sh

Comprehensive setup script that installs required development tools on Ubuntu/Debian (WSL2 + non-WSL Linux such as Ubuntu Server, EC2, GCE, container-based VMs, etc.). WSL-specific bits (`wslu`, `BROWSER=wslview`) are intentionally **not** automated — see the inline notes in the script for the manual one-liner.

You can run it either through `install.sh` or directly via `scripts/setup-local-linux.sh`.

**6.2.1 Installed Tools**

1. **System Configuration**
   - **Locale/Timezone** - Automatically sets ja_JP.UTF-8 and Asia/Tokyo
   - **Dev Container mount directories** - `~/.aws`, `~/.claude`, `~/.gemini`, `~/.config/gh`, `~/.local/share/pnpm`, etc.
2. **Basic CLI Tools**
   - **build-essential** - C/C++ compilers and build tools
   - **tree** - Directory structure visualization
   - **fzf** - Fuzzy finder (Ctrl+R for history search)
   - **jq** - JSON processing
   - **ripgrep** - Fast text search tool
   - **fd-find** - Fast and user-friendly alternative to find
   - **unzip** - Archive extraction (required for AWS CLI)
   - WSL2-only `wslu` / `BROWSER=wslview` are **not** automated; see inline notes in the script for the manual one-liner.
3. **Version Manager (foundation)**
   - **mise** - Unified manager for runtimes and CLI tools (replaces Volta, supersedes per-tool installers)
4. **Node.js Ecosystem (via mise)**
   - **Node.js LTS** - JavaScript runtime
   - **pnpm** - Fast package manager
   - **Bun** (via mise, opt-in) - All-in-one JS runtime / package manager / bundler (set `INSTALL_BUN=1` or select interactively). Needed for Bun-native tools such as MCP servers that use `bun:sqlite` and won't run on Node/`npx`. An *additional* choice, not a replacement for Node + pnpm; pinned to the `bun@1` major (mise core backend, same range policy as Node/Python). Genuinely opt-in: it is intentionally **not** listed in the global mise config template, so default hosts stay Bun-free.
5. **Python Ecosystem (via mise)**
   - **Python** - Latest stable via mise
   - **uv** - Packaging, virtualenvs, and CLI tool installer
6. **Version Control Tools**
   - **Git** - Version control system
   - **GitHub CLI** - GitHub operations
   - **gitleaks** (via mise) - Modern secret scanner; wire into project-level lefthook / pre-commit hooks
   - **Git basic config** - user.name, user.email, core.editor, etc.
7. **Container / Sandbox Tools**
   - **bubblewrap** - Lightweight unprivileged sandboxing primitive used by modern CLI / desktop tooling
   - **Docker Engine** - Container runtime
   - **Docker Compose** - Multi-container management tool (essential for Dev Containers)
   - **Docker service auto-start** - Service startup on WSL2
8. **Cloud Tools**
   - **AWS CLI v2** - AWS resource operations (default-on)
   - **Azure CLI** - Microsoft Azure resource operations (opt-in)
   - **Google Cloud CLI** - Google Cloud Platform resource operations (opt-in)
9. **Terminal Multiplexer** (opt-in)
   - **tmux** (via apt) - Classic terminal multiplexer (Linux only, opt-in; set `INSTALL_TMUX=1` or select interactively). A sensible `~/.tmux.conf` (truecolor, mouse, 50k scrollback, 1-based indexing, `prefix r` reload bind) is shipped only when no existing config is present
   - **Zellij** (via mise) - Modern terminal multiplexer (opt-in; set `INSTALL_ZELLIJ=1` or select interactively)
10. **AI Agent CLIs** (choose individually)
    - **Claude Code** - Interactive development tool with Claude AI
    - **Codex CLI** - OpenAI Codex CLI (code generation AI)
    - **GitHub Copilot CLI** - GitHub Copilot coding agent for the terminal
    - **Gemini CLI** - Google Gemini AI agent for the terminal
    - Multi-agent support: shared skills in `.agents/skills/` (Agent Skills standard), `AGENTS.md` as common entry point, Claude Code overlays in `.claude/skills/`
11. **AI Power Tools** (boost agent capabilities)
    - **markitdown[all]** (via uv tool) - Converts PDF / Word / Excel / PowerPoint / images / audio into Markdown
    - **tesseract-ocr** + **tesseract-ocr-jpn** (apt) - OCR backend that enables markitdown to read scanned PDFs and images
    - **ffmpeg** (apt) - Audio/video backend for markitdown transcription and video frame extraction
    - **ast-grep** (via mise) - Structural (AST-based) code search and refactor
    - **yq** (via mise) - YAML query tool; the YAML counterpart of jq
12. **Development Utilities**
    - **just** - Task runner
    - **zoxide** - Smarter cd command with directory jumping
    - **shellcheck** (via mise) - Shell script static analysis (useful for AI-generated scripts too)
    - **chezmoi** (via mise) - Dotfile manager that applies the repo's `dotfiles/` templates to `$HOME` (see ADR-0003)
    - **trivy** (via mise + dotfiles template) - Filesystem vulnerability scanner; wired into this repo's lefthook pre-commit hook (`mise exec -- trivy fs --scanners vuln`)

**6.2.2 Key Features**

- ✅ **Interactive Tool Selection** - Choose which tools to install (install all or select individually)
- ✅ **Idempotency** - Safe to run multiple times
- ✅ **Environment Check** - Only runs on Ubuntu/Debian systems
- ✅ **Unified Error Handling** - Error checking for all critical operations
  - Unified format (cause analysis + solution + manual commands)
  - Easy troubleshooting
- ✅ **Detailed Error Messages** - Provides troubleshooting hints
- ✅ **Input Validation** - Git email address format checking
- ✅ **Logging Feature** - Optional log output for troubleshooting
- ✅ **DRY Principle** - Minimizes code duplication
  - Consistent use of `add_to_shell_config` function
  - Unified shell configuration management
- ✅ **Interactive Configuration** - Interactive Git username/email setup
- ✅ **Security Features** - Automates git-secrets global configuration
- ✅ **Detailed Summary Display** - Easy verification of installation results
- ✅ **Clear Variable Management** - Explicit initialization and scope management of global variables
- ✅ **Detailed Comments** - Explanatory comments for complex processes (pipelines, regex, etc.)

**6.2.3 Usage**

```bash
# Via install.sh (recommended for first-time setup)
curl -fsSL https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh | bash -s -- local

# Basic execution from a cloned repository
./install.sh local

# Direct script execution
./scripts/setup-local-linux.sh

# With logging (default path: ~/setup-local-linux-YYYYMMDD-HHMMSS.log)
SETUP_LOG=1 ./install.sh local

# Specify custom log file path
SETUP_LOG=/var/log/setup.log ./install.sh local

# Completely close and re-login to terminal
# (exec is not sufficient to ensure PATH is applied)
exit
```

**6.2.4 Recommended Post-Setup Steps**

1. **Configure AWS credentials**:

   ```bash
   aws configure      # For IAM user
   aws configure sso  # For SSO
   ```

2. **GitHub authentication**:

   ```bash
   gh auth login
   ```

3. **AI tool authentication**:

   ```bash
   claude auth login   # Claude Code
   codex auth login    # Codex CLI
   copilot             # GitHub Copilot CLI (authenticate with /login on first launch)
   gemini              # Gemini CLI (authenticate with Google account on first launch)
   ```

4. **Verify tool installation**:

   ```bash
   # Version manager + runtimes
   mise --version
   node --version
   pnpm --version
   python3 --version
   uv --version

   # Git / cloud / AI
   gh --version
   gitleaks version
   aws --version
   claude --version
   codex --version
   copilot --version
   gemini --version

   # AI power tools
   markitdown --version
   tesseract --version
   ffmpeg -version | head -n1
   ast-grep --version
   yq --version

   # Container + dev utilities
   bwrap --version
   docker --version
   docker compose version
   just --version
   shellcheck --version | head -n2
   ```

5. **Batch-update every installed tool**:

   ```bash
   ./install.sh update           # normal run
   ./scripts/update-tools.sh -n  # dry-run to preview which tools will be upgraded
   ```

**6.2.5 Git Configuration**

The following settings are configured interactively during script execution:

- `user.name` - Git username (default: current username)
- `user.email` - Git email address (with format validation)
- `core.editor` - Default editor (vim)
- `init.defaultBranch` - Default branch (main)
- `core.autocrlf` - Line ending configuration (input)
- `core.fileMode` - Track execution permissions (true)
- `pull.rebase` - Pull merge strategy (false; merge commit on `git pull`)

**6.2.6 Error Handling**

All critical operations include error checking with detailed information in a unified format:

**Unified Error Message Format**:

```
⚠️  Error message
ℹ️  Possible causes:
    - Cause 1
    - Cause 2
ℹ️  Solutions:
    1. Step 1
    2. Step 2
ℹ️  Manual verification/execution: command
```

**Example 1: apt update failure**

```bash
⚠️  システムパッケージの更新に失敗しました
ℹ️  考えられる原因:
    - ネットワーク接続の問題
    - パッケージリポジトリの障害
    - /etc/apt/sources.list の設定ミス
ℹ️  手動で確認: sudo apt update
```

**Example 2: mise not found / shim resolution fails**

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

**Example 3: Docker service startup failure**

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

**6.2.7 Log Files**

Setting the `SETUP_LOG` environment variable records all output to a log file:

```bash
# Record to default path (~/setup-local-linux-YYYYMMDD-HHMMSS.log)
SETUP_LOG=1 ./install.sh local

# Record to custom path
SETUP_LOG=/tmp/setup.log ./install.sh local
```

Logs include:

- All output messages
- Error messages
- User input (Git configuration, etc.)
- Installation results

**6.2.8 Notes**

- For Ubuntu/Debian environments (WSL2 or non-WSL Linux) **outside** Dev Container
- Inside Dev Container, necessary tools are already installed
- Safe to run multiple times (idempotent)
- On non-Ubuntu/Debian systems, a warning is displayed and confirmation is requested
- If Git username/email is not set, interactive configuration is prompted
- Whitespace-only input and invalid email addresses are validated
- WSL2-only utilities (`wslu`, `BROWSER=wslview`) are not installed automatically — see inline notes in the script

---

### 6.3 setup-local-macos.sh

macOS counterpart to `setup-local-linux.sh`, intentionally lighter-weight: focuses on **mise as the entry point** for runtime/CLI provisioning, and defers OS-integration (Docker Desktop, AI agent CLIs requiring interactive auth, cloud CLIs) to manual install.

**6.3.1 What Gets Installed**

- **mise** — installed via `curl -fsSL https://mise.run | sh` (same canonical path as Linux)
- **Node.js LTS / pnpm / Python / uv** (via `mise use -g`)
- **gitleaks** (via mise) — modern secret scanner
- **trivy** (via mise + dotfiles template) — filesystem vulnerability scanner (used by lefthook pre-commit; same `github:aquasecurity/trivy` pin as Linux)
- **ast-grep / yq** (via mise) — AI power tools
- **markitdown[all]** (via `uv tool install`)
- **just / zoxide / shellcheck / chezmoi** (via mise) — dev helpers (chezmoi applies `dotfiles/` templates per ADR-0003)
- **zellij** (via mise) — terminal multiplexer (opt-in; set `INSTALL_ZELLIJ=1`)
- **Bun** (via mise) — JS runtime / package manager / bundler (opt-in; set `INSTALL_BUN=1`). Registered after the chezmoi apply since it is intentionally not in the global mise config template (see ADR-0002)

**6.3.2 What Is NOT Installed (manual on macOS)**

- **Docker Desktop** — license + interactive installer required; install from <https://www.docker.com/products/docker-desktop>
- **AI agent CLIs** (Claude Code / Codex / Copilot / Gemini) — interactive authentication; install per the vendor docs
- **Cloud CLIs** (`aws`, `az`, `gcloud`) — `brew install awscli azure-cli google-cloud-sdk` recommended
- **tmux** — manual install via `brew install tmux` if desired (mise-first policy on macOS; setting `INSTALL_TMUX=1` only prints a notice and does not invoke brew)

**6.3.3 Usage**

```bash
# Auto-dispatched by install.sh on Darwin
./install.sh local

# Direct invocation
./scripts/setup-local-macos.sh

# Non-interactive (CI / scripted)
AGENTYARD_ASSUME_YES=1 ./scripts/setup-local-macos.sh
```

**6.3.4 Notes**

- Idempotent — safe to re-run; mise handles the heavy lifting
- Adds `mise activate` to `~/.zshrc`, `~/.bash_profile`, and `~/.bashrc`
- Verified weekly on `macos-latest` via the canary workflow

---

### 6.4 update-tools.sh

A single entry point that refreshes every tool installed by the setup script, across all install backends.

**6.4.1 Update Coverage**

| Backend | Tools updated |
|---|---|
| **mise** | `mise self-update` + `mise upgrade` + `mise reshim` (covers gitleaks / trivy / ast-grep / yq / chezmoi / just / shellcheck etc.) |
| **uv tool** | `uv tool upgrade --all` (e.g. markitdown) |
| **npm global** | `@openai/codex`, `@google/gemini-cli` |
| **Native installer** | `claude update`, `copilot update` (timeout-guarded) |

**6.4.2 Usage**

```bash
# Batch-update via install.sh (works locally and through curl|bash)
./install.sh update

# Run the script directly
./scripts/update-tools.sh

# Dry-run to preview which tools will be upgraded
./scripts/update-tools.sh --dry-run

# Log to a file
SETUP_LOG=1 ./install.sh update
SETUP_LOG=/tmp/update.log ./install.sh update
```

**6.4.3 Behavior**

- Idempotent — missing tools are skipped with an `⏭️` marker
- Resilient — a single command failure emits a warning but does not abort the run
- Log-friendly — honors the same `SETUP_LOG` convention as `setup-local-linux.sh`
- Cross-OS — works equally on Linux (WSL2 / non-WSL) and macOS

---

### 6.5 doctor.sh

Diagnoses the integrity of an existing bootstrapped environment without making any changes. Useful when something feels off after a system update, or before debugging a new project setup.

**6.5.1 What It Checks**

- **System tools** — `curl`, `git`, `unzip`, `xz`, `tar` are present
- **mise** — binary exists at `~/.local/bin/mise`, PATH wiring includes `~/.local/bin` and the mise shims directory
- **mise-managed tools** — `node`, `pnpm`, `python`, `uv` are under mise's global config
- **chezmoi drift** — runs `chezmoi diff` against the repository's `dotfiles/` to detect divergence
- **`~/.zshrc.d/`** — directory exists and is sourced from `~/.zshrc`

**6.5.2 Exit Codes**

| Code | Meaning |
|---|---|
| `0` | Healthy (no warnings, no errors) |
| `1` | Warnings only (recommended tools missing, drift detected) |
| `2` | Errors (required system tools missing) |

This makes it useful in CI / health-check pipelines — `./install.sh doctor || echo "needs attention"` exits non-zero only when there's a real problem.

**6.5.3 Usage**

```bash
# Via install.sh dispatcher
./install.sh doctor

# Direct script execution
./scripts/doctor.sh
```

Each non-`✅` finding is paired with a copy-paste-ready fix hint. The Doctor never executes fixes itself — it tells you what to run, and you decide.

**6.5.4 Sample Output**

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

## 7. Troubleshooting

### 7.1 Common Issues

**7.1.1 apt update fails**

```bash
# Error message example
⚠️  Failed to update system packages

# Solution
1. Check network connection
2. Run sudo apt update manually to see detailed errors
3. Validate /etc/apt/sources.list configuration
```

**7.1.2 mise / uv / node not found after install**

```bash
# Error message example
⚠️  mise のインストールに失敗しました
ℹ️  Possible causes:
    - mise install did not finish successfully
    - PATH has not been refreshed after installation
    - You are running from a shell that has not yet sourced .zshrc / .bashrc
ℹ️  Solutions:
    1. Completely close the terminal (exit) and reopen
    2. Rerun this script
ℹ️  Manual verification: ~/.local/bin/mise --version

# Additional verification steps
1. Close terminal and reopen
2. Check PATH via: echo $PATH
3. Confirm mise installation: ls -la ~/.local/bin/mise
4. Run: eval "$(~/.local/bin/mise activate bash)"
```

**7.1.3 Docker won't start**

```bash
# Error message example
⚠️  Failed to start Docker service
ℹ️  Possible causes:
    - Docker installation incomplete
    - Service manager issues
    - Kernel modules not loaded
ℹ️  Solutions:
    1. Check installation state: dpkg -l | grep docker
    2. Inspect service status: sudo service docker status
ℹ️  Manual start: sudo service docker start

# Additional verification steps
sudo service docker status  # Check status
sudo service docker start   # Manual start
sudo docker run hello-world # Verify operation
```

**7.1.4 Docker Compose not found**

```bash
# Error message example
⚠️  Failed to install Docker Compose
ℹ️  Possible causes:
    - docker-compose-plugin not available in repository
    - Docker Engine installation incomplete
ℹ️  Solutions:
    1. Check Docker packages: dpkg -l | grep docker
    2. Install manually: sudo apt-get install -y docker-compose-plugin
ℹ️  Manual verification: docker compose version

# Additional verification steps
docker compose version
dpkg -l | grep docker-compose
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

**7.1.5 Invalid Git email address**

```bash
# Error message example
⚠️  Invalid email format

# Solution
Enter valid format: user@example.com
Or configure later: git config --global user.email "you@example.com"
```

**7.1.6 Existing `~/.tmux.conf` is not overwritten**

```bash
# Behavior
When INSTALL_TMUX=1 is set, the install script writes a sensible
~/.tmux.conf ONLY if the file does not already exist. If you already
have ~/.tmux.conf, the script skips it with:

  ⏭️  ~/.tmux.conf は既に存在（上書きしません）

# If you want the shipped defaults
mv ~/.tmux.conf ~/.tmux.conf.bak
INSTALL_TMUX=1 ./install.sh local

# What ships in the bundled config
- truecolor + 256color (tmux-256color terminfo)
- mouse on, 50k scrollback
- 1-based window / pane indexing with renumber-windows
- `prefix r` to reload ~/.tmux.conf
- Default prefix (C-b) kept; no vi/emacs mode-keys; no plugin manager
```

**7.1.7 `curl ... | bash` aborts with "TTY を確保できませんでした"**

Some environments (notably certain WSL2 configurations, containers without a controlling terminal, or nested subshells) cannot reach `/dev/tty` from the bash subshell spawned by `curl ... | bash`. In these cases, the install script can no longer show interactive prompts, so it now aborts with a clear error rather than silently proceeding with default values for hidden prompts.

```bash
# Error message example
⚠️  対話プロンプト用の TTY を確保できませんでした
ℹ️  考えられる原因:
    - stdin が pipe で、/dev/tty へのフォールバックも失敗した
    - curl ... | bash 実行時に /dev/tty が利用不可（WSL2 の一部環境 / コンテナ / サブシェル）
ℹ️  対処法:
    1. ファイル経由で実行する（推奨）: ...
    2. プロセス置換で実行する: ...
    3. 非対話モードで実行する: ...
```

Pick one of the following workarounds:

```bash
# (a) File-based execution — most reliable, also lets you inspect the script first
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh \
  -o /tmp/install.sh
bash /tmp/install.sh local

# (b) Process substitution — keeps the one-liner shape while restoring a real TTY for stdin
bash <(curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh) local

# (c) Non-interactive mode — accept all defaults (install every category)
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/ozzy-labs/agentyard/main/install.sh \
  | AGENTYARD_ASSUME_YES=1 bash -s -- local
```

### 7.2 Checking Logs

```bash
# When executed with logging enabled
SETUP_LOG=1 ./install.sh local

# Log file path will be shown, e.g.:
ℹ️  Logs stored at /home/user/setup-local-linux-20250109-123456.log

# View log
cat /home/user/setup-local-linux-20250109-123456.log
```

---

## 8. Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

For detailed review process, see:

- [Review Process Guide](docs/review-process.md)
- [Review Checklist](docs/review-checklist.md)

---

## 9. Changelog

The changelog is auto-managed in [CHANGELOG.md](CHANGELOG.md) by [release-please](https://github.com/googleapis/release-please) from Conventional Commits. Per-release details are published on [GitHub Releases](https://github.com/ozzy-labs/agentyard/releases).
