# Reti Docker — runtime operativa (workspace `Chat/`)

Documento **Fasi 8–9**: guida operativa unica con sezioni 1–10 nell’ordine del piano (**Fase 8**); **§11 Fase 9** checklist finale. Dettaglio dichiarativo delle reti nei compose e snapshot host in [`ricognizione-reti-locali-orbstack-proxy.md`](ricognizione-reti-locali-orbstack-proxy.md) (§1 tabelle, §2–§4 conflitti/host).  
Altri riferimenti: [`docker_network_target_architecture.md`](docker_network_target_architecture.md), [`docker_network_inventory.md`](docker_network_inventory.md), [`docker_compose_matrix.md`](docker_compose_matrix.md). Follow-up infra VPS *(opzionale)*: [`adr/0001-future-vps-docker-edge-alignment-workshop-follow-up.md`](adr/0001-future-vps-docker-edge-alignment-workshop-follow-up.md).

---

## 1. Architettura target

Il modello concettuale (**`chat_edge`** + reti interne/dati, ingress **`chat_local_ingress`**) è descritto in **`docs/docker_network_target_architecture.md`**.

In sintesi runtime: **`chat_edge`** ospita Traefik target e gli alias degli applicativi che ricevono traffico TLS locale (tramite overlay in **`Traefik-locale-chat/infra-local/`**); **non** è l’equivalente di **`rete_per_instradamento`** usata in prod (vedi §4).

---

## 2. Reti locali

Reti Docker tipiche quando si lavora in **solo locale workshop** sul Mac/OrbStack:

| Nome Docker (effettivo) | Origine stack | Ruolo breve |
|-------------------------|----------------|-------------|
| **`chat_edge`** | Preflight **`scripts/docker-networks-preflight.sh local`** + manifest **`infra-local/networks.local.manifest`** | Edge per **`chat_local_ingress`** e attach overlay. |
| **`club_dei_presidenti_local`** | **`club_dei_presidenti/docker/docker-compose.local.yml`** | Redis, MySQL Club, Django `app` (porta diretta host **8084**). |
| **`rete_chat`** | **`RealTimeChat/infra/docker-compose.yml`** (+ dev/rtc overlay) | Phoenix, Postgres, Redis, MinIO dev, opc. `rtc-media-node`. |
| **`rete_superadmin_app_chat`** | **`SuperAdmin-App-per-RealTimeChat/docker/docker-compose.yml`** | Postgres + app SuperAdmin (spesso porta host **8001** in merge dev). |
| **`rete_authentik`**, **`authentik_internal`** | **`Authentik-server-login/docker-compose.yml`** | Stack Authentik (non nell’host list del Traefik unified locale del piano chat). |

Per l’**elenco completo nominato nei compose** (inclusi nomi progetto Compose come `club_traefik_local_default`): **[`ricognizione-reti-locali-orbstack-proxy.md` §1](ricognizione-reti-locali-orbstack-proxy.md)**.

Creazione reti consentita dal piano in locale senza **`rete_per_instradamento`**: usare **`bash scripts/docker-networks-preflight.sh local`**; per creare anche l’edge legacy: **`bash scripts/docker-networks-preflight.sh local --with-legacy-edge`** (solo se serve stack SuperAdmin/Club storici sulla stessa rete nome fisso prod).

---

## 3. Reti produzione (contratto da compose nel repo)

Qui solo **contratto dichiarativo** nei file del workspace — **nessuna** istruzione di deploy sulla VPS.

- **`rete_per_instradamento`** (**external**) — `traefik.docker.network=rete_per_instradamento` su servizi pubblicati dai compose prod/lab: Club **`club_dei_presidenti/docker/docker-compose.yml`**, RealTimeChat **`infra/docker-compose.prod.yml`**, **`docker-compose.prod.images.yml`**, **`docker-compose.rtc-media-prod.yml`**, SuperAdmin **`docker-compose.prod.yml`**.
- **`rete_club_dei_presidenti`**, **`rete_redis`** (**external**) — dati/redis Club in compose prod (`club_dei_presidenti/docker/docker-compose.yml`).
- **`rete_authentik`** (**external**) — Authentik verso Traefik con host `auth.presidentepro.it` (`Authentik-server-login/docker-compose.yml`).

