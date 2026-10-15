#!/usr/bin/env bash

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")

COMPOSE_URL="${TINYNOTE_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/tinynote/main/docker-compose.yml}"
xdio_install_compose_stack "TinyNote" "/opt/tinynote" "$COMPOSE_URL" "80"

cat <<EOF >~/tinynote.creds
TinyNote
========
App URL:      http://${LOCAL_IP}
Compose file: /opt/tinynote/docker-compose.yml
EOF

motd_ssh
customize
cleanup_lxc
