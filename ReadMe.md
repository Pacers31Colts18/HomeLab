# Home Lab Configuraiton

## Domain Configuration
- Name: joeloveless.net
  - Provider: Cloudflare
  - Used for: Homelab Services
  - API Token Permissions: DNS Zone Read/Edit
  - Notes:
    - Put token into .env file (Caddy)
    - Allows DNS certificate challenge with Lets Encrypt
- Name: joeloveless.com
  - Provider: Squarespace
  - Used for: Website, Intune, AD/SCCM lab
- Name: joeloveless.dev
  - Provider: Squarespace
  - Used for: N/A

## Networking Configuration
### Starlink

### Eero
- Custom DNS:
  - Ipv4 Primary:
    - 192.168.4.208
    - 192.168.4.125
### Technitium
- Hostname: dns01
  - Role: Primary DNS Server/Ad Blocker
  - Type: Proxmox LXC
  - IP Address: 192.168.4.208
  - FQDN: dns01.joeloveless.net
  - Hardware: Intel NUC
  - Notes:
    - Tailscale:
      - Subnet Router
        - https://tailscale.com/kb/1019/subnets
      - Exit Node
        - https://tailscale.com/kb/1103/exit-nodes?tab=linux
- Hostname: dns02
  - Type: Docker Container
  - IP Address: 192.168.4.125
  - FQDN: dns02.joeloveless.net
  - Hardware: UGreen NAS

- Forwarder Zone: joeloveless.net

|Name    |Type|TTL |Data         |
|--------|----|----|-------------|
|service   |A   |3600|192.168.4.229|

#### Reverse Proxy
- Hostname: caddy01
  - Role: Secondary DNS Server/Ad Blocker
  - Type: Proxmox LXC
  - IP Address: 192.168.4.229
  - FQDN: N/A
#### Tailscale
- dns03
  - Advertises subnet routes
  - Exit node
- DNS Settings
  - dns03 IP address as global name server
    - Use with exit nodes
  - Search Domains:
    - joeloveless.net
  - MagicDNS
    - Disabled
- Allows resolving of FQDN's when connected via Tailscale

## Intel NUC
### Proxmox Server
- IP Address: 192.168.4.2
- FQDN: proxmox.joeloveless.net
#### LXC Containers
- Name: dns01
  - Role: Primary DNS Server
  - IP Address: 192.168.4.208
  - FQDN: dns01.joeloveless.net
- Name: dns03
  - Role: Third DNS Server - Tailscale
  - IP Address: 192.168.4.219
  - FQDN: dns03.joeloveless.net
- Name: freshrss
  - Role: RSS Reader
  - IP Address: 192.168.4.55
  - FQDN: rss.joeloveless.net
- Name: karakeep
  - Role: Bookmark Manager
  - IP Address: 192.168.4.202
  - FQDN: karakeep.joeloveless.net
- Name: joplin-server
  - Role: Note Taking
  - IP Address: 192.168.4.205
  - FQDN: joplin.joeloveless.net
- Name: caddy
  - Role: Reverse Proxy
  - IP Address: 192.168.4.229
  - FQDN: N/A
  - Notes:
    - Caddyfile
      - /etc/caddy/Caddyfile
    - Environmental Variable
      - /etc/caddy
```bash
sudo nano Caddyfile
sudo nano .env
```

#### Virtual Machines
- Name: homeassistant
  - Role: Home Assistant
  - IP Address: 192.168.4.4
  - FQDN: homeassistant.joeloveless.net
## UGreen NAS
- Hardware: 8TB Seagate Ironwolf (2x)
- IP Address: 192.168.4.125
- FQDN: nas.joeloveless.net
### Docker
#### Containers
- Name: portainer
  - Role: Docker management
  - Network Type: Bridge
  - IP Address: 172.17.0.2
  - FQDN: portainer.joeloveless.net
- Name: bazarr
  - Role: Subtitles
  - Network Type: Bridge
  - IP Address: 172.26.0.2
  - Port: 6767
  - FQDN: bazarr.joeloveless.net
  - Notes:
    - Providers:
      - Opensubtitles.org
- Name: lidarr
  - Role: Music
  - Network Type: Bridge
  - IP Address: 172.18.0.2
  - Port: 8686
  - FQDN: lidarr.joeloveless.net
- Name: nzbget
  - Role: Usenet
  - Network Type: Bridge
  - IP Address: 172.19.0.2
  - Port: 6789
  - FQDN: nzbget.joeloveless.net
  - Notes:
    - NewsServers:
      - news.eweka.nl
      - news.newsdemon.nl
- Name: prowlarr
  - Role: Arr syncing
  - Network Type: Bridge
  - IP Address: 172.20.0.2
  - Port: 9696
  - FQDN: prowlarr.joeloveless.net
  - Notes:
    - Indexers
      - https://nzb.su
        - Yearly
      - https://nzbfinder.ws
        - Yearly
      - https://nzbgeek.info
        - Lifetime
- Name: radarr
  - Role: Movies
  - Network Type: Bridge
  - IP Address: 192.168.4.2
  - Port: 7878
  - FQDN: radarr.joeloveless.net
- Name: sonarr
  - Role: Shows
  - Network Type: Bridge
  - IP Address: 172.25.0.2
  - Port: 8989
  - FQDN: sonarr.joeloveless.net
- Name: technitium
  - Role: Seconary DNS Server
  - Network Type: Host
  - IP Address: 192.168.4.125
  - FQDN: dns02.joeloveless.net
- Name: immich (multiple containers)
  - Role: Photos
  - Network Type: Bridge
  - IP Address: 172.23.0.5
  - Port: 2283
  - FQDN: immich.joeloveless.net
- Name: linuxserver_plex-1
  - Role: Media Server
  - Network Type: Host
  - IP Address: 192.168.4.125
  - Port: 32000
  - FQDN: plex.joeloveless.net
## Dell Optiplex 7020
- Operating System: Windows 11 Pro
- Role: Hyper-V
- Used for:
  - Active Directory
    - Hybrid Join
  - Configuration Manager
    - Co-Managed


