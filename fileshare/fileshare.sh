#!/usr/bin/env bash
# Fileshare — Proxmox LXC + Docker (build from git, geen GHCR)
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/fileshare/fileshare.sh)"

export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}"

_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/xdio.func" ]]; then
  # shellcheck source=/dev/null
  source "$(dirname "${BASH_SOURCE[0]}")/../lib/xdio.func"
else
  # shellcheck source=/dev/null
  source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL}/lib/xdio.func")
fi

APP="Fileshare"
var_tags="${var_tags:-files;docker}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-10}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"
export var_docker_compose="${var_docker_compose:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /opt/fileshare/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating Fileshare from git"
  cd /opt/fileshare
  $STD git fetch origin
  $STD git pull --ff-only
  msg_info "Rebuilding Fileshare image (Patience)"
  $STD docker compose build
  $STD docker compose up -d
  msg_ok "Updated Fileshare"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}${CL}"
