#!/usr/bin/env bash
# DynCompare — Proxmox LXC + Docker (s4ndyp/scripts)
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/dyncompare/dyncompare.sh)"

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

APP="DynCompare"
var_tags="${var_tags:-compare;docker}"
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
  if [[ ! -f /opt/dyncompare/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  msg_info "Updating DynCompare"
  cd /opt/dyncompare
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated DynCompare"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}URLs:${CL}"
echo -e "${GATEWAY}${BGN}App: http://${IP}${CL}"
echo -e "${GATEWAY}${BGN}Sync: http://${IP}:8080${CL}"
