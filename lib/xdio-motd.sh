#!/usr/bin/env bash
# Vervangt community-scripts MOTD-regel door Xdio scripts (LXC console / SSH login).

XDIO_PROVIDER_NAME="${XDIO_PROVIDER_NAME:-Xdio scripts}"
XDIO_PROVIDER_GITHUB="${XDIO_PROVIDER_GITHUB:-https://github.com/s4ndyp/scripts}"

_xdio_patch_motd_files() {
  local f
  for f in /etc/profile.d/00_lxc-details.sh /etc/motd; do
    [[ -f "$f" ]] || continue
    sed -i \
      -e "s/community-scripts ORG/${XDIO_PROVIDER_NAME}/g" \
      -e 's|https://github.com/community-scripts/ProxmoxVE|'"${XDIO_PROVIDER_GITHUB}"'|g' \
      "$f"
  done
}

if declare -f motd_ssh >/dev/null 2>&1; then
  eval "$(declare -f motd_ssh | sed '1s/motd_ssh/_xdio_cs_motd_ssh/')"
  motd_ssh() {
    _xdio_cs_motd_ssh "$@"
    _xdio_patch_motd_files
  }
fi
