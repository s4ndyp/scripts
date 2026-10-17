#!/usr/bin/env bash
# Helpers for Hermes Web UI Docker + agent (s4ndyp/scripts install/update).

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
xdio_hermes_docker_link_agent() {
  local app_dir="$1"
  cd "$app_dir" || return 1
  docker compose exec -T hermes-webui bash -lc '
set -e
AGENT=/home/hermeswebui/.hermes/hermes-agent
PY=/app/venv/bin/python
test -f "$AGENT/pyproject.toml"
test -x "$PY"
# Retry init may have skipped agent deps when .deps_installed was stamped early.
rm -f /app/venv/.deps_installed
export PATH="/home/hermeswebui/.local/bin:/usr/local/bin:$PATH"
if command -v uv >/dev/null 2>&1; then
  uv pip install --python "$PY" -e "${AGENT}[all]" \
    --trusted-host pypi.org --trusted-host files.pythonhosted.org
else
  "$PY" -m pip install -e "${AGENT}[all]"
fi
"$PY" -c "from run_agent import AIAgent; print(\"AIAgent ok\")"
'
}
