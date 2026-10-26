#!/usr/bin/env bash
# Snapzilla stack helpers (source after network is up in install/update).

SNAPZILLA_WEB_IMAGE="${SNAPZILLA_WEB_IMAGE:-ghcr.io/s4ndyp/snapzilla-web:latest}"
SNAPZILLA_ANALYZER_IMAGE="${SNAPZILLA_ANALYZER_IMAGE:-ghcr.io/s4ndyp/snapzilla-analyzer:latest}"
SNAPZILLA_OCR_IMAGE="${SNAPZILLA_OCR_IMAGE:-gunthercox/ocr-service:2.0.1-tesseract}"

snapzilla_patch_compose() {
  local file="${1:?compose file}"
  sed -i '/^[[:space:]]*build:/d' "$file"
  sed -i "s|image: snapzilla-web:latest|image: ${SNAPZILLA_WEB_IMAGE}|" "$file"
  sed -i "s|image: snapzilla-analyzer:latest|image: ${SNAPZILLA_ANALYZER_IMAGE}|" "$file"
  if grep -q 'container_name: snapzilla-ocr' "$file" 2>/dev/null; then
    sed -i "s|image: gunthercox/ocr-service:.*|image: ${SNAPZILLA_OCR_IMAGE}|" "$file"
  fi
}

snapzilla_write_env() {
  local app_dir="$1" host_port="$2"
  if [[ -f "${app_dir}/.env" ]] && grep -q '^SNAPZILLA_PORT=' "${app_dir}/.env" 2>/dev/null; then
    sed -i "s/^SNAPZILLA_PORT=.*/SNAPZILLA_PORT=${host_port}/" "${app_dir}/.env"
  else
    echo "SNAPZILLA_PORT=${host_port}" >"${app_dir}/.env"
  fi
}

snapzilla_pb_migrate() {
  local app_dir="${1:-/opt/snapzilla}"
  cd "${app_dir}" || return 1
  msg_info "Running PocketBase migrations"
  local ready=0
  local _i
  for _i in $(seq 1 30); do
    if $STD docker compose exec -T pocketbase wget -q -O /dev/null http://127.0.0.1:8090/api/health 2>/dev/null; then
      ready=1
      break
    fi
    sleep 2
  done
  if [[ "$ready" -ne 1 ]]; then
    msg_warn "PocketBase not healthy — skipped migrate up (retry: docker compose exec pocketbase pocketbase migrate up)"
    return 1
  fi
  if ! $STD docker compose exec -T pocketbase pocketbase migrate up \
    --dir=/pb_data \
    --migrationsDir=/pb_migrations; then
    msg_warn "PocketBase migrate up failed — check docker compose logs pocketbase"
    return 1
  fi
  msg_ok "PocketBase migrations applied"
}

snapzilla_sync_repo() {
  local app_dir="${1:-/opt/snapzilla}"
  local branch="${2:-${SNAPZILLA_BRANCH:-main}}"

  cd "${app_dir}" || exit 1
  if [[ ! -d .git ]]; then
    msg_error "Missing git checkout in ${app_dir}"
    exit 1
  fi

  msg_info "Syncing Snapzilla from origin/${branch}"
  $STD git fetch origin "${branch}" --depth=1
  if ! $STD git diff --quiet -- docker-compose.yml 2>/dev/null; then
    msg_info "Restoring docker-compose.yml from origin/${branch}"
    git restore --source="origin/${branch}" --staged --worktree docker-compose.yml 2>/dev/null \
      || git checkout "origin/${branch}" -- docker-compose.yml
  fi
  $STD git reset --hard "origin/${branch}"
  msg_ok "Synced Snapzilla repository"
}

snapzilla_deploy_stack() {
  local app_dir="${1:-/opt/snapzilla}"
  local host_port="${2:-${SNAPZILLA_PORT:-80}}"

  snapzilla_patch_compose "${app_dir}/docker-compose.yml"
  # shellcheck source=/dev/null
  source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")
  xdio_compose_set_host_port "${app_dir}/docker-compose.yml" "${host_port}" "80"
  snapzilla_write_env "${app_dir}" "${host_port}"

  xdio_ghcr_login
  cd "${app_dir}" || exit 1
  msg_info "Pulling Snapzilla images (web, analyzer, OCR, PocketBase)"
  if ! $STD docker compose pull; then
    msg_error "Could not pull images. Make ghcr.io/s4ndyp/snapzilla-* public or set GHCR_TOKEN on the Proxmox host."
    exit 1
  fi
  msg_ok "Pulled Snapzilla images"

  msg_info "Starting Snapzilla stack"
  $STD docker compose up -d
  msg_ok "Started Snapzilla stack"

  snapzilla_pb_migrate "${app_dir}" || true
}

snapzilla_refresh_stack() {
  snapzilla_sync_repo "${1:-/opt/snapzilla}"
  snapzilla_deploy_stack "${1:-/opt/snapzilla}" "${2:-${SNAPZILLA_PORT:-80}}"
}
