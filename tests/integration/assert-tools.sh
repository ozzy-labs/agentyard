#!/bin/bash
# =======================================================================
# tests/integration/assert-tools.sh
# -----------------------------------------------------------------------
# Run as a login shell (bash -l) so the agentyard env.sh is in effect.
# Asserts the default tools, the four default agents, and the opt-ins the
# entrypoint selected (AGENTYARD_WITH).
# =======================================================================
set -u
FAIL=0
check() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '  ✅ %s\n' "$1"
  else
    printf '  ❌ %s not found\n' "$1"
    FAIL=1
  fi
}

echo "Default tools:"
for t in git git-lfs gh jq rg tree fzf fd bwrap socat mise node pnpm uv; do check "$t"; done

echo "Default agents:"
for t in claude codex copilot agy; do check "$t"; done

echo "Opt-ins (${AGENTYARD_WITH:-}):"
case ",${AGENTYARD_WITH:-}," in *,zsh,*) check zsh ;; esac
case ",${AGENTYARD_WITH:-}," in *,tmux,*) check tmux ;; esac
case ",${AGENTYARD_WITH:-}," in *,zellij,*) check zellij ;; esac
case ",${AGENTYARD_WITH:-}," in *,aws,*) check aws ;; esac
case ",${AGENTYARD_WITH:-}," in *,ast-grep,*) check ast-grep ;; esac
case ",${AGENTYARD_WITH:-}," in *,yq,*) check yq ;; esac
case ",${AGENTYARD_WITH:-}," in *,markitdown,*) check markitdown ;; esac
case ",${AGENTYARD_WITH:-}," in *,bun,*) check bun ;; esac

echo "AGENTS.md wiring:"
if case ",${AGENTYARD_WITH:-}," in *,agents-md,*) true ;; *) false ;; esac then
  [ -f "$HOME/.agents/AGENTS.md" ] && echo "  ✅ ~/.agents/AGENTS.md" || {
    echo "  ❌ ~/.agents/AGENTS.md"
    FAIL=1
  }
  grep -qF '@~/.agents/AGENTS.md' "$HOME/.claude/CLAUDE.md" && echo "  ✅ Claude Code import" || {
    echo "  ❌ Claude Code import"
    FAIL=1
  }
  [ -L "$HOME/.codex/AGENTS.md" ] && echo "  ✅ Codex symlink" || {
    echo "  ❌ Codex symlink"
    FAIL=1
  }
  grep -qF '](~/.agents/AGENTS.md)' "$HOME/.gemini/AGENTS.md" && echo "  ✅ Antigravity include" || {
    echo "  ❌ Antigravity include"
    FAIL=1
  }
  case ",${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:-}," in
  *",$HOME/.agents,"*) echo "  ✅ Copilot dirs" ;;
  *)
    echo "  ❌ COPILOT_CUSTOM_INSTRUCTIONS_DIRS=${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:-}"
    FAIL=1
    ;;
  esac
fi

exit "$FAIL"
