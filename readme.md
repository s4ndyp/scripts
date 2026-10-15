# s4ndyp/scripts — xdio scripts (Proxmox LXC)

Eigen Proxmox-installatiescripts in de stijl van [community-scripts/ProxmoxVE](https://github.com/community-scripts/ProxmoxVE): één LXC per app, Docker in de container, applicatie klaar na het script. De engine blijft `community-scripts/core`; banner en tags zijn **xdio scripts**.

## Netwerk (default install)

Bij **Default Install**, **App Defaults** (zonder `var_net`) en **Generated** krijgt elke LXC automatisch:

| Instelling | Waarde |
|------------|--------|
| IPv4 | `10.5.0.<CTID>/16` (CTID = LXC-nummer) |
| Gateway | `10.5.0.1` |
| DNS | `10.5.0.110`, `10.5.0.111` (`pct -nameserver`, tenzij `var_ns` gezet) |

Zonder `var_ns` zet community-scripts **geen** DNS op de LXC; bij statisch IP is `/etc/resolv.conf` dan vaak leeg of onbruikbaar voor apt/docker. xdio vult daarom bovenstaande DNS in zodra er een statisch IPv4-adres wordt gebruikt.

Zet `var_net` in User/App defaults of kies **Advanced Install** voor DHCP of een ander adres. Uitschakelen: `export XDIO_STATIC_NET=0` vóór het script. Andere DNS: `export XDIO_DNS="10.5.0.110 10.5.0.111"` of `var_ns=...` in defaults.

**Connectivity test:** de engine pingt **1.1.1.1 / 8.8.8.8** (ICMP). Als je netwerk geen ping naar het internet toelaat, krijg je een waarschuwing terwijl IP/gateway/DNS wél kloppen — de installatie gaat door.

Optioneel in `default.vars` op de Proxmox-host: `var_gateway=10.5.0.1` (zie `defaults/xdio.vars.example`).

## Gedeelde library

| Bestand | Doel |
|---------|------|
| `lib/xdio.func` | ASCII-banner, tag `xdio-script`, vast IP-schema |

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
