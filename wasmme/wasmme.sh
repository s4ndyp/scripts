#!/usr/bin/env bash
# WasmMe — Proxmox LXC + Docker (s4ndyp/scripts)
# Gebruik op de Proxmox-host:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"
#
# Vereist: community-scripts core (wordt automatisch gedownload).

export COMMUNITY_SCRIPTS_URL="${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}"

_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

APP="WasmMe"
var_tags="${var_tags:-wasm;static;docker}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"
# Docker Compose zonder extra prompts (handig voor unattended installs)
export var_docker_compose="${var_docker_compose:-yes}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/wasmme/docker-compose.yml ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating WasmMe containers"
  cd /opt/wasmme
  $STD docker compose pull
  $STD docker compose up -d
  msg_ok "Updated WasmMe"

  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}URLs:${CL}"
echo -e "${GATEWAY}${BGN}Gepubliceerde site: http://${IP}${CL}"
echo -e "${GATEWAY}${BGN}Admin (upload/publish): http://${IP}:8080${CL}"
