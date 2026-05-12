# Inventario reti Docker — workspace `Chat/`

Fonte: sola lettura dei file `docker-compose*.yml` nel repo (Fase 1 del piano di normalizzazione reti).  
Prerequisiti comuni: molti stack richiedono reti esterne create a mano (`docker network create …`) o variabili d’ambiente (es. `MKCERT_CAROOT` per RealTimeChat dev, **`MKCERT_CERT_DIR`** solo per Traefik **legacy** Club); l’ingress **`chat_local_ingress`** usa i file in **`Traefik-locale-chat/infra-local/certs/`** senza `MKCERT_CERT_DIR`. Vedi README dei sottoprogetti.

---

## Ricognizioni grezze (baby step 1.1)

Dalla root `Chat/` sono state usate ricerche mirate (`rg`/`grep`) sui file compose per: `networks:`, `rete_per_instradamento`, `host.docker.internal`, label `traefik.`, blocchi `ports:`. Sintesi percorsi toccati: `club_dei_presidenti/docker/**`, `RealTimeChat/infra/**`, `SuperAdmin-App-per-RealTimeChat/**`, `Authentik-server-login/docker-compose.yml`.  
Percorso **non inventario compose applicativo**: `RealTimeChat/.github/workflows/docker-compose-build.yml` (CI che invoca `-f infra/docker-compose.yml -f infra/docker-compose.prod.yml` per `build`).

---

## `club_dei_presidenti/docker/docker-compose.yml`

- **Nome progetto Compose (`name`):** `club_dei_presidenti`
- **Servizio `club_mysql`:** solo rete **interna nominata nel file** → `club` (nome rete Docker `rete_club_dei_presidenti`, **external: true**). Nessuna porta host pubblicata.
- **Servizio `app`:** reti `club`, `redis` (`rete_redis`, **external**), `instradamento` (`rete_per_instradamento`, **external**).  
  **Label Traefik:** `traefik.enable`, `traefik.docker.network=rete_per_instradamento`, router `club` / `club-http`, host produzione `clubdeipresidenti.presidentepro.it`, service port **8000**, TLS Let’s Encrypt.  
  **host.docker.internal:** assente.  
  **Dipendenze implicite:** prima dello `up` devono esistere le reti esterne `rete_club_dei_presidenti`, `rete_redis`, `rete_per_instradamento`.

---

## `club_dei_presidenti/docker/docker-compose.local.yml`

- **Nome progetto:** `club_dei_presidenti`
- **Servizio `redis`:** rete `club` → nome `club_dei_presidenti_local` (definita in fondo al file, non external). Nessuna porta pubblicata.
- **Servizio `club_mysql`:** stessa rete `club`. Nessuna porta pubblicata.
- **Servizio `app`:** rete `club`; **porte host** `8084:8000`. Nessuna label Traefik; nessun `host.docker.internal` sul servizio (solo mount e Gunicorn su 8000).
- **Dipendenze:** nessuna rete esterna richiesta oltre alla bridge creata da Compose per `club_dei_presidenti_local`.

---

## `club_dei_presidenti/docker/docker-compose.phoenix-localhost.yml`

- **Overlay** del solo servizio `app` (merge con `docker-compose.local.yml`).  
- **Reti / porte / Traefik:** non introduce modifiche di rete; solo variabili `REALTIME_CHAT_BROWSER_*`.  
- **Nota file:** documenta che `REALTIME_CHAT_API_BASE_URL` nel `.env` resta verso `http://host.docker.internal:4000` per Django → Phoenix.

---

## `club_dei_presidenti/docker/traefik-local/docker-compose.yml`

- **Nome progetto:** `club_traefik_local`
- **Servizio `traefik`:** nessuna sezione `networks` (rete di default Compose).  
- **Porte:** `${TRAEFIK_HOST_HTTPS:-443}:443` (HTTPS terminato nel container).  
- **extra_hosts:** `host.docker.internal:host-gateway` (Traefik risolve upstream su host).  
- **Volume certificati:** `${MKCERT_CERT_DIR}:/certs:ro` → **richiede `MKCERT_CERT_DIR` impostato** per `docker compose config` valido.  
- **Traefik:** config statica file `traefik.yml` + `dynamic.yml` (non label Docker provider).

---

## `Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`

- **Nome progetto:** `chat_local_ingress`
- **Servizio `traefik`:** rete **`chat_edge`** (**external: true**, `name: chat_edge`).  
- **Porte host:** **`${TRAEFIK_HOST_HTTPS:-443}:443`** — in uso normale **443** (URL HTTPS senza porta).  
- **Certificati:** volume **`./certs:/certs:ro`** → directory workspace **`Traefik-locale-chat/infra-local/certs/`** con **`cert.pem`** e **`cert-key.pem`** (mkcert; file non in VCS, vedi `.gitignore` in quella directory).  
- **Nessun** `extra_hosts` verso `host.docker.internal` sul container Traefik target.

---

## `RealTimeChat/infra/docker-compose.yml`

