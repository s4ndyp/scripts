#!/usr/bin/env bash
# BackAI — PocketBase stack (deploy/docker-compose.yml from s4ndyp/backai, GHCR).

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APP_DIR="/opt/backai"
COMPOSE_URL="${BACKAI_COMPOSE_URL:-${BACKAI_DEPLOY_URL:-https://raw.githubusercontent.com/s4ndyp/backai/main/deploy}/docker-compose.yml}"

setup_docker
xdio_ghcr_login

msg_info "Preparing BackAI stack"
mkdir -p "${APP_DIR}"
curl -fsSL "${COMPOSE_URL}" -o "${APP_DIR}/docker-compose.yml"
msg_ok "Prepared BackAI stack"

BACKAI_AGENT_REGISTER_KEY="${BACKAI_AGENT_REGISTER_KEY:-$(random_password 24)}"
BACKAI_HTTP_PORT="${BACKAI_HTTP_PORT:-80}"
BACKAI_IMAGE="${BACKAI_IMAGE:-ghcr.io/s4ndyp/backai:latest}"

msg_info "Writing BackAI environment"
cat >"${APP_DIR}/.env" <<EOF
BACKAI_HTTP_PORT=${BACKAI_HTTP_PORT}
BACKAI_IMAGE=${BACKAI_IMAGE}
BACKAI_AGENT_REGISTER_KEY=${BACKAI_AGENT_REGISTER_KEY}
EOF
chmod 600 "${APP_DIR}/.env"
msg_ok "Configured BackAI (.env in ${APP_DIR})"

msg_info "Pulling BackAI images"
cd "${APP_DIR}"
if ! $STD docker compose pull; then
  msg_error "Could not pull GHCR images. Make ghcr.io/s4ndyp/backai public or set GHCR_TOKEN on the Proxmox host."
  exit 1
fi
msg_ok "Pulled BackAI images"

msg_info "Starting BackAI"
$STD docker compose up -d
msg_ok "Started BackAI"

DASHBOARD_URL="http://${LOCAL_IP}"
if [[ "${BACKAI_HTTP_PORT}" != "80" ]]; then
  DASHBOARD_URL="http://${LOCAL_IP}:${BACKAI_HTTP_PORT}"
fi

cat <<EOF >~/backai.creds
BackAI
======
Dashboard:    ${DASHBOARD_URL}
PocketBase:   ${DASHBOARD_URL}/_/  (optioneel admin)
Compose:      ${APP_DIR}/docker-compose.yml
Env file:     ${APP_DIR}/.env

BACKAI_AGENT_REGISTER_KEY=${BACKAI_AGENT_REGISTER_KEY}

Agents: BACKAI_SERVER_URL=${DASHBOARD_URL} and BACKAI_AGENT_REGISTER_KEY (above) on first run.
See: https://github.com/s4ndyp/backai/blob/main/README.md
EOF
chmod 600 ~/backai.creds

motd_ssh
customize
cleanup_lxc
