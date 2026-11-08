#!/bin/bash
# scripts/lib/load.sh
# Sources every library in dependency order. Set AGENTYARD_ROOT first.

: "${AGENTYARD_ROOT:?AGENTYARD_ROOT must be set}"
AGENTYARD_TOOLS_FILE="${AGENTYARD_TOOLS_FILE:-$AGENTYARD_ROOT/config/tools.toml}"

# shellcheck source=core.sh
. "$AGENTYARD_ROOT/scripts/lib/core.sh"
# shellcheck source=support.sh
. "$AGENTYARD_ROOT/scripts/lib/support.sh"
# shellcheck source=state.sh
. "$AGENTYARD_ROOT/scripts/lib/state.sh"
# shellcheck source=block.sh
. "$AGENTYARD_ROOT/scripts/lib/block.sh"
# shellcheck source=components/platform.sh
. "$AGENTYARD_ROOT/scripts/lib/components/platform.sh"
# shellcheck source=select.sh
. "$AGENTYARD_ROOT/scripts/lib/select.sh"
# shellcheck source=shellenv.sh
. "$AGENTYARD_ROOT/scripts/lib/shellenv.sh"
# shellcheck source=mise.sh
. "$AGENTYARD_ROOT/scripts/lib/mise.sh"
# shellcheck source=git.sh
. "$AGENTYARD_ROOT/scripts/lib/git.sh"
# shellcheck source=os/ubuntu.sh
. "$AGENTYARD_ROOT/scripts/lib/os/ubuntu.sh"
# shellcheck source=os/macos.sh
. "$AGENTYARD_ROOT/scripts/lib/os/macos.sh"
# shellcheck source=components/docker.sh
. "$AGENTYARD_ROOT/scripts/lib/components/docker.sh"
# shellcheck source=components/tools.sh
. "$AGENTYARD_ROOT/scripts/lib/components/tools.sh"
# shellcheck source=agents.sh
. "$AGENTYARD_ROOT/scripts/lib/agents.sh"
# shellcheck source=agentsmd.sh
. "$AGENTYARD_ROOT/scripts/lib/agentsmd.sh"
# shellcheck source=answers.sh
. "$AGENTYARD_ROOT/scripts/lib/answers.sh"
