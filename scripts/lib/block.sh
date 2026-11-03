#!/bin/bash
# scripts/lib/block.sh
# Managed blocks: agentyard never overwrites user content (ADR-0007 principle 7).
# It only inserts / replaces / removes the region between its own markers.
#
# Styles:
#   sh  -> "# >>> agentyard >>>" ... "# <<< agentyard <<<"
#   md  -> "<!-- >>> agentyard >>> -->" ... "<!-- <<< agentyard <<< -->"
# Requires lib/core.sh and lib/state.sh.

_block_begin() {
  case "$1" in
  md) printf '<!-- >>> agentyard >>> -->' ;;
  *) printf '# >>> agentyard >>>' ;;
  esac
}

_block_end() {
  case "$1" in
  md) printf '<!-- <<< agentyard <<< -->' ;;
  *) printf '# <<< agentyard <<<' ;;
  esac
}

# block_present <file> [style]
block_present() {
  local file="$1" style="${2:-sh}"
  [ -f "$file" ] && grep -qF "$(_block_begin "$style")" "$file"
}

# block_upsert <file> <content> [style]
# Creates <file> when missing (recorded as "created"), appends the block when
# absent, or replaces the existing block in place. Content outside the block
# is left untouched. Symlinked files are edited at their target.
block_upsert() {
  local file="$1" content="$2" style="${3:-sh}"
  local begin end tmp
  begin="$(_block_begin "$style")"
  end="$(_block_end "$style")"

  if [ ! -e "$file" ]; then
    mkdir -p "$(dirname "$file")"
    : >"$file"
    state_add created "$file"
  fi

  tmp="$(mktemp)"
  if grep -qF "$begin" "$file"; then
    BLOCK_CONTENT="$content" awk -v b="$begin" -v e="$end" '
      $0 == b { print; print ENVIRON["BLOCK_CONTENT"]; skip = 1; next }
      $0 == e { skip = 0; print; next }
      !skip { print }
    ' "$file" >"$tmp"
  else
    cat "$file" >"$tmp"
    # Separate from existing content with a blank line.
    if [ -s "$file" ]; then
      [ -n "$(tail -c1 "$file")" ] && printf '\n' >>"$tmp"
      printf '\n' >>"$tmp"
    fi
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >>"$tmp"
  fi
  if ! cmp -s "$tmp" "$file"; then
    cat "$tmp" >"$file"
  fi
  rm -f "$tmp"
  state_add block "$file" "$style"
}

# block_remove <file> [style]
# Removes the block and the single blank line that preceded it (if any).
block_remove() {
  local file="$1" style="${2:-sh}"
  local begin end tmp
  begin="$(_block_begin "$style")"
  end="$(_block_end "$style")"
  [ -f "$file" ] || return 0
  grep -qF "$begin" "$file" || return 0
  tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    $0 == b { skip = 1; if (held) { held = 0 }; next }
    $0 == e { skip = 0; next }
    skip { next }
    {
      if (held) { print pending; held = 0 }
      if ($0 == "") { pending = $0; held = 1 } else { print }
    }
    END { if (held) print pending }
  ' "$file" >"$tmp"
  cat "$tmp" >"$file"
  rm -f "$tmp"
  state_remove block "$file"
}
