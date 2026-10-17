#!/usr/bin/env bash
# Hermes Agent + Web UI — gebaseerd op community-scripts/ProxmoxVE ct/hermesagent.sh
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/hermesagent/hermesagent.sh)"
#
# Agent-install: zelfde flow als https://community-scripts.org/scripts/hermesagent
# + Hermes Web UI (nesquena/hermes-webui) native in de LXC.

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

APP="Hermes Agent"
var_tags="${var_tags:-ai;automation;agent}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_arm64="${var_arm64:-yes}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -x /home/hermes/.local/bin/hermes ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  confirm_external_installer "https://hermes-agent.nousresearch.com/" "hermes update (https://hermes-agent.nousresearch.com/)"

  msg_info "Stopping Services"
  systemctl stop hermes-webui 2>/dev/null || true
  systemctl stop hermes-dashboard
  msg_ok "Stopped Services"

  msg_info "Updating Hermes Agent"
  $STD setsid --wait bash -c '
    set -a; source /etc/default/hermes; set +a
    /home/hermes/.local/bin/hermes update --yes
  '
  mapfile -t root_gateway_pids < <(ps -eo user=,pid=,args= | awk '$1 == "root" && /\/home\/hermes\/\.hermes\// && /hermes_cli[.]main/ && / gateway run --replace$/ { print $2 }')
  if ((${#root_gateway_pids[@]})); then
    kill -TERM "${root_gateway_pids[@]}"
    for pid in "${root_gateway_pids[@]}"; do
      while kill -0 "$pid" 2>/dev/null; do
        sleep 0.1
      done
    done
  fi
  if ! chown -R hermes:hermes /home/hermes 2>/dev/null; then
    sleep 1
    chown -R hermes:hermes /home/hermes || msg_warn "Could not take ownership of everything under /home/hermes"
  fi
  msg_ok "Updated Hermes Agent"

  if [[ -d /home/hermes/hermes-webui ]]; then
    msg_info "Updating Hermes Web UI"
    $STD su - hermes -c '
      set -a; source /etc/default/hermes; set +a
      cd /home/hermes/hermes-webui
      git fetch origin
      git pull --ff-only
      ./ctl.sh restart --host 0.0.0.0 80 --skip-agent-install
    '
    msg_ok "Updated Hermes Web UI"
  fi

  msg_info "Starting Services"
  systemctl start hermes-dashboard
  systemctl start hermes-webui 2>/dev/null || true
  msg_ok "Started Services"
  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}Hermes Agent + Web UI setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Configure provider/gateway in the LXC:${CL}"
echo -e "${TAB}${BGN}hermes-setup${CL}"
echo -e "${INFO}${YW} Web UI:${CL}"
echo -e "${TAB}${BGN}http://${IP}${CL} (password in ~/hermes.creds)"
echo -e "${INFO}${YW} Hermes API key:${CL}"
echo -e "${TAB}${BGN}/home/hermes/.hermes/.env${CL}"
