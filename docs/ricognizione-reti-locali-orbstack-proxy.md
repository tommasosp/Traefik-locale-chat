# Ricognizione — reti Docker locali (OrbStack) e proxy nel workspace Chat

Documento **derivato dai compose e dai file Traefik nel workspace** `Chat/` (RealTimeChat, Club dei presidenti, SuperAdmin, Authentik clone).  
Aggiorna la sezione «runtime» quando cambiano stack o host.

**Aggiorna anche** il documento operativo strutturato **[`docker_networks_runtime.md`](docker_networks_runtime.md)** (Fase 8) per procedure, troubleshooting e comandi; qui restano **tabelle dichiarative** e note OrbStack dove non si duplica contenuto incoerente.

---

## 1. Reti Docker nominate nei compose (dichiarativo)

| Rete (nome Docker) | Dove è definita | `external` | Servizi / ruolo |
|--------------------|-----------------|------------|-------------------|
| **`chat_edge`** | `Traefik-locale-chat/infra-local/networks.local.manifest` (riga **`chat_edge`**); `Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`; `Traefik-locale-chat/infra-local/docker-compose.club-chat-edge.attach.yml`; `Traefik-locale-chat/infra-local/docker-compose.rtc-chat-edge.attach.yml`; `Traefik-locale-chat/infra-local/docker-compose.superadmin-chat-edge.attach.yml` | **sì** nei compose **`external: true`** con `name: chat_edge`; creazione prima dello **`up`** incaricata a **`Traefik-locale-chat/scripts/docker-networks-preflight.sh`** che legge il manifest (`local`; opzione `--with-legacy-edge` per altre reti legacy) |
| **`rete_chat`** | `RealTimeChat/infra/docker-compose.yml` | no (creata dallo stack `realtime_chat`) | `postgres`, `redis`, `otel-collector`, `backend`; in dev anche `minio`, `minio-init`; overlay RTC/coturn/e2e agganciano qui |
| **`rete_per_instradamento`** | `RealTimeChat/infra/docker-compose.prod.yml`, **`RealTimeChat/infra/docker-compose.prod.images.yml`**, `RealTimeChat/infra/docker-compose.rtc-media-prod.yml`; `club_dei_presidenti/docker/docker-compose.yml`; `SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml`, `docker-compose.traefik-local.yml`; **`SuperAdmin-App-per-RealTimeChat/traefik-local/docker-compose.yml`** | **sì** (`external: true` nei file indicati dove compare il blocco `networks`) | Compose prod/lab con label **`traefik.*`** (dettaglio per servizio nei rispettivi YAML). Locale con **`docker-compose.traefik-local.yml`**: **`app`** e alias **`superadminappchat`** su questa rete. |
| **`rete_club_dei_presidenti`** | `club_dei_presidenti/docker/docker-compose.yml` | **sì** | DB Club (`club_mysql`) — rete dedicata dati |
| **`rete_redis`** | `club_dei_presidenti/docker/docker-compose.yml` | **sì** | Redis condiviso (profilo «prod-like» Club) |
| **`club_dei_presidenti_local`** | `club_dei_presidenti/docker/docker-compose.local.yml` | no | Stack locale OrbStack: `redis`, `club_mysql`, `app` (senza Traefik nel compose) |
| **`rete_superadmin_app_chat`** | `SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml` | no | `db`, `app` SuperAdmin |
| **`rete_per_instradamento`** (definita nel merge locale) | `SuperAdmin-App-per-RealTimeChat/docker-compose.local-ingress.yml` — sotto **`networks.rete_per_instradamento`** con **`name: rete_per_instradamento`**, senza **`external`** | **no** | Stesso YAML aggiunge servizio **`traefik`** e collega **`app`** alla rete sopra (`services.app.networks` nel file). |
| **`authentik_internal`** | `Authentik-server-login/docker-compose.yml` | no | `postgresql`, `redis`, `worker` Authentik |
| **`rete_authentik`** | `Authentik-server-login/docker-compose.yml` | **sì** | Espone `server` Authentik verso Traefik VPS (`traefik.docker.network=rete_authentik`) |

Reti di progetto Compose senza nome globale esplicito aggiuntivo:

- **`club_traefik_local_default`** — **`name: club_traefik_local`** in `club_dei_presidenti/docker/traefik-local/docker-compose.yml`; assenza di blocco `networks:` in quel file sul servizio → rete progetto Compose predefinita; nome sul motore tipicamente **`club_traefik_local_default`**.
- **`superadminappchat_rete_superadmin_app_chat`** — `name: superadminappchat` in `SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml` + chiave rete **`rete_superadmin_app_chat`** senza `name:` sotto quel blocco → nome Docker **`{ progettoCompose }_{ chiaveRete }`** coerente con la convenzione Docker Compose (**`superadminappchat_rete_superadmin_app_chat`** quando il progetto effettivo è **`superadminappchat`**).

