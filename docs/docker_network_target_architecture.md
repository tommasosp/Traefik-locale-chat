# Architettura target — reti Docker (solo convenzioni locali, workspace `Chat/`)

Documento di **modello target** per la normalizzazione delle reti in locale. **Non** modifica i compose esistenti: descrive naming e policy attesi per `chat_local_ingress`, overlay in `infra-local/` e transizione dai Traefik legacy.  
Riferimento operativo dei fatti oggi nel repo: `docs/docker_network_inventory.md` (Fase 1).

---

## 1. Rete edge — `chat_edge`

**Ruolo:** rete **user-defined** dedicata al **perimetro di ingresso HTTP/HTTPS** in ambiente locale target. Devono essere collegati a `chat_edge` almeno:

- il container **Traefik** del progetto Compose target **`chat_local_ingress`**;
- i servizi che devono essere raggiungibili da quel Traefik tramite **DNS Docker** (upstream verso `http://<alias>:<porta>`), con **alias stabili** concordati (es. `club_app`, `rtc_backend`, `superadminappchat`, `minio`, nodo media), così il Traefik target **non** dipende da `host.docker.internal` per quegli upstream principali.

**Policy (cosa non mettere su `chat_edge`):** non collegare a `chat_edge` servizi **puramente interni** che non ricevono traffico di ingresso applicativo attraverso quel Traefik: in particolare **database** (Postgres/MySQL), **Redis**, worker batch, collector interni, ecc. Restano sulle rispettive **reti backend / dati** (vedi sotto). Eccezioni eventuali vanno documentate in `docs/docker_networks_runtime.md` (Fase 8) con motivazione.

**TLS (ingress ufficiale):** certificati mkcert in **`Traefik-locale-chat/infra-local/certs/`** (`cert.pem`, `cert-key.pem`), path persistente nel workspace — vedi **`infra-local/certs/README.md`**. Il Traefik Club legacy continua a usare **`MKCERT_CERT_DIR`** solo per il percorso fallback descritto nel suo README.

---

## 2. Reti interne (backend per area prodotto)

Convenzione **target** per isolare il traffico east-west tra servizi dello stesso dominio. Oggi nel repo compaiono nomi effettivi diversi (bridge Compose, `rete_chat`, ecc.): in transizione si **mappano** così, senza obbligo di rinominare subito le reti legacy se gli overlay agganciano alias e reti aggiuntive.

| Rete target (nome logico) | Contenuto atteso | Evidenza attuale (inventario) |
|---------------------------|------------------|-------------------------------|
| **`rtc_backend`** | Phoenix (`backend`), dipendenze applicative strette su stesso stack (es. dipendenze da convenzione deploy), **non** il solo DB/Redis se restano su rete dedicata | Oggi stack dev: servizi principali su `rete_chat` (`RealTimeChat/infra/docker-compose.yml`) |
| **`club_backend`** | App Django Club, eventuale Redis dedicato stack Club | Locale: `club_dei_presidenti_local`; prod: `rete_club_dei_presidenti` (external) |
| **`superadmin_backend`** | App Django SuperAdmin + DB dedicato | `rete_superadmin_app_chat` in `SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml` |
| **`authentik_backend`** | Componenti Authentik che non devono essere sulla sola edge | `authentik_internal` in `Authentik-server-login/docker-compose.yml` |
| **`rtc_media_backend`** | `rtc-media-node` (signaling/media); spesso stessa area di Phoenix per S2S | Dev: `rete_chat` con `rtc-media-node`; prod: anche `rete_per_instradamento` per label Traefik (`docker-compose.rtc-media-prod.yml`) |

I servizi possono essere attaccati **contemporaneamente** a una rete interna e a `chat_edge` solo dove serve l’ingresso (pattern “doppia interfaccia”: interno + edge).

---

## 3. Reti dati (opzionali)

Convenzione **target** per stati e datastore, separati dal perimetro HTTP verso Traefik:

| Rete target (nome logico) | Uso |
|---------------------------|-----|
| **`rtc_data`** | Postgres/Redis (e analoghi) dello stack RealTimeChat |
| **`club_data`** | MySQL Club, volumi coerenti con stack Club |
| **`superadmin_data`** | Postgres SuperAdmin |
| **`authentik_data`** | Postgres/Redis Authentik (se si vuole separazione netta da `authentik_internal` in evoluzioni future) |

Nel dev attuale molti di questi componenti condividono la stessa rete bridge dello stack (es. `rete_chat` per postgres/redis/backend): la suddivisione in `*_data` è **obiettivo di policy** per nuovi overlay o refactor, non una replica 1:1 obbligata dello stato odierno.

---

## 4. Legacy e produzione

- **`rete_per_instradamento`:** nome dell’**edge** usato in **produzione** e nei compose prod / lab che espongono label Traefik verso l’infrastruttura esistente (`club_dei_presidenti/docker/docker-compose.yml`, `RealTimeChat/infra/docker-compose.prod.yml`, `SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml`, `docker-compose.rtc-media-prod.yml`, ecc.). **Non** va sostituito né rinominato nell’ambito di questo piano lato prod.
- **`chat_edge`:** nome target **solo per il contesto locale** e per i **nuovi** file (`infra-local/`, script preflight Fase 7). È l’equivalente funzionale locale di un’“edge” dedicata al Traefik unificato in transizione, distinta dal nome legacy prod.

**Authentik:** resta su `rete_authentik` con host pubblico `auth.presidentepro.it` nel compose del repo; **non** è nella lista degli host del Traefik locale unificato del piano (`clubdeipresidenti.loc`, `phoenix.…`, `s3.…`, `media.…`, `superadminappchat.local`).

