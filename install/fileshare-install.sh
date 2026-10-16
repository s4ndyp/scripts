#!/usr/bin/env bash
# Fileshare: clone + docker compose build (geen GHCR / geen pull-only image).

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

FILESHARE_DIR="/opt/fileshare"
FILESHARE_REPO="${FILESHARE_REPO_URL:-https://github.com/s4ndyp/fileshare.git}"
FILESHARE_BRANCH="${FILESHARE_BRANCH:-main}"

setup_docker

msg_info "Installing git"
$STD apt install -y git
msg_ok "Installed git"

msg_info "Cloning Fileshare (${FILESHARE_BRANCH})"
rm -rf "${FILESHARE_DIR}"
$STD git clone --depth 1 --branch "${FILESHARE_BRANCH}" "${FILESHARE_REPO}" "${FILESHARE_DIR}"
msg_ok "Cloned Fileshare"

msg_info "Configuring Fileshare (poort 80 op LXC)"
cat >"${FILESHARE_DIR}/.env" <<EOF
FILESHARE_PORT=80
EOF
msg_ok "Configured Fileshare"

msg_info "Building Fileshare Docker image (Patience)"
cd "${FILESHARE_DIR}"
if ! $STD docker compose build; then
  msg_error "Docker build failed. Check disk/RAM in the LXC (default: 2 CPU, 2 GB RAM, 10 GB disk)."
  exit 1
fi
msg_ok "Built Fileshare image"

msg_info "Starting Fileshare"
$STD docker compose up -d
msg_ok "Started Fileshare"

cat <<EOF >~/fileshare.creds
Fileshare
=========
App URL:      http://${LOCAL_IP}
Data volume:  fileshare_data (Docker volume)
Source:       ${FILESHARE_DIR} (${FILESHARE_BRANCH})
Compose:      ${FILESHARE_DIR}/docker-compose.yml
EOF

motd_ssh
customize
cleanup_lxc