---

## 2. Proxy e terminatori TLS nel repo

### 2.0 Traefik target unificato (`chat_local_ingress`, rete **`chat_edge`**)

Dichiarativo da **`Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`**: progetto Compose **`chat_local_ingress`**; immagine **`traefik:v3.6.13`**; **`command`** `--configFile=/etc/traefik/traefik.yml`; porta host **`${TRAEFIK_HOST_HTTPS:-443}`** → container **`443`**; volumi **`./traefik/traefik.yml`**, `./traefik/dynamic/` (cartella provider), `./certs` → **`/certs`**; **`networks: chat_edge`** con **`external: true`**.  
Static (**`Traefik-locale-chat/infra-local/traefik/traefik.yml`**): **`providers.file.directory`** su `/etc/traefik/dynamic` (directory, non singolo YAML come il Traefik Club legacy).  
Upstream e host TLS nei file **`Traefik-locale-chat/infra-local/traefik/dynamic/*.yml`**.

### 2.1 Traefik — Club locale (fallback, upstream **`host.docker.internal`**)

| Elemento | Percorso |
|----------|----------|
| Compose | `club_dei_presidenti/docker/traefik-local/docker-compose.yml` (`name: club_traefik_local`, immagine **`traefik:v3.6.13`**) |
| Static | `club_dei_presidenti/docker/traefik-local/traefik.yml`: **`providers.file.filename`** `/etc/traefik/dynamic.yml` (singolo file, **`watch: true`**) |
| Dynamic | `./dynamic.yml` nel repo → mount **`/etc/traefik/dynamic.yml`** (**`club_dei_presidenti/docker/traefik-local/dynamic.yml`**) |

**Upstream (valori dai `servers.url` di `dynamic.yml`):**

- `clubdeipresidenti.loc` → **`http://host.docker.internal:8084`**
- `phoenix.clubdeipresidenti.loc` → **`http://host.docker.internal:4000`**
- `s3.clubdeipresidenti.loc` → **`http://host.docker.internal:9000`**
- `media.clubdeipresidenti.loc` → **`http://host.docker.internal:4443`**

**Porte / volumi compose:** **`${TRAEFIK_HOST_HTTPS:-443}:443`** sul servizio **`traefik`**; **`extra_hosts`** `host.docker.internal:host-gateway`; volume **`${MKCERT_CERT_DIR}:/certs:ro`**.

### 2.2 Traefik — SuperAdmin locale (legacy)

| Elemento | Percorso |
|----------|----------|
| Compose standalone | `SuperAdmin-App-per-RealTimeChat/traefik-local/docker-compose.yml` (`traefik:v3.6.4`, monta **`./dynamic`**, argomenti CLI `--providers.file.directory=/etc/traefik/dynamic`) |
| Dynamic | `SuperAdmin-App-per-RealTimeChat/traefik-local/dynamic/superadmin-app-chat.yml` |
| Merge con app + Traefik | `SuperAdmin-App-per-RealTimeChat/docker-compose.local-ingress.yml` — servizi **`traefik`** e **`app`**; mount dynamic **`./traefik-local/dynamic`** |
| Solo `app` sulla rete edge | `SuperAdmin-App-per-RealTimeChat/docker-compose.traefik-local.yml` — **nessun** servizio Traefik; solo **`app`** con alias **`superadminappchat`** su **`rete_per_instradamento`** (**`external: true`**) |

**Upstream (da `superadmin-app-chat.yml`):** **`http://superadminappchat:8000`**.  
**Porte host (standalone e `docker-compose.local-ingress.yml`):** **`127.0.0.1:80:80`**, **`127.0.0.1:443:443`**.  
**Rete:** **`rete_per_instradamento`** — **external** nel compose standalone e in **`docker-compose.traefik-local.yml`**; definita **non** external con **`name:`** in **`docker-compose.local-ingress.yml`** (vedi §1).

### 2.3 Traefik — produzione / lab (label Docker, non file statico nel repo)

Le label sono nei compose:

- **RealTimeChat** — `RealTimeChat/infra/docker-compose.prod.yml`, **`RealTimeChat/infra/docker-compose.prod.images.yml`**: `Host(${CHAT_PUBLIC_HOST})`, API/socket/admin_socket, redirect root → `CHAT_ROOT_REDIRECT_URL`, Let’s Encrypt.
- **rtc-media-node** — `RealTimeChat/infra/docker-compose.rtc-media-prod.yml`: `Host(${RTC_MEDIA_PUBLIC_HOST})` per `/ws`, `/health`, `/metrics`.
- **Club** — `club_dei_presidenti/docker/docker-compose.yml`: `clubdeipresidenti.presidentepro.it`.
- **SuperAdmin** — `SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml`: `superadminappchat.presidentepro.it`.
- **Authentik** — `Authentik-server-login/docker-compose.yml`: `auth.presidentepro.it`.

