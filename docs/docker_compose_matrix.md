# Matrice compose Docker — workspace `Chat/`

Ingresso HTTPS **ufficiale** in locale: **`Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`** sulla **443** host, certificati **`Traefik-locale-chat/infra-local/certs/`**, URL **`https://<host>`** senza porta per Club, Phoenix, S3, media, SuperAdmin — vedi **`docs/docker_networks_runtime.md` §5**. I compose Traefik **legacy** (Club `club_traefik_local`, SuperAdmin storici) restano nel repo solo come **fallback/debug** e **non** devono bindare la **443** quando l’ingress unificato è attivo.

Guida ai **profili**, **merge `-f`** e coesistenza con stack su **`rete_per_instradamento`** per scenari eccezionali.

Riferimenti incrociati: `docs/docker_network_inventory.md`, `docs/docker_network_target_architecture.md`, `docs/docker_networks_runtime.md`, overlay in `Traefik-locale-chat/infra-local/`.

Legenda **classificazione** (file o frammento): **KEEP** = resta punto di verità/canonical per uno scenario; **MERGE** = si usa solo combinato come `-f` aggiuntivo; **DEPRECATE** = sostituito sul piano locale dall’ingresso unificato, ma ancora avviabile in transizione; **DELETE LATER** = candidate a rimozione solo dopo migrazione completa degli scenari dipendenti (nessuna cancellazione in questa fase piano).

---

## Regola porta HTTPS (**443**)

Sul host deve esistere **al massimo un** Traefik con bind **443→443** (di norma **`chat_local_ingress-traefik-1`**). **`TRAEFIK_HOST_HTTPS`** su un’altra porta è solo per emergenze o confronti e **non** corrisponde agli URL ufficiali senza porta.

SuperAdmin **`docker-compose.local-ingress.yml`** (legacy) può pubblicare **`127.0.0.1:443`** — **non** combinarlo con **`chat_local_ingress`** sulla stessa **443** host.

---

## Scenari locali principali

### Scenario 1 — **Full stack locale** con Traefik **target** (`chat_local_ingress`)

Operare da **`Chat/`**.

1. **`chat_edge`** (preflight dalla root Chat):  
   `bash scripts/docker-networks-preflight.sh local`  
   Opzionale se servono anche stack SuperAdmin storici sulla stessa rete edge legacy: `--with-legacy-edge`.

2. Club (merge + attach **`chat_edge`**, da **`club_dei_presidenti/docker/`**):  
   `docker compose -f docker-compose.local.yml -f ../../Traefik-locale-chat/infra-local/docker-compose.club-chat-edge.attach.yml up -d --build`

3. RealTimeChat + dev + rtc + attach (da **`RealTimeChat/`**, servono **`MKCERT_CAROOT`**, `.env`):  
   `docker compose -f infra/docker-compose.yml -f infra/docker-compose.dev.yml -f infra/docker-compose.rtc-dev.yml -f ../Traefik-locale-chat/infra-local/docker-compose.rtc-chat-edge.attach.yml up -d --build`

4. SuperAdmin + attach (da **`SuperAdmin-App-per-RealTimeChat/`**, `--env-file` come da README del clone):  
   `docker compose --env-file docker/.env --env-file env/.env -f docker/docker-compose.yml -f docker-compose.dev.yml -f ../Traefik-locale-chat/infra-local/docker-compose.superadmin-chat-edge.attach.yml up -d --build`

5. **Prima** di alzare l’ingress: **`docker stop club_traefik_local-traefik-1`** (se presente) e ogni altro Traefik sulla **443** — vedi **`docs/docker_networks_runtime.md` §5.3**.  
6. Certificati: generare **`Traefik-locale-chat/infra-local/certs/cert.pem`** e **`cert-key.pem`** ( **`Traefik-locale-chat/infra-local/certs/README.md`** ).  
7. Ingress unificato (da **`Traefik-locale-chat/infra-local/`**):  
   `docker compose -f docker-compose.chat-local-ingress.yml up -d`

**Traefik attivo:** **solo** **`chat_local_ingress`** sulla **443** (URL **`https://…`** senza porta). Upstream sulla **`chat_edge`**: alias `club_app`, `rtc_backend`, `minio`:9000, `rtc_media`, `superadminappchat` — vedi dynamic in `Traefik-locale-chat/infra-local/traefik/dynamic/`.

