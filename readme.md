# s4ndyp/scripts — xdio scripts (Proxmox LXC)

Eigen Proxmox-installatiescripts in de stijl van [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE): één LXC per app, Docker in de container, applicatie klaar na het script. De engine blijft `community-scripts/core`; banner en tags zijn **xdio scripts**.

Netwerk gebruikt de **community-scripts defaults (DHCP op vmbr0)**. Statisch IP, gateway of DNS kun je desgewenst zelf instellen via **Advanced Install** of User/App defaults (`var_net`, `var_gateway`, `var_ns`).

## Gedeelde library

| Bestand | Doel |
|---------|------|
| `lib/xdio.func` | ASCII-banner (Xdio scripts), tag `xdio-script` |

Elk app-script sourced `lib/xdio.func` **na** `build.func`.

## Structuur

| Pad | Doel |
|-----|------|
| `{app}/{app}.sh` | Aanroepen **op de Proxmox-host** (maakt LXC + installatie) |
| `install/{app}-install.sh` | Installatie binnen de LXC (wordt door de engine opgehaald; naam moet `{app}-install` zijn) |

Nieuwe app toevoegen: kopieer het WasmMe-voorbeeld, pas `APP`, tags en resources aan, en zet de install-logica in `install/jouapp-install.sh`.

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
