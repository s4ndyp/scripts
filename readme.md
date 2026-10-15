# s4ndyp/scripts — xdio scripts (Proxmox LXC)

Eigen Proxmox-installatiescripts in de stijl van [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE): één LXC per app, Docker in de container, applicatie klaar na het script. De engine blijft `community-scripts/core`; banner en tags zijn **xdio scripts**.

Netwerk gebruikt de **community-scripts defaults (DHCP op vmbr0)**. Statisch IP, gateway of DNS kun je desgewenst zelf instellen via **Advanced Install** of User/App defaults (`var_net`, `var_gateway`, `var_ns`).

## Proxmox-host — alle scripts

Voer uit in de shell op je **Proxmox-node** (Default Install in het menu):

```bash
# WasmMe — site :80, admin :8080
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"

# FinancePro
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/financepro/financepro.sh)"

# TrackNote
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/tracknote/tracknote.sh)"

# TinyNote
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/tinynote/tinynote.sh)"

# AssetVault
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/assetvault/assetvault.sh)"
```

Private **GHCR**-images: log eerst in op de Proxmox-host, daarna hetzelfde commando:

```bash
export GHCR_TOKEN="ghp_..."   # PAT met read:packages
export GHCR_USERNAME="s4ndyp" # optioneel
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"
```

Standaard resources (alle apps): 1 CPU, 1 GB RAM, 8 GB disk, Debian 13, unprivileged LXC.

## Apps

| App | Repo | URL na install |
|-----|------|----------------|
| WasmMe | [wasmme](https://github.com/s4ndyp/wasmme) | `:80` site, `:8080` admin |
| FinancePro | [financepro](https://github.com/s4ndyp/financepro) | `http://<ip>` |
| TrackNote | [tracknote](https://github.com/s4ndyp/tracknote) | `http://<ip>` |
| TinyNote | [tinynote](https://github.com/s4ndyp/tinynote) | `http://<ip>` |
| AssetVault | (nog geen public repo) | `http://<ip>` |

**AssetVault:** als `s4ndyp/assetvault` nog niet bestaat, gebruikt het install-script een ingebouwde compose (`ghcr.io/s4ndyp/assetvault:latest`).

## Gedeelde library

| Bestand | Doel |
|---------|------|
| `lib/xdio.func` | Figlet-banner met horizontaal regenboogverloop, tag `xdio-script` |
| `lib/xdio-compose-install.sh` | GHCR-login + docker compose pull/up (install-scripts) |
| `lib/xdio-motd.sh` | LXC-login: “Provided by: **Xdio scripts**” → [s4ndyp/scripts](https://github.com/s4ndyp/scripts) |

Elk app-script sourced `lib/xdio.func` **na** `build.func`.

In elke eigen LXC wordt de app op **poort 80** bereikbaar (compose-poort wordt bij install naar `80:…` gezet), behalve WasmMe (site 80, admin 8080).

## Structuur

| Pad | Doel |
|-----|------|
| `{app}/{app}.sh` | Aanroepen **op de Proxmox-host** (maakt LXC + installatie) |
| `install/{app}-install.sh` | Installatie binnen de LXC (wordt door de engine opgehaald; naam moet `{app}-install` zijn) |

Nieuwe app toevoegen: kopieer een bestaand voorbeeld, pas `APP`, tags en resources aan, en zet de install-logica in `install/jouapp-install.sh`.

## WasmMe (details)

Webbeheer voor WASM/static sites: admin op poort **8080**, gepubliceerde site op poort **80**.

### Update (bestaande LXC)

Script opnieuw op de host (menu **Update**), of in de container:

```bash
cd /opt/wasmme && docker compose pull && docker compose up -d
```

### Na installatie

- Site: `http://<container-ip>`
- Admin: `http://<container-ip>:8080`
- Overzicht: `~/wasmme.creds` in de container

## Overige apps — update in de container

```bash
cd /opt/financepro && docker compose pull && docker compose up -d
cd /opt/tracknote && docker compose pull && docker compose up -d
cd /opt/tinynote && docker compose pull && docker compose up -d
cd /opt/assetvault && docker compose pull && docker compose up -d
```

Credentials: `~/financepro.creds`, `~/tracknote.creds`, `~/tinynote.creds`, `~/assetvault.creds`.
