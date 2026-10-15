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

APP_DIR="/opt/dyncompare"
COMPOSE_URL="${DYNCOMPARE_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/dyncompare/main/docker-compose.yml}"

setup_docker
xdio_ghcr_login

msg_info "Preparing DynCompare stack"
mkdir -p "${APP_DIR}"
curl -fsSL "${COMPOSE_URL}" -o "${APP_DIR}/docker-compose.yml"
sed -i -E \
  -e 's/"8097:8090"/"80:8090"/' \
  -e 's/"8098:8091"/"8080:8091"/' \
  "${APP_DIR}/docker-compose.yml"
msg_ok "Prepared DynCompare stack"

msg_info "Pulling DynCompare images"
cd "${APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull GHCR images. Make the package public or set GHCR_TOKEN on the Proxmox host."
  exit 1
fi
msg_ok "Pulled DynCompare images"

msg_info "Starting DynCompare"
$STD docker compose up -d
msg_ok "Started DynCompare"

cat <<EOF >~/dyncompare.creds
DynCompare
==========
App:          http://${LOCAL_IP}
Sync service: http://${LOCAL_IP}:8080
Compose file: ${APP_DIR}/docker-compose.yml
EOF

motd_ssh
customize
cleanup_lxc
