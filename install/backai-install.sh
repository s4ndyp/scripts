#!/usr/bin/env bash
# BackAI server stack — deploy/docker-compose.yml from s4ndyp/backai (GHCR).

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
DEPLOY_BASE="${BACKAI_DEPLOY_URL:-https://raw.githubusercontent.com/s4ndyp/backai/main/deploy}"

setup_docker
xdio_ghcr_login

msg_info "Preparing BackAI stack"
mkdir -p "${APP_DIR}"
curl -fsSL "${DEPLOY_BASE}/docker-compose.yml" -o "${APP_DIR}/docker-compose.yml"
msg_ok "Prepared BackAI stack"

POSTGRES_PASSWORD="${BACKAI_POSTGRES_PASSWORD:-$(random_password 24)}"
BACKAI_SESSION_SECRET="${BACKAI_SESSION_SECRET:-$(random_password 32)}"
BACKAI_AGENT_REGISTER_KEY="${BACKAI_AGENT_REGISTER_KEY:-$(random_password 24)}"
BACKAI_HTTP_PORT="${BACKAI_HTTP_PORT:-80}"
BACKAI_IMAGE="${BACKAI_IMAGE:-ghcr.io/s4ndyp/backai:latest}"

msg_info "Writing BackAI environment"
cat >"${APP_DIR}/.env" <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
BACKAI_SESSION_SECRET=${BACKAI_SESSION_SECRET}
BACKAI_AGENT_REGISTER_KEY=${BACKAI_AGENT_REGISTER_KEY}
BACKAI_HTTP_PORT=${BACKAI_HTTP_PORT}
BACKAI_IMAGE=${BACKAI_IMAGE}
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

cat <<EOF >~/backai.creds
BackAI
======
Dashboard:    http://${LOCAL_IP}
Compose:      ${APP_DIR}/docker-compose.yml
Env file:     ${APP_DIR}/.env

POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
BACKAI_SESSION_SECRET=${BACKAI_SESSION_SECRET}
BACKAI_AGENT_REGISTER_KEY=${BACKAI_AGENT_REGISTER_KEY}

Agents: set BACKAI_SERVER_URL=http://${LOCAL_IP} and BACKAI_AGENT_REGISTER_KEY (above) on first run.
See: https://github.com/s4ndyp/backai/blob/main/README.md
EOF
chmod 600 ~/backai.creds

motd_ssh
customize
cleanup_lxc
