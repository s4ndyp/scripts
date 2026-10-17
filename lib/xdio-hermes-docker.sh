#!/usr/bin/env bash
# Helpers for Hermes Web UI Docker + agent (s4ndyp/scripts install/update).

xdio_hermes_read_runtime_ids() {
  local app_dir="$1"
  local uid gid
  uid="$(grep -E '^UID=' "${app_dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d ' "')"
  gid="$(grep -E '^GID=' "${app_dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d ' "')"
  uid="${uid:-1000}"
  gid="${gid:-1000}"
  printf '%s:%s' "$uid" "$gid"
}

xdio_hermes_patch_compose_env() {
  local compose_file="$1"
  if grep -q 'HERMES_WEBUI_AGENT_DIR=' "$compose_file" 2>/dev/null; then
    return 0
  fi
  sed -i '/HERMES_WEBUI_PASSWORD=\${HERMES_WEBUI_PASSWORD:-}/a\
      - HERMES_HOME=/home/hermeswebui/.hermes\
      - HERMES_WEBUI_AGENT_DIR=/home/hermeswebui/.hermes/hermes-agent\
      - HERMES_SKIP_CHMOD=1' "$compose_file"
}

xdio_hermes_wait_for_venv() {
  local app_dir="$1"
  local tries="${2:-90}"
  local i
  cd "$app_dir" || return 1
  for ((i = 1; i <= tries; i++)); do
    if docker compose exec -T hermes-webui test -x /app/venv/bin/python 2>/dev/null; then
      return 0
    fi
    sleep 10
  done
  return 1
}

# Editable agent install into WebUI venv + import probe (fixes "AIAgent not available").
# Must run as the mount owner (UID/GID from .env), not root — hermes update refuses uid 0 on uid-1000 trees.
xdio_hermes_docker_link_agent() {
  local app_dir="$1"
  local runtime_user
  runtime_user="$(xdio_hermes_read_runtime_ids "$app_dir")"
  cd "$app_dir" || return 1
  docker compose exec -T --user "${runtime_user}" hermes-webui bash -lc '
set -e
export HERMES_HOME=/home/hermeswebui/.hermes
AGENT="${HERMES_HOME}/hermes-agent"
PY=/app/venv/bin/python
test -f "${AGENT}/pyproject.toml"
test -x "${PY}"
rm -f /app/venv/.deps_installed
export PATH="${HERMES_HOME}/tools/bin:${AGENT}/venv/bin:/home/hermeswebui/.local/bin:/usr/local/bin:${PATH}"
if command -v hermes >/dev/null 2>&1; then
  hermes pm repair 2>/dev/null || true
fi
if command -v uv >/dev/null 2>&1; then
  uv pip install --python "${PY}" -e "${AGENT}[all]" \
    --trusted-host pypi.org --trusted-host files.pythonhosted.org
else
  "${PY}" -m pip install -e "${AGENT}[all]"
fi
"${PY}" -c "import dotenv; from run_agent import AIAgent; print(\"AIAgent ok\")"
'
}