Lista path prod: **`docs/docker_network_inventory.md`** e tabella **`docs/ricognizione-reti-locali-orbstack-proxy.md`** (coerenti con gli stessi file).

---

## 4. Reti legacy (naming e confusioni da evitare)

- **`rete_per_instradamento`**: nome storico dell’**edge prod/lab** e di parte degli stack **legacy** locali SuperAdmin (`docker-compose.local-ingress.yml`, `docker-compose.traefik-local.yml`, Traefik standalone). **Non** rinominare in prod nell’ambito di questo piano.
- **`chat_edge`**: nome **solo locale** introdotto dall’infra **`infra-local/`**; equivalenza funzionale “edge TLS workshop” ma **isolata** dai compose prod sopra citati.

Dettaglio testuale Fase 5: tabella **`rete_per_instradamento` vs `chat_edge`** in **`docker_network_target_architecture.md`** (§4.1).

---

## 5. Traefik locale — **`chat_local_ingress`** (ufficiale su **443**) **vs** legacy (fallback)

### 5.1 Ingress ufficiale (**`chat_local_ingress`**)

Questo è l’**unico** terminatore TLS locale da tenere sulla **443** del host in condizioni normali. Gli URL applicativi **non** richiedono porta esplicita:

- `https://clubdeipresidenti.loc`
- `https://phoenix.clubdeipresidenti.loc`
- `https://s3.clubdeipresidenti.loc`
- `https://media.clubdeipresidenti.loc`
- `https://superadminappchat.local`

Prima di **`docker compose -f docker-compose.chat-local-ingress.yml up -d`** (da **`Traefik-locale-chat/infra-local/`**): (**1**) creare/verificare i certificati in **`Traefik-locale-chat/infra-local/certs/`** (`cert.pem`, `cert-key.pem`) seguendo **`infra-local/certs/README.md`**; (**2**) assicurarsi che **nessun altro Traefik** (in particolare **Club** `club_traefik_local` né SuperAdmin legacy) sia in ascolto sulla **443** sullo stesso host.

| Elemento | Percorso |
|----------|-----------|
| Compose | **`Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml`** (progetto **`chat_local_ingress`**) |
| Static / dynamic | **`Traefik-locale-chat/infra-local/traefik/`** (`traefik.yml` + **`traefik/dynamic/*.yml`**) |
| Rete container | **`chat_edge`** (**external**, creata dal preflight) |
| Certificati mkcert (**persistenti nel workspace**) | **`Traefik-locale-chat/infra-local/certs/`** — mount **`./certs:/certs`** (nessun export **`MKCERT_CERT_DIR`** richiesto per l’ingress target) |

**Upstream** (solo DNS Docker sulla **`chat_edge`**, alias in tabella):

| Host TLS | Upstream | Porta |
|----------|----------|-------|
| `superadminappchat.local` | `superadminappchat` | 8000 |
| `clubdeipresidenti.loc` | `club_app` | 8000 |
| `phoenix.clubdeipresidenti.loc` | `rtc_backend` | 4000 |
| `s3.clubdeipresidenti.loc` | `minio` | **9000** |
| `media.clubdeipresidenti.loc` | `rtc_media` | 4443 |

Overlay attach: **`infra-local/docker-compose.club-chat-edge.attach.yml`**, **`docker-compose.rtc-chat-edge.attach.yml`**, **`docker-compose.superadmin-chat-edge.attach.yml`**.

### 5.2 Legacy — **non** ingresso principale

- **Club** — **`club_dei_presidenti/docker/traefik-local/`** (`club_traefik_local`): upstream **`host.docker.internal`**. **In uso normale deve restare spento** così la **443** è libera per **`chat_local_ingress`**. Dettaglio storico: **`ricognizione-reti-locali-orbstack-proxy.md` §2.1**.
- **SuperAdmin** — **`traefik-local/docker-compose.yml`**, **`docker-compose.local-ingress.yml`**: stessa regola (fallback solo se serve debug e **senza** conflitto **443**). Header **`DEPRECATED`**: puntamento a **`infra-local/docker-compose.chat-local-ingress.yml`**.

### 5.3 Regola perentoria — **una sola** **443** Traefik

**Non** devono esistere due container Traefik che pubblicano contemporaneamente la **stessa** **443** sul host (OrbStack/Docker Desktop). La configurazione **standard** è: **`chat_local_ingress` attivo sulla 443**, Traefik legacy Club (e ogni altro Traefik locale su **443**) **spento**.

