#!/usr/bin/env bash
# Hermes Web UI: clone nesquena/hermes-webui, docker compose build (agent in-process).

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

HERMES_DIR="/opt/hermes-webui"
HERMES_REPO="${HERMES_REPO_URL:-https://github.com/nesquena/hermes-webui.git}"
HERMES_BRANCH="${HERMES_BRANCH:-master}"
HERMES_DATA="/opt/hermes-data"
HERMES_WORKSPACE="/opt/hermes-workspace"
HERMES_UID="${HERMES_UID:-1000}"
HERMES_GID="${HERMES_GID:-1000}"

setup_docker

msg_info "Installing git"
$STD apt install -y git
msg_ok "Installed git"

msg_info "Preparing Hermes data directories"
mkdir -p "${HERMES_DATA}" "${HERMES_WORKSPACE}"
chown -R "${HERMES_UID}:${HERMES_GID}" "${HERMES_DATA}" "${HERMES_WORKSPACE}"
msg_ok "Prepared Hermes data directories"

msg_info "Cloning Hermes Web UI (${HERMES_BRANCH})"
rm -rf "${HERMES_DIR}"
$STD git clone --depth 1 --branch "${HERMES_BRANCH}" "${HERMES_REPO}" "${HERMES_DIR}"
msg_ok "Cloned Hermes Web UI"

if [[ -z "${HERMES_WEBUI_PASSWORD:-}" ]]; then
  HERMES_WEBUI_PASSWORD="$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 20)"
fi

msg_info "Configuring Hermes (Web UI on port 80 in LXC)"
cat >"${HERMES_DIR}/.env" <<EOF
UID=${HERMES_UID}
GID=${HERMES_GID}
HERMES_HOME=${HERMES_DATA}
HERMES_WORKSPACE=${HERMES_WORKSPACE}
HERMES_WEBUI_PASSWORD=${HERMES_WEBUI_PASSWORD}
EOF

# Expose on all interfaces via LXC port 80 (not localhost-only 8787).
sed -i \
  -e 's/127\.0\.0\.1:8787:8787/"80:8787"/' \
  -e 's/#      - "8787:8787"/      # - "8787:8787"/' \
  "${HERMES_DIR}/docker-compose.yml"
msg_ok "Configured Hermes"

msg_info "Building Hermes Docker image (Patience — compiles SQLite in image)"
cd "${HERMES_DIR}"
if ! $STD docker compose build; then
  msg_error "Docker build failed. Try more RAM/disk on the LXC (default: 2 CPU, 4 GB RAM, 20 GB disk)."
  exit 1
fi
msg_ok "Built Hermes image"

msg_info "Starting Hermes Web UI"
$STD docker compose up -d
msg_ok "Started Hermes Web UI"

cat <<EOF >~/hermes.creds
Hermes Web UI
=============
Web UI:       http://${LOCAL_IP}
Password:     ${HERMES_WEBUI_PASSWORD}
Hermes data:  ${HERMES_DATA}
Workspace:    ${HERMES_WORKSPACE}
Source:       ${HERMES_DIR} (branch ${HERMES_BRANCH})
Compose:      ${HERMES_DIR}/docker-compose.yml

Configure API keys / models in the Web UI (Control Center) on first visit.
Upstream:     https://github.com/nesquena/hermes-webui
EOF
chmod 600 ~/hermes.creds

motd_ssh
customize
cleanup_lxc
