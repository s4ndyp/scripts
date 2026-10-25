#!/usr/bin/env bash
# Snapzilla stack helpers (source from install script after network is up).

SNAPZILLA_WEB_IMAGE="${SNAPZILLA_WEB_IMAGE:-ghcr.io/s4ndyp/snapzilla-web:latest}"
SNAPZILLA_ANALYZER_IMAGE="${SNAPZILLA_ANALYZER_IMAGE:-ghcr.io/s4ndyp/snapzilla-analyzer:latest}"

snapzilla_patch_compose() {
  local file="${1:?compose file}"
  sed -i '/^[[:space:]]*build:/d' "$file"
  sed -i "s|image: snapzilla-web:latest|image: ${SNAPZILLA_WEB_IMAGE}|" "$file"
  sed -i "s|image: snapzilla-analyzer:latest|image: ${SNAPZILLA_ANALYZER_IMAGE}|" "$file"
}

snapzilla_refresh_stack() {
  local app_dir="${1:-/opt/snapzilla}"
  local host_port="${2:-${SNAPZILLA_PORT:-80}}"
  local branch="${SNAPZILLA_BRANCH:-main}"
  local repo="${SNAPZILLA_REPO_URL:-https://github.com/s4ndyp/snapzilla.git}"

  cd "${app_dir}" || exit 1
  if [[ -d .git ]]; then
    $STD git fetch origin
    $STD git checkout "${branch}"
    $STD git pull --ff-only origin "${branch}"
  else
    msg_error "Missing git checkout in ${app_dir}"
    exit 1
  fi

  snapzilla_patch_compose "${app_dir}/docker-compose.yml"
  # shellcheck source=/dev/null
  source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")
  xdio_compose_set_host_port "${app_dir}/docker-compose.yml" "${host_port}" "80"
  echo "SNAPZILLA_PORT=${host_port}" >"${app_dir}/.env"

  xdio_ghcr_login
  cd "${app_dir}"
  if ! $STD docker compose pull; then
    msg_error "Could not pull images. Make GHCR packages public or set GHCR_TOKEN on the Proxmox host."
    exit 1
  fi
  $STD docker compose up -d
}