**Reti chiave:** `chat_edge` (+ reti bridge interne `club_dei_presidenti_local`, `rete_chat`, `rete_superadmin_app_chat`). **NON** è richiesta `rete_per_instradamento` per questo percorso (salvo scegliere stack legacy SuperAdmin nel mix).

**Porte rilevanti (host):** dirette verso backend **8084** Club, **4000** Phoenix, **8001** SuperAdmin diretto (opzionale), MinIO **9000/9001**, rtc-media **4443** + UDP RTC; HTTPS browser → **443** verso **`chat_local_ingress`**.

---

### Scenario 2 — Club **solo** con Traefik legacy (`club_traefik_local`) *(fallback/debug)*

**Non** è il flusso standard del workspace quando si usa **`chat_local_ingress`**: tenere questo Traefik **spento** così la **443** resta libera.

Da **`club_dei_presidenti/docker`**: stack `docker-compose.local.yml` su **8084**; Traefik dalla directory **`docker/traefik-local/`**: `MKCERT_CERT_DIR=… docker compose up -d` (tipicamente con **`TRAEFIK_HOST_HTTPS`** diverso dalla **443** se l’ingress ufficiale è attivo).

**Traefik attivo:** legacy Club (`dynamic.yml`, **`host.docker.internal`**).

**Conflitto 443:** sì se **`chat_local_ingress`** usa già **443**.

---

### Scenario 3 — SuperAdmin dev con Traefik legacy (solo app su `rete_per_instradamento`)

Rete **`rete_per_instradamento`** deve esistere (preflight **`--with-legacy-edge`** o `docker network create`).

Da root clone SuperAdmin:  
`docker compose --env-file docker/.env --env-file env/.env -f docker/docker-compose.yml -f docker-compose.dev.yml -f docker-compose.traefik-local.yml up -d`

Traefik avviato **separatamente** da **`traefik-local/docker-compose.yml`**.

**Traefik attivo:** **legacy SuperAdmin** (dynamic file provider).

---

### Scenario 4 — SuperAdmin **one-shot** legacy (Traefik incluso nel merge)

Da root clone SuperAdmin:  
`docker compose --env-file docker/.env --env-file env/.env -f docker/docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local-ingress.yml up`

Pubblicazione tipica **`127.0.0.1:80` e `:443`** — utile quando non si vuole terminare TLS su Traefik pubblico sulla macchina globale.

**Traefik attivo:** **legacy** embeddato.

---

### Scenario 5 — RealTimeChat **solo** (senza media, senza ingress unificato)

Da **`RealTimeChat/`**:  
`docker compose -f infra/docker-compose.yml -f infra/docker-compose.dev.yml up`

**Traefik:** nessuno; browser va su **localhost:4000** o host diretti pubblicati nei servizi (`5433`, `6380`, `9000`, `9001`).

---

### Scenario 6 — RealTimeChat + **rtc-media** senza ingress unificato

`docker compose -f infra/docker-compose.yml -f infra/docker-compose.dev.yml -f infra/docker-compose.rtc-dev.yml up`

**Traefik:** nessuno a meno che non si usino altri percorsi; **WebRTC** documentato con **`host.docker.internal`** per **`MEDIASOUP_ANNOUNCED_IP`**.

---

### Scenario 7 — **Prod / lab VPS** (contratto compose, senza comando operativo VPS)

Merge tipico da **`RealTimeChat/infra`** con env di produzione:  
`docker compose --env-file ../.env -f docker-compose.yml -f docker-compose.prod.yml …`

**Traefik:** esterno sulla rete **`rete_per_instradamento`** (Compose **external** nel file prod). Nessun `chat_edge` sul deploy descritto in questi file.

*(Authentik)* — **`Authentik-server-login/docker-compose.yml`**, rete **`rete_authentik`** + **`authentik_internal`**.

*(Coturn)* — overlay **`RealTimeChat/infra/docker-compose.coturn.yml`** MERGE sulla base RTC.

*(Attachments E2E)* — **`docker-compose.attachments-e2e.yml`** come MERGE overlay su stack dev/minio/backend per test backend isolati (**senza** Traefik/mkcert nei commenti di file).

---

## Classifica per **file compose** nel workspace Chat

Percorsi relativi alla root **`Chat/`**.

