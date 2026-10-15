# s4ndyp/scripts — xdio scripts (Proxmox LXC)

Eigen Proxmox-installatiescripts in de stijl van [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE): één LXC per app, Docker in de container, applicatie klaar na het script. De engine blijft `community-scripts/core`; banner en tags zijn **xdio scripts**.

Netwerk gebruikt de **community-scripts defaults (DHCP op vmbr0)**. Statisch IP, gateway of DNS kun je desgewenst zelf instellen via **Advanced Install** of User/App defaults (`var_net`, `var_gateway`, `var_ns`).

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

## Apps

| App | Script | Repo | URL na install |
|-----|--------|------|----------------|
| WasmMe | `wasmme/wasmme.sh` | [wasmme](https://github.com/s4ndyp/wasmme) | `:80` site, `:8080` admin |
| FinancePro | `financepro/financepro.sh` | [financepro](https://github.com/s4ndyp/financepro) | `http://<ip>` |
| TrackNote | `tracknote/tracknote.sh` | [tracknote](https://github.com/s4ndyp/tracknote) | `http://<ip>` |
| TinyNote | `tinynote/tinynote.sh` | [tinynote](https://github.com/s4ndyp/tinynote) | `http://<ip>` |
| AssetVault | `assetvault/assetvault.sh` | (nog geen public repo) | `http://<ip>` |

Voorbeeld FinancePro:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/financepro/financepro.sh)"
```

**AssetVault:** als `s4ndyp/assetvault` nog niet bestaat, gebruikt het install-script een ingebouwde compose (`ghcr.io/s4ndyp/assetvault:latest`). Override: `ASSETVAULT_COMPOSE_URL=…` op de Proxmox-host (wordt niet automatisch doorgegeven aan de LXC — zet desnoods de compose-URL in een aangepast install-script of publiceer de repo).

## WasmMe

Webbeheer voor WASM/static sites ([s4ndyp/wasmme](https://github.com/s4ndyp/wasmme)): admin op poort **8080**, gepubliceerde site op poort **80**. Vervangt Dockhand + handmatig plakken van `docker-compose.yml`.

### Installatie (Proxmox shell)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"
```

Standaard resources: 1 CPU, 1 GB RAM, 8 GB disk, Debian 13, unprivileged LXC.

### GHCR (private packages)

Images: `ghcr.io/s4ndyp/wasmme:latest` en `ghcr.io/s4ndyp/wasmme-public:latest`. Zet het package **public**, of log in vóór het script:

```bash
export GHCR_TOKEN="ghp_..."   # of een PAT met read:packages
export GHCR_USERNAME="s4ndyp" # optioneel
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"
```

### Update (in bestaande LXC)

Start het WasmMe-script opnieuw op de Proxmox-host en kies **Update** in het menu, of in de container:

```bash
cd /opt/wasmme && docker compose pull && docker compose up -d
```

### Na installatie

- Site: `http://<container-ip>`
- Admin: `http://<container-ip>:8080`
- Credentials/overzicht: `~/wasmme.creds` in de container
