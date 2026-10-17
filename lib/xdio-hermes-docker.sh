#!/usr/bin/env bash
# Helpers for Hermes Web UI Docker + agent (s4ndyp/scripts install/update).

# Return passwd name for HERMES_UID (create hermes-install if missing). Requires getent + runuser.
xdio_hermes_ensure_run_user() {
  local uid="${1:-1000}"
  local gid="${2:-1000}"
  local home="${3:-/var/lib/hermes-install}"
  local user gname

  user="$(getent passwd | awk -F: -v u="$uid" '$3 == u { print $1; exit }')"
  if [[ -n "$user" ]]; then
    printf '%s' "$user"
    return 0
  fi

  gname="$(getent group | awk -F: -v g="$gid" '$3 == g { print $1; exit }')"
  if [[ -z "$gname" ]]; then
    groupadd -g "$gid" hermes-install 2>/dev/null || groupadd hermes-install 2>/dev/null || true
    gname="$(getent group | awk -F: -v g="$gid" '$3 == g { print $1; exit }')"
    gname="${gname:-hermes-install}"
  fi

  user="hermes-install"
  if ! useradd -u "$uid" -g "$gname" -d "$home" -m -s /bin/bash "$user" 2>/dev/null; then
    useradd -u "$uid" -g "$gname" -d "$home" -M -s /bin/bash "$user" \
      || useradd -u "$uid" -d "$home" -M -s /bin/bash "$user" \
      || return 1
  fi
  install -d -o "$uid" -g "$gid" "$home" 2>/dev/null || install -d -o "$uid" "$home"
  printf '%s' "$user"
}

xdio_hermes_read_runtime_ids() {
  local app_dir="$1"
  local uid gid
  uid="$(grep -E '^UID=' "${app_dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d ' "')"
  gid="$(grep -E '^GID=' "${app_dir}/.env" 2>/dev/null | cut -d= -f2- | tr -d ' "')"
  uid="${uid:-1000}"
  gid="${gid:-1000}"
  printf '%s:%s' "$uid" "$gid"
}

# Host path to agent-managed Python (3.14 store / agent venv) after official install.sh.
xdio_hermes_resolve_agent_python() {
  local data="$1"
  local run_user="$2"
  local install_home="$3"
  local py json_out

  json_out="$(runuser -u "$run_user" -- env HERMES_HOME="$data" HOME="$install_home" \
    PATH="${install_home}/.local/bin:/usr/local/bin:${PATH}" bash -lc '
    if command -v hermes >/dev/null 2>&1; then
      hermes --print-runtime-command 2>/dev/null || true
    fi
  ')"
  if [[ -n "$json_out" ]]; then
    py="$(printf '%s' "$json_out" | python3 -c 'import json,sys
try:
  d=json.load(sys.stdin)
  print(d[0] if isinstance(d,list) and d else "")
except Exception:
  pass
' 2>/dev/null || true)"
    if [[ -n "$py" && -x "$py" ]]; then
      printf '%s' "$py"
      return 0
    fi
  fi

  shopt -s nullglob
  local candidates=(
    "${data}/hermes-agent/venv/bin/python"
    "${data}"/tools/python-*/bin/python3
    "${data}"/tools/python-*/bin/python
    "${data}"/tools/*/bin/python3
  )
  for py in "${candidates[@]}"; do
    [[ -x "$py" ]] || continue
    if runuser -u "$run_user" -- env HERMES_HOME="$data" "$py" -c "import dotenv" 2>/dev/null; then
      printf '%s' "$py"
      return 0
    fi
  done
  return 1
}

xdio_hermes_host_to_container_path() {
  local data="$1"
  local host_path="$2"
  printf '%s' "${host_path/#${data}//home/hermeswebui/.hermes}"
}

xdio_hermes_patch_compose_env() {
  local compose_file="$1"
  if grep -q 'HERMES_WEBUI_AGENT_DIR=' "$compose_file" 2>/dev/null; then
    return 0
  fi
  sed -i '/HERMES_WEBUI_PASSWORD=\${HERMES_WEBUI_PASSWORD:-}/a\
      - HERMES_HOME=/home/hermeswebui/.hermes\
      - HERMES_WEBUI_AGENT_DIR=/home/hermeswebui/.hermes/hermes-agent\
      - HERMES_WEBUI_PYTHON=${HERMES_WEBUI_PYTHON:-}\
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

# Verify agent import using HERMES_WEBUI_PYTHON (agent store) or WebUI venv fallback.
xdio_hermes_docker_link_agent() {
  local app_dir="$1"
  local runtime_user
  runtime_user="$(xdio_hermes_read_runtime_ids "$app_dir")"
  cd "$app_dir" || return 1
  docker compose exec -T --user "${runtime_user}" hermes-webui bash -lc '
set -e
export HERMES_HOME=/home/hermeswebui/.hermes
AGENT="${HERMES_HOME}/hermes-agent"
WEBUI_PY=/app/venv/bin/python
PY="${HERMES_WEBUI_PYTHON:-$WEBUI_PY}"
test -f "${AGENT}/pyproject.toml"
test -x "${PY}"
export PATH="${HERMES_HOME}/tools/bin:${AGENT}/venv/bin:/home/hermeswebui/.local/bin:/usr/local/bin:${PATH}"
if command -v hermes >/dev/null 2>&1; then
  hermes pm repair 2>/dev/null || true
fi
if [[ "${PY}" == "${WEBUI_PY}" ]]; then
  rm -f /app/venv/.deps_installed
  if command -v uv >/dev/null 2>&1; then
    uv pip install --python "${PY}" python-dotenv \
      --trusted-host pypi.org --trusted-host files.pythonhosted.org
    uv pip install --python "${PY}" -e "${AGENT}[all]" \
      --trusted-host pypi.org --trusted-host files.pythonhosted.org
  else
    "${PY}" -m pip install python-dotenv
    "${PY}" -m pip install -e "${AGENT}[all]"
  fi
fi
"${PY}" -c "import dotenv; from run_agent import AIAgent; print(\"AIAgent ok on ${PY}\")"
'
}
