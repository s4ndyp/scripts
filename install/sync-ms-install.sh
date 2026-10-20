#!/usr/bin/env bash
# Sync-MS — PocketBase + collector (docker-compose.yml from s4ndyp/sync-ms, GHCR).

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")

APP_DIR="/opt/sync-ms"
COMPOSE_URL="${SYNCMS_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/sync-ms/main/docker-compose.yml}"
HOST_PORT="${SYNCMS_HTTP_PORT:-80}"
SYNCMS_IMAGE="${SYNCMS_IMAGE:-ghcr.io/s4ndyp/sync-ms:latest}"
SYNCMS_SAMPLE_INTERVAL_SEC="${SYNCMS_SAMPLE_INTERVAL_SEC:-60}"
SYNCMS_RETENTION_DAYS="${SYNCMS_RETENTION_DAYS:-45}"

setup_docker
xdio_ghcr_login

msg_info "Preparing Sync-MS stack"
mkdir -p "${APP_DIR}"
curl -fsSL "${COMPOSE_URL}" -o "${APP_DIR}/docker-compose.yml"
xdio_compose_set_host_port "${APP_DIR}/docker-compose.yml" "${HOST_PORT}" 8090
msg_ok "Prepared Sync-MS stack"

msg_info "Writing Sync-MS environment"
cat >"${APP_DIR}/.env" <<EOF
SYNCMS_IMAGE=${SYNCMS_IMAGE}
SYNCMS_SAMPLE_INTERVAL_SEC=${SYNCMS_SAMPLE_INTERVAL_SEC}
SYNCMS_RETENTION_DAYS=${SYNCMS_RETENTION_DAYS}
EOF
chmod 600 "${APP_DIR}/.env"
msg_ok "Configured Sync-MS (.env in ${APP_DIR})"

msg_info "Pulling Sync-MS images"
cd "${APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull GHCR images. Make ghcr.io/s4ndyp/sync-ms public or set GHCR_TOKEN on the Proxmox host."
  exit 1
fi
msg_ok "Pulled Sync-MS images"

msg_info "Starting Sync-MS"
$STD docker compose up -d
msg_ok "Started Sync-MS"

msg_info "Waiting for Sync-MS API"
_ready=0
for _i in $(seq 1 45); do
  if curl -sf "http://127.0.0.1:${HOST_PORT}/api/health" >/dev/null 2>&1; then
    _ready=1
    break
  fi
  sleep 2
done
if [[ "$_ready" -eq 1 ]]; then
  msg_ok "Sync-MS is responding on port ${HOST_PORT}"
else
  msg_warn "Sync-MS container started but /api/health not ready yet — check: docker logs sync-ms"
fi

DASHBOARD_URL="http://${LOCAL_IP}"
if [[ "${HOST_PORT}" != "80" ]]; then
  DASHBOARD_URL="http://${LOCAL_IP}:${HOST_PORT}"
fi

cat <<EOF >~/sync-ms.creds
Sync-MS
=======
Dashboard:    ${DASHBOARD_URL}
Compose:      ${APP_DIR}/docker-compose.yml
Env file:     ${APP_DIR}/.env

SYNCMS_SAMPLE_INTERVAL_SEC=${SYNCMS_SAMPLE_INTERVAL_SEC}
SYNCMS_RETENTION_DAYS=${SYNCMS_RETENTION_DAYS}

Geen login in de app — alleen vertrouwd netwerk of reverse proxy.
Syncthing: GUI-URL + API key per instance toevoegen in het dashboard.
See: https://github.com/s4ndyp/sync-ms/blob/main/readme.md
EOF
chmod 600 ~/sync-ms.creds

motd_ssh
customize
cleanup_lxc
