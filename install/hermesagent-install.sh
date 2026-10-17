#!/usr/bin/env bash
# Gebaseerd op community-scripts/ProxmoxVE install/hermesagent-install.sh ( gelezen via GitHub raw, maart 2026 )
# https://github.com/community-scripts/ProxmoxVE/blob/main/install/hermesagent-install.sh
# xdio uitbreiding: Hermes Web UI (https://github.com/nesquena/hermes-webui) — native ctl.sh, geen Docker build.

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y git python3 python3-venv libcap2-bin
msg_ok "Installed Dependencies"

NODE_VERSION="22" setup_nodejs

msg_info "Creating Hermes User"
useradd -m -s /bin/bash hermes
loginctl enable-linger hermes
echo 'export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"' >>/home/hermes/.profile
msg_ok "Created Hermes User"

msg_info "Configuring Service Environment"
cat <<EOF >/etc/default/hermes
HOME=/home/hermes
PATH=/home/hermes/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
NODE_OPTIONS=${NODE_OPTIONS}
EOF
msg_ok "Configured Service Environment"

confirm_external_installer "https://hermes-agent.nousresearch.com/" "https://hermes-agent.nousresearch.com/install.sh"

msg_info "Installing Hermes Agent"
curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o /tmp/hermes-install.sh
$STD setsid --wait bash -c '
  set -a; source /etc/default/hermes; set +a
  export npm_config_yes=true
  bash /tmp/hermes-install.sh --skip-setup --hermes-home /home/hermes/.hermes --dir /home/hermes/.hermes/hermes-agent
'
rm -f /tmp/hermes-install.sh
chown -R hermes:hermes /home/hermes
chmod 750 /home/hermes
chmod 700 /home/hermes/.hermes
git config --system --add safe.directory /home/hermes/.hermes/hermes-agent 2>/dev/null || true
msg_ok "Installed Hermes Agent"

msg_info "Configuring API Server"
API_SERVER_KEY=$(random_password 32)
mkdir -p /home/hermes/.hermes
cat <<EOF >/home/hermes/.hermes/.env
API_SERVER_ENABLED=true
API_SERVER_HOST=0.0.0.0
API_SERVER_PORT=8642
API_SERVER_KEY=${API_SERVER_KEY}
EOF
chmod 600 /home/hermes/.hermes/.env
msg_ok "Configured API Server"

HERMES_WEBUI_DIR="/home/hermes/hermes-webui"
HERMES_WEBUI_REPO="${HERMES_WEBUI_REPO:-https://github.com/nesquena/hermes-webui.git}"
HERMES_WEBUI_BRANCH="${HERMES_WEBUI_BRANCH:-master}"
HERMES_WEBUI_PORT="${HERMES_WEBUI_PORT:-80}"
HERMES_WEBUI_PASSWORD="${HERMES_WEBUI_PASSWORD:-$(random_password 20)}"

msg_info "Installing Hermes Web UI (native — agent already in /home/hermes/.hermes)"
rm -rf "${HERMES_WEBUI_DIR}"
$STD git clone --depth 1 --branch "${HERMES_WEBUI_BRANCH}" "${HERMES_WEBUI_REPO}" "${HERMES_WEBUI_DIR}"
chown -R hermes:hermes "${HERMES_WEBUI_DIR}"
grep -q '^HERMES_WEBUI_PASSWORD=' /home/hermes/.hermes/.env 2>/dev/null \
  || echo "HERMES_WEBUI_PASSWORD=${HERMES_WEBUI_PASSWORD}" >>/home/hermes/.hermes/.env
chmod 600 /home/hermes/.hermes/.env
msg_ok "Cloned Hermes Web UI"

msg_info "Bootstrapping Hermes Web UI (Patience — first on 8787, then poort ${HERMES_WEBUI_PORT})"
if ! $STD setsid --wait bash -c "
  set -a; source /etc/default/hermes; set +a
  export HERMES_HOME=/home/hermes/.hermes
  export HERMES_WEBUI_PASSWORD=${HERMES_WEBUI_PASSWORD}
  cd ${HERMES_WEBUI_DIR}
  ./ctl.sh start --host 0.0.0.0 8787 --skip-agent-install
"; then
  msg_error "Hermes Web UI bootstrap failed. Check /home/hermes/.hermes/webui.log (su - hermes)."
  exit 1
