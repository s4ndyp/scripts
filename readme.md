# s4ndyp/scripts — xdio scripts (Proxmox LXC)

Eigen Proxmox-installatiescripts in de stijl van [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE): één LXC per app, Docker in de container, applicatie klaar na het script. De engine blijft `community-scripts/core`; banner en tags zijn **xdio scripts**.

## Netwerk (Default Install)

Bij **Default Install**, **App Defaults** (zonder `var_net`) en **Generated** zet `lib/xdio.func` (alle app-scripts) automatisch:

| Instelling | Waarde |
|------------|--------|
| IPv4 | `10.5.0.<CTID>/16` |
| Gateway | `10.5.0.1` |
| DNS | `10.5.0.110`, `10.5.0.111` |
| VLAN (vmbr0) | **5** |

Uitschakelen: `export XDIO_STATIC_NET=0` vóór het script. Andere waarden: `XDIO_NET_PREFIX`, `XDIO_GATEWAY`, `XDIO_DNS`, `XDIO_VLAN`, of `var_*` via **Advanced** / User defaults.

**Branding (Notes + MOTD):** optioneel `XDIO_PROVIDER_NAME`, `XDIO_PROVIDER_GITHUB`, en voor de install-scriptlink in Notes `XDIO_SCRIPT_URL` (anders `…/blob/main/<app>/<app>.sh` in `s4ndyp/scripts`).

## Proxmox-host — alle scripts

Voer uit in de shell op je **Proxmox-node** (Default Install in het menu):

**WasmMe** (site :80, admin :8080)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"
```

**FinancePro**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/financepro/financepro.sh)"
```

**TrackNote**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/tracknote/tracknote.sh)"
```

**TinyNote**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/tinynote/tinynote.sh)"
```

**AssetVault**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/assetvault/assetvault.sh)"
```

**DynCompare** (app :80, sync :8080)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/dyncompare/dyncompare.sh)"
```

**Fileshare** (build uit git in de LXC, geen GHCR)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/fileshare/fileshare.sh)"
```

Zelfde Proxmox-uitleg voor in [fileshare/readme.md](https://github.com/s4ndyp/fileshare/blob/main/readme.md): [fileshare/README-proxmox-section.md](fileshare/README-proxmox-section.md).

**Hermes** (Web UI + agent in één container, build uit git — [nesquena/hermes-webui](https://github.com/nesquena/hermes-webui))

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/hermes/hermes.sh)"
```

Optioneel vóór install op de host: `HERMES_WEBUI_PASSWORD=…` (anders willekeurig wachtwoord in `~/hermes.creds`). De install draait eerst de **officiële** [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) `install.sh` naar `/opt/hermes-data/hermes-agent` (zelfde als `bootstrap.py`), daarna Docker Web UI. Standaard resources: **2 CPU, 4 GB RAM, 24 GB disk**.

Private **GHCR**-images: log eerst in op de Proxmox-host:

```bash
export GHCR_TOKEN="ghp_..."
```

```bash
export GHCR_USERNAME="s4ndyp"
```

Daarna het install-commando van de app, bijvoorbeeld WasmMe:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/s4ndyp/scripts/main/wasmme/wasmme.sh)"
```

Standaard resources: 1 CPU, 1 GB RAM, 8 GB disk (Fileshare: **2 CPU, 2 GB RAM, 10 GB disk**; Hermes: **2 CPU, 4 GB RAM, 24 GB disk** — agent + Docker build). Debian 13, unprivileged LXC.

## Apps

| App | Repo | URL na install |
|-----|------|----------------|
| WasmMe | [wasmme](https://github.com/s4ndyp/wasmme) | `:80` site, `:8080` admin |
| FinancePro | [financepro](https://github.com/s4ndyp/financepro) | `http://<ip>` |
| TrackNote | [tracknote](https://github.com/s4ndyp/tracknote) | `http://<ip>` |
| TinyNote | [tinynote](https://github.com/s4ndyp/tinynote) | `http://<ip>` |
| AssetVault | (nog geen public repo) | `http://<ip>` |
| DynCompare | [dyncompare](https://github.com/s4ndyp/dyncompare) | `:80` app, `:8080` sync |
| Fileshare | [fileshare](https://github.com/s4ndyp/fileshare) | `http://<ip>` (git build) |
| Hermes | [hermes-webui](https://github.com/nesquena/hermes-webui) | `http://<ip>` (Web UI, wachtwoord in `~/hermes.creds`) |

**AssetVault:** als `s4ndyp/assetvault` nog niet bestaat, gebruikt het install-script een ingebouwde compose (`ghcr.io/s4ndyp/assetvault:latest`).

## Gedeelde library

| Bestand | Doel |
|---------|------|
| `lib/xdio.func` | Figlet-banner, tag `xdio-script`, statisch netwerk, Proxmox **Notes** (xdio i.p.v. community-scripts.org) |
| `lib/xdio-compose-install.sh` | GHCR-login + docker compose pull/up (install-scripts) |
| `lib/xdio-motd.sh` | LXC-login: “Provided by: **Xdio scripts**” → [s4ndyp/scripts](https://github.com/s4ndyp/scripts) |

Elk app-script sourced `lib/xdio.func` **na** `build.func`.

In elke eigen LXC wordt de hoofdapp op **poort 80** bereikbaar (compose-poort wordt bij install aangepast), behalve WasmMe en DynCompare (extra service op **8080**).

## Structuur

| Pad | Doel |
|-----|------|
| `{app}/{app}.sh` | Aanroepen **op de Proxmox-host** (maakt LXC + installatie) |
| `ct/{app}.sh` | Pad voor **`update`** in de LXC (community-scripts helper; wijst door naar `{app}/{app}.sh`) |
| `install/{app}-install.sh` | Installatie binnen de LXC (wordt door de engine opgehaald; naam moet `{app}-install` zijn) |

Nieuwe app toevoegen: kopieer een bestaand voorbeeld, pas `APP`, tags en resources aan, en zet de install-logica in `install/jouapp-install.sh`.

## Update in de container

In de LXC: **`update`**, of handmatig:

**WasmMe**

```bash
cd /opt/wasmme && docker compose pull && docker compose up -d
```

**FinancePro**

```bash
cd /opt/financepro && docker compose pull && docker compose up -d
```

**TrackNote**

```bash
cd /opt/tracknote && docker compose pull && docker compose up -d
```

**TinyNote**

```bash
cd /opt/tinynote && docker compose pull && docker compose up -d
```

**AssetVault**

```bash
cd /opt/assetvault && docker compose pull && docker compose up -d
```

**DynCompare**

```bash
cd /opt/dyncompare && docker compose pull && docker compose up -d
```

**Fileshare** (git pull + rebuild)

```bash
cd /opt/fileshare && git pull --ff-only && docker compose build && docker compose up -d
```

**Hermes** (git pull + rebuild)

```bash
cd /opt/hermes-webui && git pull --ff-only && docker compose build && docker compose up -d
```

**Hermes — “AIAgent not available”** (in de LXC, agent editable in WebUI-venv):

```bash
cd /opt/hermes-webui
docker compose exec -T hermes-webui bash -lc 'rm -f /app/venv/.deps_installed; uv pip install --python /app/venv/bin/python -e /home/hermeswebui/.hermes/hermes-agent[all]; /app/venv/bin/python -c "from run_agent import AIAgent; print(\"ok\")"'
docker compose restart hermes-webui
```

Credentials-overzicht in de container: `~/<app>.creds` (bijv. `~/dyncompare.creds`).
