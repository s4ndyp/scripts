#!/usr/bin/env bash
# Snapzilla stack helpers (source after network is up in install/update).

SNAPZILLA_WEB_IMAGE="${SNAPZILLA_WEB_IMAGE:-ghcr.io/s4ndyp/snapzilla-web:latest}"
SNAPZILLA_ANALYZER_IMAGE="${SNAPZILLA_ANALYZER_IMAGE:-ghcr.io/s4ndyp/snapzilla-analyzer:latest}"

# community-scripts msg_info/msg_ok use a nested _MSG_BLOCKS stack; an unmatched
# msg_info leaves a spinner running after cleanup_lxc (on_exit). Reset explicitly.
snapzilla_msg_spinner_reset() {
  if declare -f stop_spinner >/dev/null 2>&1; then
    stop_spinner
  fi
  if declare -p _MSG_BLOCKS &>/dev/null 2>&1; then
    _MSG_BLOCKS=()
  fi
}

snapzilla_env_set() {
  local file="$1" key="$2" value="$3"
  grep -v "^${key}=" "$file" >"${file}.new" 2>/dev/null || : >"${file}.new"
  printf '%s=%s\n' "$key" "$value" >>"${file}.new"
  mv "${file}.new" "$file"
}

snapzilla_read_host_port() {
  local app_dir="${1:-/opt/snapzilla}" default_port="${2:-80}"
  local env_file="${app_dir}/.env"
  if [[ -f "$env_file" ]]; then
    local p
    p="$(grep -E '^SNAPZILLA_PORT=' "$env_file" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '\r"' | tr -d ' ')"
    if [[ -n "$p" && "$p" =~ ^[0-9]+$ ]]; then
      echo "$p"
      return 0
    fi
  fi
  echo "$default_port"
}

snapzilla_patch_compose() {
  local file="${1:?compose file}"
  sed -i '/^[[:space:]]*build:/d' "$file"
  sed -i "s|image: snapzilla-web:latest|image: ${SNAPZILLA_WEB_IMAGE}|" "$file"
  sed -i "s|image: snapzilla-analyzer:latest|image: ${SNAPZILLA_ANALYZER_IMAGE}|" "$file"
}

snapzilla_write_env() {
  local app_dir="$1" host_port="$2"
  local env_file="${app_dir}/.env"
  local example="${app_dir}/.env.example"

  if [[ ! -f "$env_file" && -f "$example" ]]; then
    cp "$example" "$env_file"
  fi
  [[ -f "$env_file" ]] || touch "$env_file"

  if grep -q '^SNAPZILLA_PORT=' "$env_file" 2>/dev/null; then
    sed -i "s/^SNAPZILLA_PORT=.*/SNAPZILLA_PORT=${host_port}/" "$env_file"
  else
    echo "SNAPZILLA_PORT=${host_port}" >>"$env_file"
  fi

  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    snapzilla_env_set "$env_file" OPENROUTER_API_KEY "${OPENROUTER_API_KEY}"
  elif ! grep -q '^OPENROUTER_API_KEY=' "$env_file" 2>/dev/null; then
    echo "OPENROUTER_API_KEY=" >>"$env_file"
  fi

  if [[ -n "${OPENROUTER_MODEL:-}" ]]; then
    snapzilla_env_set "$env_file" OPENROUTER_MODEL "${OPENROUTER_MODEL}"
  fi

  chmod 600 "$env_file"
}

snapzilla_pb_migrate() {
  local app_dir="${1:-/opt/snapzilla}"
  cd "${app_dir}" || return 1
  msg_info "Running PocketBase migrations"
  $STD docker compose up -d pocketbase
  local ready=0
  local _i
  for _i in $(seq 1 45); do
    if $STD docker compose exec -T pocketbase wget -q -O /dev/null http://127.0.0.1:8090/api/health 2>/dev/null; then
      ready=1
      break
    fi
    sleep 2
  done
  if [[ "$ready" -ne 1 ]]; then
    msg_warn "PocketBase not healthy — skipped migrate up (retry: cd ${app_dir} && bash scripts/pb-migrate.sh)"
    return 1
  fi
  local migrate_out
  if ! migrate_out=$(
    $STD docker compose exec -T pocketbase pocketbase migrate up \
      --dir=/pb_data \
      --migrationsDir=/pb_migrations 2>&1
  ); then
    msg_warn "PocketBase migrate up failed"
    msg_warn "${migrate_out}"
    msg_warn "Handmatig: cd ${app_dir} && docker compose exec pocketbase pocketbase migrate up --dir=/pb_data --migrationsDir=/pb_migrations"
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

  if ! git diff --quiet -- docker-compose.yml 2>/dev/null; then
    msg_info "Restoring docker-compose.yml from origin/${branch}"
    $STD git fetch origin "${branch}" 2>/dev/null || true
    git restore --source="origin/${branch}" --staged --worktree docker-compose.yml 2>/dev/null \
      || git checkout "origin/${branch}" -- docker-compose.yml 2>/dev/null || true
    msg_ok "Restored docker-compose.yml from origin/${branch}"
  fi

  $STD git fetch origin "${branch}"
  if ! $STD git pull --ff-only origin "${branch}"; then
    msg_warn "Fast-forward pull failed — resetting to origin/${branch}"
    $STD git reset --hard "origin/${branch}"
  fi
  msg_ok "Synced Snapzilla repository ($(git rev-parse --short HEAD 2>/dev/null || echo '?'))"
}

snapzilla_deploy_stack() {
  local app_dir="${1:-/opt/snapzilla}"
  local host_port="${2:-$(snapzilla_read_host_port "$app_dir" "${SNAPZILLA_PORT:-80}")}"

  snapzilla_patch_compose "${app_dir}/docker-compose.yml"
  # shellcheck source=/dev/null
  source <(curl -fsSL "${COMMUNITY_SCRIPTS_URL:-https://raw.githubusercontent.com/s4ndyp/scripts/main}/lib/xdio-compose-install.sh")
  xdio_compose_set_host_port "${app_dir}/docker-compose.yml" "${host_port}" "80"
  snapzilla_write_env "${app_dir}" "${host_port}"

  xdio_ghcr_login
  cd "${app_dir}" || exit 1
  msg_info "Pulling Snapzilla images (PocketBase, web, analyzer)"
  if ! $STD docker compose pull; then
    msg_error "Could not pull images. Make ghcr.io/s4ndyp/snapzilla-* public or set GHCR_TOKEN on the Proxmox host."
    exit 1
  fi
  msg_ok "Pulled Snapzilla images"

  msg_info "Starting Snapzilla stack"
  if ! $STD docker compose up -d --remove-orphans; then
    msg_error "docker compose up failed — check: cd ${app_dir} && docker compose ps && docker compose logs --tail=40"
    exit 1
  fi
  $STD docker compose up -d --force-recreate web analyzer 2>/dev/null || true
  msg_ok "Started Snapzilla stack"

  snapzilla_pb_migrate "${app_dir}" || true
  snapzilla_msg_spinner_reset
}

snapzilla_refresh_stack() {
  local app_dir="${1:-/opt/snapzilla}"
  local host_port="${2:-$(snapzilla_read_host_port "$app_dir" "${SNAPZILLA_PORT:-80}")}"
  snapzilla_sync_repo "${app_dir}" "${SNAPZILLA_BRANCH:-main}"
  snapzilla_deploy_stack "${app_dir}" "${host_port}"
  snapzilla_msg_spinner_reset
}