Solo in **eccezione** (incident response, confronto side‑by‑side): spostare **uno** dei due su un’altra porta host con **`TRAEFIK_HOST_HTTPS=<porta>`** — in quel caso gli URL con **443** non si applicano al secondo listener; non è il flusso documentato per il team.

---

## 6. Traefik produzione (solo contratto nel repo)

Il **daemon** Traefik su VPS/**risorse comuni** **non** è in tree: restano solo **label** e **entrypoint**/cert resolver attesi dall’infra esterna.

- **RealTimeChat** — **`RealTimeChat/infra/docker-compose.prod.yml`**, **`docker-compose.prod.images.yml`**: `Host(${CHAT_PUBLIC_HOST})` su `/api`, `/socket`, `/admin_socket`; redirect radice **`CHAT_ROOT_REDIRECT_URL`**; **`traefik.docker.network=rete_per_instradamento`**; service backend porta **4000**; middleware redirect HTTPS + **X-Forwarded-Proto**.
- **`rtc-media-node`** prod — **`docker-compose.rtc-media-prod.yml`**: `Host(${RTC_MEDIA_PUBLIC_HOST})` per `/ws`, `/health`, `/metrics`; service porta **4443**; **`rete_per_instradamento`**.
- **Club** prod — **`club_dei_presidenti/docker/docker-compose.yml`**: host **`clubdeipresidenti.presidentepro.it`**; service **8000**; **`rete_per_instradamento`**.
- **SuperAdmin** prod — **`SuperAdmin-App-per-RealTimeChat/docker-compose.prod.yml`**: host **`superadminappchat.presidentepro.it`**; **8000**; **`rete_per_instradamento`**.
- **Authentik** — **`Authentik-server-login/docker-compose.yml`**: **`auth.presidentepro.it`**, porta servizio container **9000**, rete **`rete_authentik`**.

Ripetizione sintetica allineata a **`ricognizione-reti-locali-orbstack-proxy.md` §2.3**.

---

## 7. Host `/etc/hosts`

Per risolvere i **nome host TLS locali** del piano verso la macchina (browser → Traefik in ascolto sull’host):

| Righe tipiche (`127.0.0.1` …) | Uso |
|-------------------------------|-----|
| `clubdeipresidenti.loc` | Club SPA/Django HTTPS |
| `phoenix.clubdeipresidenti.loc` | API Phoenix pubblica nel dev locale |
| `s3.clubdeipresidenti.loc` | MinIO tramite TLS (routing Traefik verso API :9000) |
| `media.clubdeipresidenti.loc` | Segnaling rtc-media tramite HTTPS |
| `superadminappchat.local` | SuperAdmin console locale |

La stessa lista è nella **ricognizione §4**.

---

## 8. MinIO — distinzione **API :9000** e **console :9001**

Dalla configurazione **`RealTimeChat/infra/docker-compose.dev.yml`** nel repo:

| Esposizione | Porta container / host nel dev | Ruolo |
|-------------|--------------------------------|-------|
| **API S3** | **9000** → host **9000** | Presigned PUT/GET, **`S3_ENDPOINT` HTTPS** via Traefik/host; health interno **`/minio/health/live`** sulla **9000**. |
| **Console web** | **9001** → host **9001** | UI amministrativa MinIO (**non** usarla come target del router S3 usato dall’backend). |

Il profilo **`docker-compose.attachments-e2e.yml`** espone sul host solo **9000** (API); la console resta sulla **9001 solo in rete** interna container.

Nel Traefik target **`infra-local/traefik/dynamic/10-chat-workshop.routes.yml`** il servizio S3 è esplicitamente **`http://minio:9000`**.

---

## 9. Troubleshooting (minimo)