| File | Tag | Motivazione in una frase |
|------|-----|---------------------------|
| `Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml` | **KEEP** | Ingress TLS **target** unificato su `chat_edge`. |
| `Traefik-locale-chat/infra-local/docker-compose.club-chat-edge.attach.yml` | **MERGE** | Aggancia `club_app` alla `chat_edge` senza toccare `docker-compose.local.yml`. |
| `Traefik-locale-chat/infra-local/docker-compose.rtc-chat-edge.attach.yml` | **MERGE** | Aggancia Phoenix, MinIO e rtc-media alla `chat_edge` con alias. |
| `Traefik-locale-chat/infra-local/docker-compose.superadmin-chat-edge.attach.yml` | **MERGE** | Aggancia SuperAdmin alla `chat_edge` con alias `superadminappchat`. |
| `club_dei_presidenti/docker/docker-compose.yml` | **KEEP** | Stack **Club prod** (`rete_per_instradamento`, label Traefik). |
| `club_dei_presidenti/docker/docker-compose.local.yml` | **KEEP** | Stack Club **locale canonico**. |
| `club_dei_presidenti/docker/docker-compose.phoenix-localhost.yml` | **MERGE** | Overlay opzionale variabili browser/Phoenix. |
| `club_dei_presidenti/docker/traefik-local/docker-compose.yml` | **DEPRECATE** | Legacy TLS Club; **solo** fallback — in uso normale **spento**; ingress ufficiale `Traefik-locale-chat/infra-local/`. |
| `RealTimeChat/infra/docker-compose.yml` | **KEEP** | Base RTC (**rete_chat**). |
| `RealTimeChat/infra/docker-compose.dev.yml` | **MERGE** | Overlay dev standard sulla base: Postgres/Redis/MinIO, porte pubblicate Phoenix (`MKCERT_CAROOT` richiesta). |
| `RealTimeChat/infra/docker-compose.rtc-dev.yml` | **MERGE** | Opzionale `rtc-media-node` locale. |
| `RealTimeChat/infra/docker-compose.rtc-multinode.lab.yml` | **MERGE** | Lab multi-nodo RTC. |
| `RealTimeChat/infra/docker-compose.multinode.lab.yml` | **MERGE** | Lab multi-backend Phoenix. |
| `RealTimeChat/infra/docker-compose.attachments-e2e.yml` | **KEEP** | Profilo **E2E** allegati (HTTP interno, senza Traefik); utile ai test dichiarati nel file — valutazione **DELETE LATER** solo dopo migrazione esplicita pipeline. |
| `RealTimeChat/infra/docker-compose.prod.yml` | **KEEP** | **Prod**/lab VPS contratto `.env`. |
| `RealTimeChat/infra/docker-compose.prod.images.yml` | **KEEP** | Variant prod solo immagine già pubblicata. |
| `RealTimeChat/infra/docker-compose.rtc-media-prod.yml` | **MERGE** overlay | Media prod + Traefik su `rete_per_instradamento` (merge sulla base prod). |
| `RealTimeChat/infra/docker-compose.coturn.yml` | **MERGE** overlay | Coturn RTC (merge sulla base/stack indicato nei commenti compose). |
| `SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml` | **KEEP** | Base SuperAdmin. |
| `SuperAdmin-App-per-RealTimeChat/docker-compose.dev.yml` | **MERGE** | Overlay dev locale. |
| `SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml` | **KEEP** | Prod SuperAdmin (`rete_per_instradamento`). |
| `SuperAdmin-App-per-RealTimeChat/docker-compose.traefik-local.yml` | **MERGE** | Overlay: `app` su `rete_per_instradamento` con alias; percorso legacy accanto al Traefik in `traefik-local/` mentre si migra verso `chat_edge`. |
| `SuperAdmin-App-per-RealTimeChat/docker-compose.local-ingress.yml` | **DEPRECATE** | Duplica ingress Traefik quando esiste **`chat_local_ingress`** (transizione tollerata). |
| `SuperAdmin-App-per-RealTimeChat/traefik-local/docker-compose.yml` | **DEPRECATE** | Traefik container legacy separato dalla target. |
| `Authentik-server-login/docker-compose.yml` | **KEEP** | Stack Authentik; non nel perimetro host Traefik locale del piano unified. |

**Note:** **`RealTimeChat/.github/workflows/docker-compose-build.yml`** non è un compose applicativo ma job CI (**KEEP** infra CI).

*(Regola uso tag)*: **MERGE** implica sempre un **`-f` preceduto dal file base** dello stesso prodotto; **KEEP** può essere usato da solo o come capo-merge.