- **Nome progetto:** `realtime_chat`
- **Rete definita:** `rete_chat` (nome Docker `rete_chat`, non external).
- **`postgres`:** solo `rete_chat`. Nessuna porta host nel file base.
- **`redis`:** solo `rete_chat`.
- **`otel-collector`:** solo `rete_chat`.
- **`backend`:** solo `rete_chat`; `PORT` 4000; nessuna label Traefik in questo file.  
- **host.docker.internal:** assente nel base.

---

## `RealTimeChat/infra/docker-compose.dev.yml`

- **Overlay** su base: aggiunge **porte host** a `postgres` `5433:5432`, `redis` `6380:6379`, `otel-collector` `4318:4318`.
- **`minio`:**
  - Rete: `rete_chat`.
  - **Comando:** `server /data --console-address :9001` (console UI sul container sulla porta **9001**).
  - **Porte pubblicate:** `9000:9000` (**API S3**), `9001:9001` (**console web MinIO**).
  - Healthcheck: `curl` verso `http://127.0.0.1:9000/minio/health/live` → verifica **l’endpoint API sulla 9000** (compatibile routing Traefik verso API, non alla console).
- **`minio-init`:** rete `rete_chat`; usa `mc alias set local http://minio:9000` → traffico tooling verso **API :9000** sul nome servizio Docker.
- **`backend`:** rete sempre `rete_chat` tramite merge; **porte** `4000:4000`; `extra_hosts` include `s3.clubdeipresidenti.loc:host-gateway`; mount CA mkcert; dipende da `minio` e `minio-init`.

**MinIO — riepilogo ruoli (API vs console):**

| Dove | API S3 (:9000) | Console UI (:9001) |
|------|----------------|---------------------|
| `docker-compose.dev.yml` | Pubblicata `9000:9000`; ExAws/Phoenix via `https://s3.clubdeipresidenti.loc` (Traefik → solitamente host:9000, vedi commenti file) | Pubblicata `9001:9001` per accesso browser diretto alla UI |
| Traefik/browser | Routing host tipo `s3.clubdeipresidenti.loc` deve puntare al **servizio API** (:9000), non confondere con :9001 | Eventuale host separato o accesso diretto :9001 solo per amministrazione UI |

---

## `RealTimeChat/infra/docker-compose.prod.yml`

- **Overlay prod** (merge con `docker-compose.yml`): estende solo i servizi elencati; `postgres` e `redis` restano coerenti con il base (tipicamente solo `rete_chat` dal merge).
- **`backend`:** reti `rete_chat` e `rete_per_instradamento` (**external: true** in coda al file); **label Traefik** complete per host `${CHAT_PUBLIC_HOST}`, API/socket/admin_socket, redirect root con `CHAT_ROOT_REDIRECT_URL`, `traefik.docker.network=rete_per_instradamento`, loadbalancer porta **4000**.  
- **host.docker.internal:** assente sul backend in questo file.  
- **Prerequisito:** rete Docker esterna `rete_per_instradamento` e Traefik esterno sulla stessa rete (come da commenti/README).

---

## `RealTimeChat/infra/docker-compose.prod.images.yml`

- **Stesso schema di rete e label Traefik del `docker-compose.prod.yml`** per `backend`, con `image: ${BACKEND_IMAGE}` e `otel-collector` da immagine pubblicata (`build: !reset null`).  
- **`rete_per_instradamento`:** external.  
- **host.docker.internal:** assente.

---

## `RealTimeChat/infra/docker-compose.coturn.yml`

- **Servizio `coturn`:** rete `rete_chat`; **porte UDP/TCP** variabili (`COTURN_*`, range relay). Nessun Traefik; nessun `host.docker.internal`.

---

## `RealTimeChat/infra/docker-compose.attachments-e2e.yml`

- **Profilo test:** senza Traefik/TLS (come da commenti nel file).
- **`minio`:** rete `rete_chat`; comando con `--console-address ":9001"`; **solo** `9000:9000` pubblicato sul host (**nessun bind host per 9001** — la console resta raggiungibile solo in rete interna sulla 9001 del container). Env root fissi di test.
- **`backend`:** override env per `S3_ENDPOINT: http://minio:9000` (solo HTTP interno verso **API**).

---

## `RealTimeChat/infra/docker-compose.rtc-dev.yml`

- **`rtc-media-node`:** rete `rete_chat`; **porte** `4443:4443` e range UDP `40000-40050`; `extra_hosts` `host.docker.internal:host-gateway`; env `MEDIASOUP_ANNOUNCED_IP` default `host.docker.internal`.  
- **Traefik:** nessuna label in questo file; integrazione HTTPS locale documentata via Traefik Club (`media.clubdeipresidenti.loc`) nel commento d’intestazione.

---

## `RealTimeChat/infra/docker-compose.rtc-multinode.lab.yml`

- **`rtc-media-node-b`:** rete `rete_chat`; porte `4444:4444`, UDP `40051-40101`; stesso pattern `host.docker.internal` / `MEDIASOUP_ANNOUNCED_IP` del nodo principale in `rtc-dev.yml`.