| Sintomo | Cosa verificare |
|---------|----------------|
| **`Bind … 443 failed`** | Un altro processo occupa la **443** — di norma fermare **`club_traefik_local`** (e altri Traefik legacy) prima di **`chat_local_ingress`**. **`TRAEFIK_HOST_HTTPS`** solo emergenza — **§5.3**. |
| **`network chat_edge not found`** | **`bash Traefik-locale-chat/scripts/docker-networks-preflight.sh local`** dalla root monorepo **`Chat/`** (o `bash scripts/docker-networks-preflight.sh local` con cwd **`Traefik-locale-chat/`**). |
| **`404`** / upstream irraggiungibile da Traefik target | **`docker exec`** nel container Traefik con **`wget`** verso alias (**`club_app`**, **`rtc_backend`**, ecc.); servizi devono essere sulla **`chat_edge`** (overlay **`-f …/infra-local/docker-compose.*-chat-edge.attach.yml`**). |
| **Certificato TLS rifiutato** | File **`Traefik-locale-chat/infra-local/certs/cert.pem`** (e chiave); CA mkcert nel trust — **`Traefik-locale-chat/infra-local/certs/README.md`**. |
| **Phoenix health** | Da inventario: **`GET /api/public-config`** su **4000** (non assumere **`/`**). |
| **WebRTC / media** | **`rtc-dev`**: **`MEDIASOUP_ANNOUNCED_IP`**, **`host.docker.internal`** e porte UDP (vedi **`RealTimeChat/infra/docker-compose.rtc-dev.yml`**); estraneo agli upstream del Traefik target — dettaglio in **Appendice** sotto. |

---

## 10. Comandi diagnostici (copiabili)

Percorsi assoluti sulla macchina dove risiede il clone (adatta se diversa):

```bash
cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat"

bash Traefik-locale-chat/scripts/docker-networks-preflight.sh local

docker network ls

docker network inspect chat_edge

docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"
```

Dry-run merge (richiedono env dove indicato nei file, es. **`MKCERT_CAROOT`** per RealTimeChat dev):

```bash
cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat/club_dei_presidenti/docker" && docker compose -f docker-compose.local.yml -f ../../Traefik-locale-chat/infra-local/docker-compose.club-chat-edge.attach.yml config >/dev/null && echo OK_club_attach

cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat/RealTimeChat" && MKCERT_CAROOT="${MKCERT_CAROOT:?export MKCERT_CAROOT}" docker compose -f infra/docker-compose.yml -f infra/docker-compose.dev.yml -f infra/docker-compose.rtc-dev.yml -f ../Traefik-locale-chat/infra-local/docker-compose.rtc-chat-edge.attach.yml config >/dev/null && echo OK_rtc_attach

cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat/SuperAdmin-App-per-RealTimeChat" && docker compose -f docker/docker-compose.yml -f docker-compose.dev.yml -f ../Traefik-locale-chat/infra-local/docker-compose.superadmin-chat-edge.attach.yml config >/dev/null && echo OK_superadmin_attach

cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat/Traefik-locale-chat/infra-local" && docker compose -f docker-compose.chat-local-ingress.yml config >/dev/null && echo OK_ingress
```

Con Traefik target in esecuzione e ID container noto:

```bash
docker exec "<id_container_traefik_target>" wget -qO- --timeout=3 --header='Host: clubdeipresidenti.loc' "http://club_app:8000/" | head -c 80
docker exec "<id_container_traefik_target>" wget -qO- --timeout=3 --header='Host: phoenix.clubdeipresidenti.loc' "http://rtc_backend:4000/api/public-config" | head -c 80
docker exec "<id_container_traefik_target>" wget -qO- --timeout=3 "http://minio:9000/minio/health/live" | head -c 80
```

---

## Appendice — eccezioni `host.docker.internal` (riepilogo Fase 4)

Il **Traefik target** in **`infra-local/`** non usa **`host.docker.internal`** negli upstream né **`extra_hosts`** sul container Traefik. Restano punti degli **stack applicativi**:

| Dove (percorso / contesto) | Ruolo breve |
|----------------------------|---------------|
| `RealTimeChat/infra/docker-compose.rtc-dev.yml` — `rtc-media-node` (`MEDIASOUP_ANNOUNCED_IP`, `extra_hosts`) | WebRTC: annuncio IP / gateway verso l’host. |
| `RealTimeChat/infra/docker-compose.dev.yml` — `backend` **`s3.clubdeipresidenti.loc:host-gateway`** | Risoluzione verso terminazione TLS/host per S3 e CA mkcert (Phoenix). |
| SuperAdmin **`docker-compose.yml`** / **`docker-compose.dev.yml`** — `API_BASE_URL`, `extra_hosts` | Django → Phoenix su porta pubblicata **sull’host**. |
| **`club_dei_presidenti/docker/docker-compose.phoenix-localhost.yml`** (commento sul `.env`) | Bootstrap browser vs chiamata server Django→Phoenix tramite host. |
| Traefik legacy Club **`traefik-local/dynamic.yml`** | Upstream **`host.docker.internal`** (stack separato dal target). |

