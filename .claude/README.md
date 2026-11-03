# .claude/ ディレクトリ - Claude Code 設定

このディレクトリには、Claude Code 用の設定ファイルが含まれています。

---

## ファイル構成

```
.claude/
├── settings.json          # プロジェクト共有設定（Git管理）
├── settings.local.json    # 個人設定（.gitignoreで除外）
└── README.md              # このファイル
```

---

## settings.json（プロジェクト共有設定）

### 目的

プロジェクト全体で共有される基本設定です。チーム全員に適用すべきルールや権限設定を定義します。

### Git管理

✅ **Gitで管理**されます（チーム全員で共有）

### 用途

- プロジェクトの基本的な権限設定
- 全員に適用すべきルール
- リポジトリ固有の設定

### 現在の設定内容

```json
{
  "permissions": {
    "allow": [],
    "deny": [],
    "ask": []
  }
}
```

このプロジェクトでは、デフォルトの権限設定を使用しています。必要に応じて、以下のような設定を追加できます：

#### 設定例

**自動承認したい操作**:

```json
{
  "permissions": {
    "allow": [
      "Read(**/*.md)",           // すべてのMarkdownファイルの読み取り
      "Read(scripts/**)",        // スクリプトの読み取り
      "Bash(git status:*)",      // git statusコマンド
      "Bash(tree:*)"             // treeコマンド
    ]
  }
}
```

**禁止したい操作**:

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf:*)",          // 危険な削除コマンド
      "Edit(scripts/**)",        // スクリプトの編集を禁止
      "Write(.gitignore)"        // .gitignoreの書き込みを禁止
    ]
  }
}
```

**確認が必要な操作**:

```json
{
  "permissions": {
    "ask": [
      "Bash(git add:*)",         // git add は確認
      "Bash(git commit:*)",      // git commit は確認
      "Bash(git push:*)",        // git push は確認
      "Edit(README.md)"          // READMEの編集は確認
    ]
  }
}
```

---

## settings.local.json（個人環境設定）

### 目的

個人の環境固有の設定や、チームで共有したくない権限設定を定義します。

### Git管理

❌ **.gitignoreで除外**されます（個人の好み）

### 用途

- 個人的な自動承認設定
- 環境固有の設定
- チームで共有したくない設定

### 作成方法

`settings.local.json` は各開発者が必要に応じて作成します：

```bash
# .claude/ ディレクトリに作成
touch .claude/settings.local.json
```

### 設定例

```json
{
  "permissions": {
    "allow": [
      "Edit(**/*.md)",           // すべてのMarkdownファイルの編集を自動承認
      "Bash(git diff:*)",        // git diff を自動承認
      "Bash(git log:*)"          // git log を自動承認
    ],
    "deny": [
      "Bash(git push --force:*)" // force push を禁止
    ]
  }
}
```

---

## 設定の優先順位

1. **settings.local.json**（最優先）
2. **settings.json**（次点）
3. **グローバル設定**（~/.claude/settings.json）
4. **デフォルト設定**

ローカル設定がプロジェクト設定を上書きします。

---

## Git操作について

**【重要】すべてのGit操作（`git add`, `git commit`, `git push`, `git pull`, `git merge`等）は、ユーザーの明示的な承認が必要です。**

- ✅ 読み取り専用: `git status`, `git log`, `git diff` は承認不要にできる
- ❌ 変更操作: `git add`, `git commit`, `git push` 等は手動承認を推奨

これは `AGENTS.md` と `.claude/rules/git-workflow.md` の Git 操作のルールに従っています。

---

## トラブルシューティング

### Q: 設定が反映されない

A: Claude Codeを再起動してください。

### Q: permissions.allowが効かない

A: パターンマッチングを確認してください。`**`は任意の深さのディレクトリ、`*`は単一レベルを意味します。

### Q: settings.local.jsonがGitにコミットされそう

A: `.gitignore`に`.claude/settings.local.json`が含まれているか確認してください。

### Q: settings.json と settings.local.json はどちらが優先される？

A: **settings.local.json が優先**されます。

---

## 参考資料

- [Claude Code 公式ドキュメント](https://code.claude.com/docs/)
- [AGENTS.md](../AGENTS.md) - このリポジトリの設計思想とルール
