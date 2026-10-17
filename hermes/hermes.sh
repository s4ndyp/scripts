#!/usr/bin/env bash
# Deprecated alias — gebruik hermesagent/hermesagent.sh (community-scripts agent + native Web UI).
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL}/hermesagent/hermesagent.sh")