---

## 11. Verifiche finali (**Fase 9** — checklist ed evidenze)

Barratura degli step **`9.1`–`9.4`** del piano nella testa dell’implementazione quando questa checklist è stata eseguita o aggiornata con gli esiti sotto.

### 11.1 Checklist HTTPS / raggiungibilità (**baby 9.1**)

Esempi con merge path del clone (adatta se diversa):

```bash
cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat"

# TLS verso **443** (ingress ufficiale `chat_local_ingress`; nessuna porta negli URL).
curl -sk --max-time 5 --resolve "clubdeipresidenti.loc:443:127.0.0.1" \
  -X GET -o /dev/null -w "%{http_code}\n" "https://clubdeipresidenti.loc/"
curl -sk --max-time 5 --resolve "phoenix.clubdeipresidenti.loc:443:127.0.0.1" \
  -o /dev/null -w "%{http_code}\n" "https://phoenix.clubdeipresidenti.loc/api/public-config"
curl -skI --max-time 5 --resolve "s3.clubdeipresidenti.loc:443:127.0.0.1" \
  "https://s3.clubdeipresidenti.loc/minio/health/live"
curl -sk --max-time 5 --resolve "media.clubdeipresidenti.loc:443:127.0.0.1" \
  -o /dev/null -w "%{http_code}\n" "https://media.clubdeipresidenti.loc/health"
```

| Voce | Criterio | Nota operative |
|------|----------|------------------|
| **Club** HTTPS | TLS + risposta applicativa sul router `clubdeipresidenti.loc` | **GET**: codice **`405`** sulla radice Django è compatibile (**non** `000`/cert errato); **HEAD**/`curl -I` possono essere fuorvianti. |
| **Phoenix** HTTPS | **`GET /api/public-config`** | Atteso **`200`** JSON pubblico (**§9** troubleshooting). |
| **MinIO API :9000** HTTPS | Routing S3/host `s3.…` | **`200`** da bucket/health sulla **9000** (non confondere con console). |
| **MinIO console :9001** | UI amministrativa | Spesso **`http://127.0.0.1:9001/`** dalla mappa compose dev (**§8**); **non** obbligatoriamente lo stesso host TLS dell’API. |
| **Media (rtc-media)** HTTPS | **`GET /health`** | Il servizio **`rtc-media-node`** risponde a **GET**, non necessariamente a **HEAD** — usare comando **senza** `-I` (evidenza: **GET `/health`** → **`200`** JSON `status`). |
| **SuperAdmin** | Host TLS **`superadminappchat.local`** | Con **`chat_local_ingress`** sulla **443**, HTTPS ufficiale **senza porta** sullo stesso host; verificare SSO/OIDC (`302` può puntare fuori dall’host). |

### 11.2 Singola porta HTTPS host (**baby 9.2**)

- **Lista mapping:** **`docker ps --format "table {{.Names}}\t{{.Ports}}"`**.
- **Conferma chi ascolta 443 sulla macchina:** **`lsof -nP -iTCP:443 -sTCP:LISTEN`** e **`docker ps`** — deve comparire **`chat_local_ingress-traefik-1`** con **`0.0.0.0:443->443`**, senza altro Traefik sulla stessa porta.

### 11.3 Traefik **target**: niente `host.docker.internal` sugli upstream (**baby 9.3**)

Ricerca (nessun risultato atteso sugli **`url`** dinamici del target):

```bash
grep -r "host\.docker\.internal" "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat/Traefik-locale-chat/infra-local/traefik/dynamic" || true
```

Allineamento con **Appendice** (upstream solo alias sulla **`chat_edge`**).

### 11.4 Produzione — solo lettura (**baby 9.4**)

Nessuna modifica compose prod in questo ramo pianificato (**§3**, **`docker_network_inventory.md`** per **`rete_per_instradamento`** e label Traefik invariati).

---

*Il documento di ricognizione OrbStack aggiorna le tabelle statiche; questo file è il punto di ingresso operativo strutturato (Fasi 8–9).*
