#!/usr/bin/env bash
# Gedeelde GHCR + docker compose install (binnen LXC). Source na community-scripts functions.

# shellcheck source=/dev/null
source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-motd.sh")

xdio_ghcr_login() {
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    msg_info "Logging in to GHCR"
    if [[ -n "${GHCR_USERNAME:-}" ]]; then
      echo "${GHCR_TOKEN}" | $STD docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin
    else
      echo "${GHCR_TOKEN}" | $STD docker login ghcr.io -u "${GITHUB_USER:-s4ndyp}" --password-stdin
    fi
    msg_ok "Logged in to GHCR"
  elif [[ -n "${GHCR_USERNAME:-}" && -n "${GHCR_PASSWORD:-}" ]]; then
    msg_info "Logging in to GHCR"
    echo "${GHCR_PASSWORD}" | $STD docker login ghcr.io -u "${GHCR_USERNAME}" --password-stdin
    msg_ok "Logged in to GHCR"
  fi
}

# Args: app_label app_dir compose_url [host_port=80]
xdio_install_compose_stack() {
  local app_label="$1" app_dir="$2" compose_url="$3" host_port="${4:-80}"

  setup_docker
  xdio_ghcr_login

  msg_info "Preparing ${app_label} stack"
  mkdir -p "${app_dir}"
  curl -fsSL "${compose_url}" -o "${app_dir}/docker-compose.yml"
  if [[ "$host_port" != "keep" ]]; then
    sed -i -E "s/^[[:space:]]*- \"[0-9]+:([0-9]+)\"/    - \"${host_port}:\\1\"/" "${app_dir}/docker-compose.yml"
  fi
  msg_ok "Prepared ${app_label} stack"

  msg_info "Pulling ${app_label} images"
  cd "${app_dir}"
  if ! $STD docker compose pull; then
    msg_error "Could not pull GHCR images. Make the package public or set GHCR_TOKEN on the Proxmox host."
    exit 1
  fi
  msg_ok "Pulled ${app_label} images"

  msg_info "Starting ${app_label}"
  $STD docker compose up -d
  msg_ok "Started ${app_label}"
}