**MinIO (dev):** il routing Traefik **target** verso S3 deve usare l’**API sulla porta 9000** nel container; la **console UI 9001** è separata (solo doc o route dedicata se previsto in Fase 8), coerente con `docs/docker_network_inventory.md`.

---

## 4.1 Mappatura nome rete edge — `rete_per_instradamento` **vs** `chat_edge` (Fase 5)

| Aspetto | **`rete_per_instradamento`** | **`chat_edge`** |
|---------|------------------------------|----------------|
| Dove si usa nel repo | Produzione / lab: label Traefik e reti **`external`** in `club_dei_presidenti/docker/docker-compose.yml`, `RealTimeChat/infra/docker-compose.prod.yml` (+ `docker-compose.prod.images.yml`), `SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml`, `RealTimeChat/infra/docker-compose.rtc-media-prod.yml`; stack SuperAdmin locale che agganciano Traefik storico (`docker-compose.local-ingress.yml`, ecc.) | Solo **locale workshop**: `infra-local/*.yml`, progetto Compose **`chat_local_ingress`**, overlay attach `docker-compose.*-chat-edge.attach.yml`, manifest preflight (`infra-local/networks.local.manifest`) |
| Oggetto | Edge condivisa con Traefik “di reparto” / VPS così come oggi deployato | Edge dedicata al Traefik target unificato in transizione sul Mac/OrbStack |
| Modifiche nell’ambito **di questo piano** | **Nessuna** (vincolo: prod protetta; compose prod intatti) | Creazione/ensure via **`scripts/docker-networks-preflight.sh local`**; consumo dai nuovi soli |

In sintesi: **`rete_per_instradamento` resta il nome dell’edge in prod** finché non esiste un mandato separato di migrazione; **`chat_edge`** è il nome operativo locale per non collidere e per non richiedere `docker network create rete_per_instradamento` per chi usa solo il percorso target.

---

## 5. Narrazione — prima e dopo (locale)

**Prima (stato attuale, da inventario):**

- Due **Traefik locali** distinti: stack **`club_traefik_local`** (`club_dei_presidenti/docker/traefik-local/`) e stack SuperAdmin (`SuperAdmin-App-per-RealTimeChat/traefik-local/` e/o `docker-compose.local-ingress.yml`).
- Il Traefik **Club** risolve gli upstream verso **`host.docker.internal`** (dynamic verso porte pubblicate su host / OrbStack per Phoenix, MinIO, media, ecc.).
- Il Traefik **SuperAdmin** usa **DNS Docker** verso l’app sulla stessa **`rete_per_instradamento`** (alias `superadminappchat`) oppure avvio combinato in `docker-compose.local-ingress.yml`.

**Dopo (obiettivo target, transizione):**

- Progetto Compose **`chat_local_ingress`** con Traefik sulla rete **`chat_edge`** (creata/verificata in **Fase 7** prima degli overlay).
- Gli **stessi hostname TLS locali** del piano restano quelli consolidati nel repo (`clubdeipresidenti.loc`, `phoenix.clubdeipresidenti.loc`, `s3.clubdeipresidenti.loc`, `media.clubdeipresidenti.loc`, `superadminappchat.local`): il browser può puntare al Traefik unificato quando quello stack è attivo e configurato.
- I servizi esposti al Traefik target hanno **alias stabili** su `chat_edge` così gli upstream nella dynamic sono `http://<alias>:<porta_container>` senza **`host.docker.internal`** per il percorso principale (allineamento **Fase 4**).

**Operazione standard:** Traefik target **`chat_local_ingress`** sulla **443** host; Traefik **legacy** (Club, SuperAdmin) **spenti** — restano nel repo come **fallback** (eventuale `TRAEFIK_HOST_HTTPS` su altra porta solo per emergenze). **Mai** due Traefik sulla stessa **443**.

---

## 6. Coerenza con `docs/docker_network_inventory.md` (baby step 2.6)

Controlli incrociati effettuati sulla base dell’inventario:

| Affermazione in questo documento | Ancoraggio inventario |
|----------------------------------|------------------------|
| Club prod usa `rete_per_instradamento` + Traefik labels | `club_dei_presidenti/docker/docker-compose.yml` |
| Club locale usa bridge `club_dei_presidenti_local`, app su `8084:8000`, senza Traefik nel compose locale | `docker-compose.local.yml` |
| Traefik Club locale: `host.docker.internal` + mkcert | `club_dei_presidenti/docker/traefik-local/docker-compose.yml` |
| RTC dev: `rete_chat`, backend `4000`, minio **9000/9001**, `rtc-media-node` **4443** + `host.docker.internal` per WebRTC | `RealTimeChat/infra/docker-compose.dev.yml`, `docker-compose.rtc-dev.yml` |
| SuperAdmin: Traefik locale su `rete_per_instradamento`, alias `superadminappchat` | `docker-compose.local-ingress.yml`, `docker-compose.traefik-local.yml`, `traefik-local/docker-compose.yml` |
| Prod RTC / media: Traefik su `rete_per_instradamento` | `docker-compose.prod.yml`, `docker-compose.rtc-media-prod.yml` |
| Authentik: `rete_authentik` + label Traefik, server su rete edge Authentik | `Authentik-server-login/docker-compose.yml` |

Eventuali drift futuri tra inventario e target vanno risolti aggiornando prima l’inventario (Fase 1) poi questo documento.