---

## `RealTimeChat/infra/docker-compose.rtc-media-prod.yml`

- **`rtc-media-node`:** reti `rete_chat` e `rete_per_instradamento`; **UDP** espanso da variabili; **label Traefik** per `${RTC_MEDIA_PUBLIC_HOST}` (WS `/ws`, `/health`, `/metrics`), `traefik.docker.network=rete_per_instradamento`, loadbalancer porta **4443**.  
- **host.docker.internal:** assente.

---

## `RealTimeChat/infra/docker-compose.multinode.lab.yml`

- **Override `backend`:** comando `runservice` e `PHX_SERVER`; stesse reti del contesto di merge (tipicamente solo `rete_chat` in assenza di `docker-compose.prod.yml`). Nessuna nuova rete. Commento: con prod, più replica ereditano le stesse label Traefik.

---

## `SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml`

- **Nome progetto:** `superadminappchat`
- **`db`:** rete `rete_superadmin_app_chat` (bridge definita in fondo). Nessuna porta host nel file base.
- **`app`:** solo `rete_superadmin_app_chat`; **default env** `API_BASE_URL: http://host.docker.internal:4000`; **extra_hosts** `host.docker.internal:host-gateway`. Nessuna label Traefik nel base.

---

## `SuperAdmin-App-per-RealTimeChat/docker-compose.dev.yml`

- **Overlay** su `docker/docker-compose.yml`: mount, `app` con **porte** `8001:8000`, `extra_hosts` host-gateway, `API_BASE_URL` default verso `host.docker.internal:4000`, `ALLOWED_HOSTS` / `CSRF_TRUSTED_ORIGINS` per dev locale.

---

## `SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml`

- **`app`:** reti `rete_superadmin_app_chat` e `rete_per_instradamento` (**external**); volume media host; **label Traefik** produzione `superadminappchat.presidentepro.it`, service port **8000**, Let’s Encrypt.

---

## `SuperAdmin-App-per-RealTimeChat/docker-compose.traefik-local.yml`

- **Overlay:** aggiunge a `app` la rete `rete_per_instradamento` (**external**) con alias **`superadminappchat`**.  
- **Non** definisce il container Traefik (si assume Traefik già in esecuzione altrove).

---

## `SuperAdmin-App-per-RealTimeChat/docker-compose.local-ingress.yml`

- **Servizio `traefik`:** immagine Traefik v3.6.4; **porte** `127.0.0.1:80:80`, `127.0.0.1:443:443`; rete `rete_per_instradamento` creata dal compose con **`name: rete_per_instradamento`** (non marcata external in questo frammento — il progetto crea la named network se assente).
- **`app`:** oltre a `rete_superadmin_app_chat`, anche `rete_per_instradamento` con alias `superadminappchat`.
- **`extra_hosts` su traefik:** `host.docker.internal:host-gateway`.

---

## `SuperAdmin-App-per-RealTimeChat/traefik-local/docker-compose.yml`

- **`traefik`:** file provider `./dynamic`; **porte** localhost 80/443; rete **`rete_per_instradamento` (external: true)**; `extra_hosts` host-gateway.  
- **`container_name`:** `traefik-local-traefik-1`.

---

## `Authentik-server-login/docker-compose.yml`

- **Nome progetto:** `stack_authentik`
- **`postgresql`, `redis`:** rete **`authentik_internal`** (bridge locale).
- **`server`:** `authentik_internal` + **`rete_authentik` (external)**; **label Traefik** `auth.presidentepro.it`, `traefik.docker.network=rete_authentik`, service port **9000** — _nota: questa porta 9000 è il servizio applicativo Authentik dietro Traefik, non MinIO._
- **`worker`:** solo `authentik_internal`.
- **`host.docker.internal`:** assente.

---

## Verifica sintassi Compose (baby step 1.6, campione)

Comandi README-driven eseguiti con successo (`docker compose … config --quiet`):

- `club_dei_presidenti/docker`: `-f docker-compose.local.yml`
- `RealTimeChat/infra`: `-f docker-compose.yml -f docker-compose.multinode.lab.yml`
- `SuperAdmin-App-per-RealTimeChat`: `-f docker/docker-compose.yml`

**Non validato qui** senza variabili: `club_dei_presidenti/docker/traefik-local/docker-compose.yml` richiede `MKCERT_CERT_DIR` non vuoto per il bind `/certs`. Il compose **`Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`** richiede invece i file **`cert.pem`** / **`cert-key.pem`** presenti sotto **`Traefik-locale-chat/infra-local/certs/`**.  
Merge che introducono `minio-init` / `MKCERT_CAROOT` richiedono variabili d’ambiente come da `infra/docker-compose.dev.yml` e README RealTimeChat.

---

## Revisione incrociata (baby step 1.5)

Ogni voce sopra è stata ricontrollata aprendo i file sorgente corrispondenti nel workspace alla data di redazione.
