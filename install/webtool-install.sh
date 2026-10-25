#!/usr/bin/env bash
# Webtool — subsite portal (docker-compose.yml from s4ndyp/webtool, GHCR).

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")

APP_DIR="/opt/webtool"
COMPOSE_URL="${WEBTOOL_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/webtool/main/docker-compose.yml}"
HOST_PORT="${WEBTOOL_PORT:-80}"

setup_docker
xdio_ghcr_login

msg_info "Preparing Webtool stack"
mkdir -p "${APP_DIR}"
curl -fsSL "${COMPOSE_URL}" -o "${APP_DIR}/docker-compose.yml"
xdio_compose_set_host_port "${APP_DIR}/docker-compose.yml" "${HOST_PORT}" "3000"
msg_ok "Prepared Webtool stack"

msg_info "Pulling Webtool images"
cd "${APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull GHCR images. Make ghcr.io/s4ndyp/webtool public or set GHCR_TOKEN on the Proxmox host."
  exit 1
fi
msg_ok "Pulled Webtool images"

msg_info "Starting Webtool"
$STD docker compose up -d
msg_ok "Started Webtool"

msg_info "Waiting for Webtool portal"
_ready=0
for _i in $(seq 1 45); do
  if curl -sf "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then
    _ready=1
    break
  fi
  sleep 2
done
if [[ "$_ready" -eq 1 ]]; then
  msg_ok "Webtool is responding on port ${HOST_PORT}"
else
  msg_warn "Container started but HTTP not ready yet — check: docker logs webtool"
fi

PORTAL_URL="http://${LOCAL_IP}"
if [[ "${HOST_PORT}" != "80" ]]; then
  PORTAL_URL="http://${LOCAL_IP}:${HOST_PORT}"
fi

cat <<EOF >~/webtool.creds
Webtool (subsite-portal)
========================
Portal:       ${PORTAL_URL}
Data volume:  webtool_data (PocketBase + uploads)
Compose:      ${APP_DIR}/docker-compose.yml
Image:        ghcr.io/s4ndyp/webtool:latest

Geen login in de UI — alleen vertrouwd netwerk of reverse proxy.
See: https://github.com/s4ndyp/webtool/blob/main/readme.md
EOF
chmod 600 ~/webtool.creds

motd_ssh
customize
cleanup_lxc