fi
WEBUI_PY="${HERMES_WEBUI_DIR}/.venv/bin/python3"
if [[ -x "${WEBUI_PY}" ]] && [[ "${HERMES_WEBUI_PORT}" == "80" ]]; then
  setcap cap_net_bind_service=+ep "${WEBUI_PY}" 2>/dev/null \
    || msg_warn "setcap failed — using port 8787 instead of 80"
  if getcap "${WEBUI_PY}" 2>/dev/null | grep -q cap_net_bind_service; then
    $STD setsid --wait bash -c "
      set -a; source /etc/default/hermes; set +a
      export HERMES_HOME=/home/hermes/.hermes
      export HERMES_WEBUI_PASSWORD=${HERMES_WEBUI_PASSWORD}
      cd ${HERMES_WEBUI_DIR}
      ./ctl.sh restart --host 0.0.0.0 80 --skip-agent-install
    "
  else
    HERMES_WEBUI_PORT=8787
    msg_warn "Web UI blijft op poort 8787 (geen cap_net_bind_service)"
  fi
fi
chown -R hermes:hermes /home/hermes
msg_ok "Bootstrapped Hermes Web UI"

msg_info "Creating Hermes Web UI Service"
cat <<EOF >/etc/systemd/system/hermes-webui.service
[Unit]
Description=Hermes Web UI
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=hermes
Group=hermes
UMask=0077
WorkingDirectory=${HERMES_WEBUI_DIR}
EnvironmentFile=/etc/default/hermes
Environment=HERMES_HOME=/home/hermes/.hermes
Environment=HERMES_WEBUI_PASSWORD=${HERMES_WEBUI_PASSWORD}
ExecStart=${HERMES_WEBUI_DIR}/ctl.sh start --host 0.0.0.0 ${HERMES_WEBUI_PORT} --skip-agent-install
ExecStop=${HERMES_WEBUI_DIR}/ctl.sh stop
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hermes-webui
msg_ok "Created Hermes Web UI Service"

msg_info "Creating Dashboard Service"
cat <<EOF >/etc/systemd/system/hermes-dashboard.service
[Unit]
Description=Hermes Agent Web Dashboard
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=hermes
Group=hermes
UMask=0077
WorkingDirectory=/home/hermes
ExecStart=/home/hermes/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open
EnvironmentFile=/etc/default/hermes
Restart=on-failure
RestartSec=5
ProtectProc=invisible
ProcSubset=pid

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now hermes-dashboard
msg_ok "Created Dashboard Service"

msg_info "Creating Setup Helper"
cat <<'SETUP' >/usr/bin/hermes-setup
#!/usr/bin/env bash
set -a; source /etc/default/hermes; set +a
/home/hermes/.local/bin/hermes setup
chown -R hermes:hermes /home/hermes
chmod 750 /home/hermes
chmod 700 /home/hermes/.hermes
if [[ -f /home/hermes/.config/systemd/user/hermes-gateway.service ]]; then
  su - hermes -c 'systemctl --user enable --now hermes-gateway'
fi
echo "Hermes setup complete. File permissions restored."
SETUP
chmod +x /usr/bin/hermes-setup
msg_ok "Created Setup Helper"

msg_info "Configuring Login Hints"
cat <<'HINT' >/etc/profile.d/hermes-hint.sh
if [[ "$(id -u)" -eq 0 ]]; then
  echo "  Run 'hermes-setup' to configure your model provider and gateway server."
  echo "  Web UI: http://$(hostname -I | awk '{print $1}'):80  (password: ~/hermes.creds)"
  echo "  Use 'su - hermes' (with the dash) to switch to the hermes user."
fi
HINT
msg_ok "Configured Login Hints"

cat <<EOF >~/hermes.creds
Hermes Agent + Web UI
=====================
Web UI:       http://${LOCAL_IP}:${HERMES_WEBUI_PORT}
Password:     ${HERMES_WEBUI_PASSWORD}
Agent home:   /home/hermes/.hermes
Web UI repo:  ${HERMES_WEBUI_DIR}
API key:      /home/hermes/.hermes/.env (API_SERVER_KEY)
Setup:        hermes-setup (in LXC as root)
Dashboard:    http://127.0.0.1:9119 (inside LXC, user hermes)
Upstream CS:  community-scripts Hermes Agent + nesquena/hermes-webui
EOF
chmod 600 ~/hermes.creds

motd_ssh
customize
cleanup_lxc
