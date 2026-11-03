#!/bin/bash
# =======================================================================
# tests/integration/entrypoint.sh
# -----------------------------------------------------------------------
# 1st run (fresh) -> assert tools -> 2nd run (idempotency) -> doctor ->
# uninstall (rc files restored) -> pipe-mode regression.
# =======================================================================
set -eo pipefail

ASSERT_SCRIPT="/workspace/tests/integration/assert-tools.sh"
export AGENTYARD_WITH="${AGENTYARD_WITH:-agents-md,zsh,tmux,zellij,aws,ast-grep,yq,markitdown,bun}"
export AGENTYARD_OFFLINE=1

assert_no_fatal_errors() {
  local log="$1" label="$2"
  local pattern='mise ERROR|^E: |Conflicting values set for option|unbound variable|: command not found|❌'
  if grep -E "$pattern" "$log"; then
    echo "❌ $label: fatal output detected (see above)"
    exit 1
  fi
}

banner() { printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n%s\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n' "$*"; }

# Snapshot rc files to verify uninstall restores them.
SNAP="$(mktemp -d)"
for f in .bashrc .profile; do cp "$HOME/$f" "$SNAP/$f" 2>/dev/null || true; done

banner "🔵 1st run — fresh install"
/workspace/install.sh install 2>&1 | tee /tmp/run1.log
assert_no_fatal_errors /tmp/run1.log "1st run"

banner "🔍 Tool assertions (login shell)"
bash -l "$ASSERT_SCRIPT"

banner "🔵 2nd run — idempotency"
/workspace/install.sh install 2>&1 | tee /tmp/run2.log
assert_no_fatal_errors /tmp/run2.log "2nd run"
skips=$(grep -c '⏭️' /tmp/run2.log || true)
echo "2nd run skip markers: $skips"
if [ "$skips" -lt 10 ]; then
  echo "❌ Expected most steps to be skipped on the 2nd run"
  exit 1
fi
for f in .bashrc .profile .zshrc .zprofile "$HOME/.agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"; do
  case "$f" in /*) path="$f" ;; *) path="$HOME/$f" ;; esac
  [ -f "$path" ] || continue
  n=$(grep -c '>>> agentyard >>>' "$path" || true)
  if [ "$n" -ne 1 ]; then
    echo "❌ $path has $n agentyard blocks (expected 1)"
    exit 1
  fi
done
echo "✅ managed blocks are not duplicated"

banner "🩺 doctor"
rc=0
/workspace/install.sh doctor || rc=$?
if [ "$rc" -gt 2 ]; then
  echo "❌ doctor exited with $rc (expected 0/1/2)"
  exit 1
fi
/workspace/install.sh doctor --repo /workspace || true

banner "🧹 uninstall"
/workspace/install.sh uninstall 2>&1 | tee /tmp/uninstall.log
# Vendor installers (e.g. Antigravity's `agy install`) may append their own
# lines, so check that (1) no agentyard block remains and (2) the original
# content is still intact at the top of each file.
for f in .bashrc .profile .zshrc .zprofile; do
  if grep -q '>>> agentyard >>>' "$HOME/$f" 2>/dev/null; then
    echo "❌ ~/$f still has an agentyard block after uninstall"
    exit 1
  fi
  [ -f "$SNAP/$f" ] || continue
  size=$(wc -c <"$SNAP/$f")
  if ! cmp -s -n "$size" "$SNAP/$f" "$HOME/$f"; then
    echo "❌ original content of ~/$f was modified:"
    diff "$SNAP/$f" "$HOME/$f" || true
    exit 1
  fi
done
if [ -d "$HOME/.config/agentyard" ]; then
  echo "❌ ~/.config/agentyard still exists after uninstall"
  exit 1
fi
echo "✅ uninstall restored rc files"

banner "🔵 Pipe-mode regression (curl | bash)"
cat /workspace/install.sh | bash -s -- --ref non-existent-ref-$$ >/tmp/pipe.log 2>&1 || true
if grep -q 'unbound variable' /tmp/pipe.log; then
  echo "❌ install.sh emitted 'unbound variable' under pipe execution"
  cat /tmp/pipe.log
  exit 1
fi
echo "✅ install.sh fails cleanly under pipe execution"

banner "✅ Integration test passed"
