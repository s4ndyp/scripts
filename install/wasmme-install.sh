#!/usr/bin/env bash
# WasmMe container install — draait binnen de LXC via community-scripts engine.

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

WASMME_APP_DIR="/opt/wasmme"
WASMME_COMPOSE_URL="${WASMME_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/wasmme/main/docker-compose.yml}"

setup_docker

if [[ -n "${GHCR_TOKEN:-}" ]]; then
  msg_info "Logging in to GHCR"
  if [[ -n "${GHCR_USERNAME:-}" ]]; then
    echo "${GHCR_TOKEN}" | $STD docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin
  else
    echo "${GHCR_TOKEN}" | $STD docker login ghcr.io -u "${GITHUB_USER:-s4ndyp}" --password-stdin
  fi
  msg_ok "Logged in to GHCR"
elif [[ -n "${GHCR_USERNAME:-}" && -n "${GHCR_PASSWORD:-}" ]]; then
  msg_info "Logging in to GHCR"
  echo "${GHCR_PASSWORD}" | $STD docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin
  msg_ok "Logged in to GHCR"
fi

msg_info "Preparing WasmMe stack"
mkdir -p "${WASMME_APP_DIR}"
curl -fsSL "${WASMME_COMPOSE_URL}" -o "${WASMME_APP_DIR}/docker-compose.yml"
msg_ok "Prepared WasmMe stack"

msg_info "Pulling WasmMe images"
cd "${WASMME_APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull GHCR images. Make the package public or set GHCR_TOKEN on the Proxmox host before running the script."
  exit 1
fi
msg_ok "Pulled WasmMe images"

msg_info "Starting WasmMe"
$STD docker compose up -d
msg_ok "Started WasmMe"

cat <<EOF >~/wasmme.creds
WasmMe
======
Published site: http://${LOCAL_IP}
Admin UI:       http://${LOCAL_IP}:8080
Data volume:    wasmme-data (Docker volume)
Compose file:   ${WASMME_APP_DIR}/docker-compose.yml
EOF

motd_ssh
customize
cleanup_lxc
