<!-- Copy-paste this section into https://github.com/s4ndyp/fileshare/blob/main/readme.md (replace old "Deploy op Proxmox" block). -->

## Deploy op Proxmox (LXC + Docker)

Gebruik het **Xdio**-installatiescript in [s4ndyp/scripts](https://github.com/s4ndyp/scripts) (zelfde stijl als de andere Proxmox LXC-apps: `community-scripts/core`, statisch netwerk, geen GHCR — deze repo wordt in de container gekloond en met `docker compose build` gebouwd).

Op de **Proxmox host** als root:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/fileshare/fileshare.sh)"
```

Standaard resources: **2 CPU**, **2 GB RAM**, **10 GB disk** (build heeft wat meer nodig dan een pure pull). De app luistert in de LXC op **poort 80** (`http://<container-ip>`).

**Update** in de container: `update`, of handmatig:

```bash
cd /opt/fileshare && git pull --ff-only && docker compose build && docker compose up -d
```

Optioneel andere fork/branch in de LXC (tijdens install): `FILESHARE_REPO_URL`, `FILESHARE_BRANCH`.

> Het script `scripts/proxmox-fileshare.sh` in deze repo is **verouderd**; gebruik bovenstaande URL uit **s4ndyp/scripts**.
