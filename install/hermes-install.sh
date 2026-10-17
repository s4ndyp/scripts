#!/usr/bin/env bash
# Hermes: official NousResearch hermes-agent install + nesquena/hermes-webui Docker (single-container).

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-hermes-docker.sh")
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
HERMES_AGENT_INSTALL_URL="${HERMES_AGENT_INSTALL_URL:-https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh}"

setup_docker

msg_info "Installing prerequisites (git, curl)"
$STD apt install -y git curl ca-certificates
msg_ok "Installed prerequisites"

msg_info "Preparing Hermes data directories"
mkdir -p "${HERMES_DATA}" "${HERMES_WORKSPACE}" "${HERMES_DATA}/logs"
chown -R "${HERMES_UID}:${HERMES_GID}" "${HERMES_DATA}" "${HERMES_WORKSPACE}"
msg_ok "Prepared Hermes data directories"

HERMES_INSTALL_HOME="/var/lib/hermes-install"
if ! id -u "${HERMES_UID}" >/dev/null 2>&1; then
  groupadd -g "${HERMES_GID}" hermes 2>/dev/null || true
  useradd -u "${HERMES_UID}" -g "${HERMES_GID}" -d "${HERMES_INSTALL_HOME}" -m -s /bin/bash hermes 2>/dev/null \
    || useradd -u "${HERMES_UID}" -d "${HERMES_INSTALL_HOME}" -m -s /bin/bash hermes
fi
install -d -o "${HERMES_UID}" -g "${HERMES_GID}" "${HERMES_INSTALL_HOME}"

if [[ "${HERMES_SKIP_AGENT_INSTALL:-0}" != "1" ]]; then
  msg_info "Installing Hermes Agent as UID ${HERMES_UID} (official NousResearch installer)"
  _agent_install_flags=(--non-interactive --skip-browser --skip-computer-use)
  if [[ -n "${HERMES_INSTALL_CHANNEL:-}" ]]; then
    _agent_install_flags+=(--channel "${HERMES_INSTALL_CHANNEL}")
  fi
  if ! runuser -u "#${HERMES_UID}" -- env \
    HERMES_HOME="${HERMES_DATA}" \
    HERMES_INSTALL_DIR="${HERMES_DATA}/hermes-agent" \
    HOME="/home/hermes" \
    bash -c "curl -fsSL '${HERMES_AGENT_INSTALL_URL}' | bash -s -- ${_agent_install_flags[*]}"; then
    msg_error "Hermes Agent install failed. Logs: ${HERMES_DATA}/logs/install.log"
    exit 1
  fi
  if [[ ! -f "${HERMES_DATA}/hermes-agent/run_agent.py" ]] || [[ ! -f "${HERMES_DATA}/hermes-agent/agent/__init__.py" ]]; then
    msg_error "Hermes Agent checkout incomplete at ${HERMES_DATA}/hermes-agent (need run_agent.py and agent/)"
    exit 1
  fi
  chown -R "${HERMES_UID}:${HERMES_GID}" "${HERMES_DATA}"
  msg_ok "Installed Hermes Agent to ${HERMES_DATA}/hermes-agent"
else
  msg_info "HERMES_SKIP_AGENT_INSTALL=1 — cloning agent source only"
  rm -rf "${HERMES_DATA}/hermes-agent"
  runuser -u "#${HERMES_UID}" -- git clone --depth 1 --branch "${HERMES_AGENT_BRANCH:-main}" \
    "${HERMES_AGENT_REPO_URL:-https://github.com/NousResearch/hermes-agent.git}" \
    "${HERMES_DATA}/hermes-agent"
  chown -R "${HERMES_UID}:${HERMES_GID}" "${HERMES_DATA}"
  msg_ok "Cloned Hermes Agent source"
fi

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

sed -i 's/"127\.0\.0\.1:8787:8787"/"80:8787"/' "${HERMES_DIR}/docker-compose.yml"
xdio_hermes_patch_compose_env "${HERMES_DIR}/docker-compose.yml"
msg_ok "Configured Hermes"

msg_info "Building Hermes Docker image (Patience — compiles SQLite in image)"
cd "${HERMES_DIR}"
if ! $STD docker compose build; then
  msg_error "Docker build failed. Try more RAM/disk (default: 2 CPU, 4 GB RAM, 24 GB disk)."
  exit 1
fi
msg_ok "Built Hermes image"

msg_info "Starting Hermes Web UI (first boot installs WebUI + agent Python deps — long)"
$STD docker compose up -d
if ! xdio_hermes_wait_for_venv "${HERMES_DIR}"; then
  msg_error "Hermes container did not finish initializing /app/venv (check: docker compose logs -f)"
  exit 1
fi
msg_info "Linking Hermes Agent into WebUI Python (pip install -e)"
if ! xdio_hermes_docker_link_agent "${HERMES_DIR}"; then
  msg_error "Could not import AIAgent in the WebUI container. See docs/troubleshooting.md in hermes-webui."
  exit 1
fi
$STD docker compose restart hermes-webui
msg_ok "Started Hermes Web UI with agent linked"

cat <<EOF >~/hermes.creds
Hermes Web UI
=============
Web UI:       http://${LOCAL_IP}
Password:     ${HERMES_WEBUI_PASSWORD}
Hermes data:  ${HERMES_DATA}
Agent:        ${HERMES_DATA}/hermes-agent (NousResearch install.sh)
Workspace:    ${HERMES_WORKSPACE}
Web UI repo:  ${HERMES_DIR} (branch ${HERMES_BRANCH})
Compose:      ${HERMES_DIR}/docker-compose.yml

Configure API keys / models in the Web UI (Control Center) on first visit.
Upstream:     https://github.com/nesquena/hermes-webui
EOF
chmod 600 ~/hermes.creds

motd_ssh
customize
cleanup_lxc