> Il **daemon Traefik di VPS / risorse comuni** non è in questo workspace; qui ci sono solo i **contratti** (label e reti).

### 2.4 Altri proxy

Nel workspace Chat **non** risultano compose che usano **nginx**, **Caddy** o **HAProxy** come servizio dedicato.  
**coturn** (`RealTimeChat/infra/docker-compose.coturn.yml`) è STUN/TURN, non reverse proxy HTTP.

### 2.5 Profili senza Traefik HTTP

- **`RealTimeChat/infra/docker-compose.attachments-e2e.yml`**: MinIO HTTP diretto su `rete_chat`; documentato esplicitamente come senza Traefik/TLS.

---

## 3. Conflitti tipici su OrbStack / macOS

- **Porta 443 host:** in **`infra-local/docker-compose.chat-local-ingress.yml`** la mappa è **`"${TRAEFIK_HOST_HTTPS:-443}:443"`** (default **443** sul host). **Traefik Club** legacy usa la stessa forma di variabile. **Traefik SuperAdmin** standalone / **`docker-compose.local-ingress`** usano **`127.0.0.1:443:443`** (bind solo loopback nei file YAML). Non avviare due Traefik sullo stesso **host:port** effettivamente in ascolto.
- **`TRAEFIK_HOST_HTTPS`:** variabile nei compose **`club_traefik_local`** e **`chat_local_ingress`** (porte host pubblicate sul servizio **`traefik`**; leggere i blocchi **`ports:`** nei rispettivi YAML).
- **`rete_per_instradamento`** con **`external: true`**: i compose che dichiarano quel blocco **non** creano la rete — va esistente sul motore (vedi **`SuperAdmin-App-per-RealTimeChat/traefik-local/docker-compose.yml`** commento riga pré-requisito) **oppure** creata dall’overload **`docker-compose.local-ingress.yml`** con **`networks.rete_per_instradamento.name`** (**senza `external`**, vedi §1).

---

## 4. Host locali documentati (`/etc/hosts`)

| Host | Dove compaiono nei sorgenti (router Traefik ingress target) |
|------|------------------------------------------------------------|
| `clubdeipresidenti.loc`, `phoenix.clubdeipresidenti.loc`, `s3.clubdeipresidenti.loc`, `media.clubdeipresidenti.loc` | `Traefik-locale-chat/infra-local/traefik/dynamic/10-chat-workshop.routes.yml` (**`http.routers`**, campo **`rule: Host(...)`**) |
| `superadminappchat.local` | `Traefik-locale-chat/infra-local/traefik/dynamic/20-superadmin-app-chat.yml` (**`http.routers`**, **`rule: Host(...)`**) |

Gli **stessi** valori **`Host(...)`** compaiono anche nel Traefik legacy Club **`club_dei_presidenti/docker/traefik-local/dynamic.yml`** (percorsi servizio diversi: **`host.docker.internal`**, §2.1).

Risoluzione **`127.0.0.1`** su `/etc/hosts` rimane configurazione macchina (**non** nei compose); vedi **`docs/docker_networks_runtime.md` §7** per uso operativo.

---

## 5. Nomi di rete attesi (solo da file in `Chat/`)

Elenco **non** esaustivo del motore Docker: sono i **nomi espliciti** (`name:`), le **chiavi** reti e le **convenzioni** ricavabili dai compose/manifest sotto **`Chat/`** (per lo stato reale usare **`docker network ls`** sul proprio host):

- **`bridge`**, **`host`**, **`none`** — reti predefinite del demone (non definite nei compose applicativi).
- **`chat_edge`** — manifest **`infra-local/networks.local.manifest`** + **`external`** negli overlay ingress.
- **`club_dei_presidenti_local`** — `club_dei_presidenti/docker/docker-compose.local.yml` (`networks.club.name`).
- **`club_traefik_local_default`** — progetto **`club_traefik_local`** senza `networks:` custom (vedi §1).
- **`rete_authentik`**, **`authentik_internal`** — `Authentik-server-login/docker-compose.yml`.
- **`rete_chat`** — `RealTimeChat/infra/docker-compose.yml` (`networks.rete_chat.name`).
- **`rete_club_dei_presidenti`**, **`rete_redis`** — `club_dei_presidenti/docker/docker-compose.yml` (reti **external**).
- **`rete_per_instradamento`** — compare come **external** in diversi compose e come rete **definita** in **`SuperAdmin-App-per-RealTimeChat/docker-compose.local-ingress.yml`** (vedi §1).
- **`superadminappchat_rete_superadmin_app_chat`** — convenzione sul nome Docker per la chiave **`rete_superadmin_app_chat`** con progetto **`superadminappchat`** (vedi §1).

