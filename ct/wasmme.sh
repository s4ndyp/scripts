#!/usr/bin/env bash
# Canonical path for `update` in de LXC (community-scripts verwacht ct/<slug>.sh).
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL}/wasmme/wasmme.sh")
