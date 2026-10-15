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

COMPOSE_URL="${ASSETVAULT_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/assetvault/master/docker-compose.yml}"
APP_DIR="/opt/assetvault"

setup_docker
xdio_ghcr_login

msg_info "Preparing AssetVault stack"
mkdir -p "${APP_DIR}"
if curl -fsSL "${COMPOSE_URL}" -o "${APP_DIR}/docker-compose.yml" 2>/dev/null; then
  sed -i -E 's/^[[:space:]]*- "[0-9]+:([0-9]+)"/    - "80:\1"/' "${APP_DIR}/docker-compose.yml"
else
  msg_warn "Could not fetch ${COMPOSE_URL}; using built-in compose (ghcr.io/s4ndyp/assetvault:latest)"
  cat >"${APP_DIR}/docker-compose.yml" <<'YAML'
services:
  app:
    image: ghcr.io/s4ndyp/assetvault:latest
    pull_policy: always
    container_name: assetvault
    restart: unless-stopped
    ports:
      - "80:8090"
    volumes:
      - assetvault_data:/app/pb_data

volumes:
  assetvault_data:
YAML
fi
msg_ok "Prepared AssetVault stack"

msg_info "Pulling AssetVault images"
cd "${APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull GHCR images. Publish the package or set GHCR_TOKEN; for a private repo set ASSETVAULT_COMPOSE_URL."
  exit 1
fi
msg_ok "Pulled AssetVault images"

msg_info "Starting AssetVault"
$STD docker compose up -d
msg_ok "Started AssetVault"

cat <<EOF >~/assetvault.creds
AssetVault
==========
App URL:      http://${LOCAL_IP}
Compose file: ${APP_DIR}/docker-compose.yml
EOF

motd_ssh
customize
cleanup_lxc