---

## 6. ICE mediasoup — `docker-compose.rtc-dev` (OrbStack / macOS host)

Fonte comportamento: **`RealTimeChat/infra/docker-compose.rtc-dev.yml`**, **`RealTimeChat/rtc-media-node/src/config.js`**, **`mediasoup-worker.js`** (`listenIps` **`0.0.0.0`**, **`announcedIp`** da env).

| Aspetto | Allineamento operativo |
|--------|-------------------------|
| **UDP host→container** | Range **`${MEDIASOUP_RTC_MIN_PORT}-${MAX}`** mappato come **`…/udp`**; le porte nei candidati ICE del browser devono essere **nello stesso intervallo** pubblicato sul host. |
| **TCP ICE (fallback)** | mediasoup offre anche candidati **TCP passive** sulla stessa finestra — il compose pubblica **`40000-40050:40000-40050/tcp`** oltre a **`/udp`**, così il fallback ICE-TCP dall’host non resta vuoto. |
| **`host.docker.internal` come announced IP** | Spesso il browser **non** completa ICE/UDP verso quel nome anche se TLS/WSS passa tramite Traefik; sintomo tipico sul nodo: **`iceState` `new`**, **`dtlsState` `new`**, **`iceSelectedTuple` null**. |
| **Test progressivo announced IP** | **A)** `127.0.0.1` — browser sulla **stessa macchina** del daemon Docker, UDP/TCP pubblicati sul loopback host. **B)** IP **LAN del Mac** (indirizzo **`192.168…`** reale sulla tua rete, non placeholder operativo inventato nel doc) — client su altri device nella stessa rete. **C)** `host.docker.internal` solo dopo verifica DNS/UDP reale dalla macchina client. Override: **`MEDIASOUP_ANNOUNCED_IP`** oppure **`RTC_ANNOUNCED_IP`** (precedenza in `config.js`: prima `MEDIASOUP_*`). |
| **Signaling vs RTP** | WSS può essere **`https://media.…`/Traefik** (`call_media_nodes.base_url`); i candidati RTP restano **`announcedIp` + porta UDP/TCP mediasoup** — non transitano dall’ingress HTTPs. |

All’avvio il nodo emette **`[rtc-media-node-boot]`** (JSON): env sopra risolti, **`listenIps`** effettivi, partizioni porte worker, promemoria sul mapping compose.

---

## 7. Riferimenti file

| Area | File chiave |
|------|-------------|
| Ingress workshop (`chat_edge`) | `Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`, `Traefik-locale-chat/infra-local/docker-compose.club-chat-edge.attach.yml`, `Traefik-locale-chat/infra-local/docker-compose.rtc-chat-edge.attach.yml`, `Traefik-locale-chat/infra-local/docker-compose.superadmin-chat-edge.attach.yml`, `Traefik-locale-chat/infra-local/networks.local.manifest`, `Traefik-locale-chat/scripts/docker-networks-preflight.sh`, `Traefik-locale-chat/infra-local/traefik/`, `Traefik-locale-chat/infra-local/certs/README.md` |
| RealTimeChat base | `RealTimeChat/infra/docker-compose.yml`, `RealTimeChat/infra/docker-compose.dev.yml`, `RealTimeChat/infra/docker-compose.prod.yml`, `RealTimeChat/infra/docker-compose.prod.images.yml` |
| RTC / media prod | `RealTimeChat/infra/docker-compose.rtc-dev.yml`, `RealTimeChat/infra/docker-compose.rtc-media-prod.yml`, `RealTimeChat/infra/docker-compose.rtc-multinode.lab.yml` |
| Club prod | `club_dei_presidenti/docker/docker-compose.yml` |
| Club locale | `club_dei_presidenti/docker/docker-compose.local.yml` |
| Club Traefik | `club_dei_presidenti/docker/traefik-local/*` |
| SuperAdmin | `SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml`, `docker-compose.local-ingress.yml`, `docker-compose.traefik-local.yml`, `traefik-local/*` |
| Authentik | `Authentik-server-login/docker-compose.yml` |

---

*Generazione: solo lettura dei file sotto la root **`Chat/`** (compose, Traefik static/dynamic, manifest, script preflight). Per lo stato runtime effettivo usare comandi Docker sul proprio host.*
