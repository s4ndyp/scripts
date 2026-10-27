#!/usr/bin/env bash
# Snapzilla — git clone (migrations) + GHCR pull web/analyzer + PocketBase; tekst via OpenRouter.

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

msg_info "Preparing Snapzilla stack (GHCR, OpenRouter via .env)"
snapzilla_deploy_stack "${APP_DIR}" "${HOST_PORT}"

if [[ -z "${OPENROUTER_API_KEY:-}" ]] && ! grep -q '^OPENROUTER_API_KEY=.\+' "${APP_DIR}/.env" 2>/dev/null; then
  msg_warn "OPENROUTER_API_KEY is leeg — zet key in web-UI (Model …) of in ${APP_DIR}/.env"
fi

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
Env:          ${APP_DIR}/.env  (optioneel OPENROUTER_API_KEY; of key in web-UI → Model …)
Data:         Docker volume pb_data

Images:       ${SNAPZILLA_WEB_IMAGE}
              ${SNAPZILLA_ANALYZER_IMAGE}

OpenRouter:   web-UI → Model … (key + test), of OPENROUTER_API_KEY in ${APP_DIR}/.env
Windows client: server-URL ${GALLERY_URL}
Update:       Proxmox menu **update** in de LXC
See: https://github.com/s4ndyp/snapzilla/blob/main/readme.md
EOF
chmod 600 ~/snapzilla.creds

motd_ssh
customize
cleanup_lxc
