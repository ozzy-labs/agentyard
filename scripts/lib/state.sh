#!/bin/bash
# scripts/lib/state.sh
# Records what agentyard installed or modified, so update / uninstall only
# touch agentyard-owned things (ADR-0007 principle 8).
#
# Format: one record per line, tab-separated: <type>\t<value>[\t<extra>...]
# Types:
#   apt-pkg <name>                  apt package installed by agentyard
#   apt-repo <name> <file> <codename|-> <pkgs,comma>
#   mise <tool-spec>                tool added to mise global config
#   uv-tool <name>
#   block <file>                    managed block written into <file>
#   created <file>                  file created by agentyard
#   symlink <path>                  symlink created by agentyard
#   agent <id>                      agent installed by agentyard
#   component <id>                  opt-in component installed by agentyard
#   setting <key> <value>           misc settings (e.g. wsl-browser 1)
# Requires lib/core.sh.

state_file() { printf '%s/state' "$AGENTYARD_CONFIG_DIR"; }

_state_ensure() {
  mkdir -p "$AGENTYARD_CONFIG_DIR"
  [ -f "$(state_file)" ] || : >"$(state_file)"
}

# state_add <type> <value> [extra...]  (idempotent on type+value)
state_add() {
  local type="$1" value="$2" line
  shift 2
  _state_ensure
  line="$(printf '%s\t%s' "$type" "$value")"
  local extra
  for extra in "$@"; do
    line="$(printf '%s\t%s' "$line" "$extra")"
  done
  state_remove "$type" "$value"
  printf '%s\n' "$line" >>"$(state_file)"
}

# state_has <type> <value>
state_has() {
  [ -f "$(state_file)" ] || return 1
  awk -F'\t' -v t="$1" -v v="$2" '$1 == t && $2 == v { found = 1 } END { exit !found }' "$(state_file)"
}

# state_list <type>  -> prints values (column 2)
state_list() {
  [ -f "$(state_file)" ] || return 0
  awk -F'\t' -v t="$1" '$1 == t { print $2 }' "$(state_file)"
}

# state_get <type> <value> <column (3+)>
state_get() {
  [ -f "$(state_file)" ] || return 1
  awk -F'\t' -v t="$1" -v v="$2" -v c="$3" '$1 == t && $2 == v { print $c; found = 1 } END { exit !found }' "$(state_file)"
}

# state_remove <type> <value>
state_remove() {
  local f tmp
  f="$(state_file)"
  [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  awk -F'\t' -v t="$1" -v v="$2" '!($1 == t && $2 == v)' "$f" >"$tmp"
  cat "$tmp" >"$f"
  rm -f "$tmp"
}
