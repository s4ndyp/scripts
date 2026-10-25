#!/usr/bin/env bash
# Webtool (subsite-portal) — Proxmox LXC + Docker (s4ndyp/webtool, GHCR)
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/webtool/webtool.sh)"

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

APP="Webtool"
export NSAPP="${NSAPP:-webtool}"
export SCRIPT_SLUG="${SCRIPT_SLUG:-webtool}"
var_tags="${var_tags:-web;docker;pocketbase}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
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
  if [[ ! -f /opt/webtool/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating Webtool (compose + GHCR pull)"
  cd /opt/webtool
  COMPOSE_URL="${WEBTOOL_COMPOSE_URL:-https://raw.githubusercontent.com/s4ndyp/webtool/main/docker-compose.yml}"
  HOST_PORT="${WEBTOOL_PORT:-80}"
  curl -fsSL "${COMPOSE_URL}" -o docker-compose.yml
  # shellcheck source=/dev/null
  source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL}/lib/xdio-compose-install.sh")
  xdio_compose_set_host_port docker-compose.yml "${HOST_PORT}" "3000"
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated Webtool"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Portal:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}${CL}"
echo -e "${INFO}${YW}Details: ~/webtool.creds${CL}"
