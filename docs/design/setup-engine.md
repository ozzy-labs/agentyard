# セットアップ・エンジン 設計書

> **注記（2026-11-04）**: 本文書は v0.4.x の設計です。v0.5.0 以降の設計は [ADR-0007](../adr/ADR-0007-host-first-redesign.md) を参照してください。

## 概要

セットアップ・エンジンは、OzzyLabs の推奨開発環境を「ワンコマンド」で構築するためのシステムです。
ホスト環境の初期設定から、ランタイムの導入、ドットファイルの適用までを一貫して行います。

## アーキテクチャ図

```mermaid
graph TD
    User([User]) -->|curl | bash| InstallSH[install.sh]
    
    subgraph "Phase 1: Dispatch"
        InstallSH -->|Detect OS| LinuxSetup[setup-local-linux.sh]
        InstallSH -->|Detect OS| MacOSSetup[setup-local-macos.sh]
    end
    
    subgraph "Phase 2: Bootstrap Tools"
        LinuxSetup --> Mise[mise install]
        MacOSSetup --> Mise
    end
    
    subgraph "Phase 3: Install Runtimes & CLIs"
        Mise --> Node[Node.js / pnpm]
        Mise --> Python[Python / uv]
        Mise --> AI[AI Agents: Claude, Gemini, etc.]
    end
    
    subgraph "Phase 4: Apply Config"
        Mise --> Chezmoi[chezmoi apply]
        Chezmoi --> Dotfiles[(dotfiles)]
    end
    
    subgraph "Phase 5: Shell Integration"
        LinuxSetup --> ZshD[~/.zshrc.d/ setup]
        MacOSSetup --> ZshD
    end
```

## 主要コンポーネント

### 1. install.sh (Bootstrap Entrypoint)

- 環境判定、OS 別スクリプトへのディスパッチを行います。
- `--auto` (`-y`) フラグにより、非対話モードでの実行を制御します。

### 2. setup-local-*.sh (OS Specific Engine)

- パッケージマネージャ（apt, brew）を用いた最小限の依存解決。
- `mise` を起点としたツールチェーンの構築。
- シェル設定ファイルの冪等な書き換え。

### 3. chezmoi (Configuration Manager)

- `dotfiles/` ディレクトリに管理されたテンプレートをホスト環境に適用します。
- ユーザーの既存ファイルを安全にバックアップし、OzzyLabs の推奨設定を注入します。

## モード詳細

- **Interactive モード（デフォルト）**: 各ステップでユーザーの確認を求めます。既存の開発機に導入する場合に適しています。
- **Auto モード (`--auto` / `-y`)**: 全てのプロンプトに Yes と答え、最短で環境を構築します。Dev Container や新規 VM での使用を想定しています。
