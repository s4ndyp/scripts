#!/usr/bin/env bash
# Snapzilla — git clone (migrations) + GHCR pull web/analyzer + PocketBase.

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APP_DIR="/opt/snapzilla"
REPO="${SNAPZILLA_REPO_URL:-https://github.com/s4ndyp/snapzilla.git}"
BRANCH="${SNAPZILLA_BRANCH:-main}"
HOST_PORT="${SNAPZILLA_PORT:-80}"

setup_docker

msg_info "Installing git"
$STD apt install -y git
msg_ok "Installed git"

msg_info "Cloning Snapzilla (${BRANCH})"
rm -rf "${APP_DIR}"
$STD git clone --depth 1 --branch "${BRANCH}" "${REPO}" "${APP_DIR}"
msg_ok "Cloned Snapzilla"

# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-snapzilla-install.sh")

msg_info "Preparing Snapzilla stack (GHCR, no LXC build)"
snapzilla_patch_compose "${APP_DIR}/docker-compose.yml"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")
xdio_compose_set_host_port "${APP_DIR}/docker-compose.yml" "${HOST_PORT}" "80"
echo "SNAPZILLA_PORT=${HOST_PORT}" >"${APP_DIR}/.env"
msg_ok "Prepared Snapzilla stack"

xdio_ghcr_login

msg_info "Pulling Snapzilla images"
cd "${APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull images. Make ghcr.io/s4ndyp/snapzilla-* public or set GHCR_TOKEN on the Proxmox host."
  exit 1
fi
msg_ok "Pulled Snapzilla images"

msg_info "Starting Snapzilla"
$STD docker compose up -d
msg_ok "Started Snapzilla"

msg_info "Waiting for Snapzilla gallery"
_ready=0
for _i in $(seq 1 60); do
  if curl -sf "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then
    _ready=1
    break
  fi
  sleep 2
done
if [[ "$_ready" -eq 1 ]]; then
  msg_ok "Snapzilla is responding on port ${HOST_PORT}"
else
  msg_warn "Stack started but HTTP not ready yet — check: docker compose -f ${APP_DIR}/docker-compose.yml ps"
fi

GALLERY_URL="http://${LOCAL_IP}"
if [[ "${HOST_PORT}" != "80" ]]; then
  GALLERY_URL="http://${LOCAL_IP}:${HOST_PORT}"
fi

cat <<EOF >~/snapzilla.creds
Snapzilla
=========
Gallery:      ${GALLERY_URL}
PocketBase:   ${GALLERY_URL}/_/  (eerste admin-setup)
Compose:      ${APP_DIR}/docker-compose.yml
Data:         Docker volume pb_data

Images:       ${SNAPZILLA_WEB_IMAGE:-ghcr.io/s4ndyp/snapzilla-web:latest}
              ${SNAPZILLA_ANALYZER_IMAGE:-ghcr.io/s4ndyp/snapzilla-analyzer:latest}

Windows client: server-URL ${GALLERY_URL}
See: https://github.com/s4ndyp/snapzilla/blob/main/readme.md
EOF
chmod 600 ~/snapzilla.creds

motd_ssh
customize
cleanup_lxc
