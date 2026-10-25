#!/usr/bin/env bash
export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL}/webtool/webtool.sh")
