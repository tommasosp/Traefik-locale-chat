# ADR 0001 (Traefik locale / monorepo `Chat/`) — Allineamento edge Docker su VPS dopo stabilizzazione locale

## Stato

**Bozza / follow-up opzionale** — emesso alla chiusura delle Fasi **1–9** del piano *Normalizzazione reti Docker locali*. Nessuna decisione esecutiva sulla produzione è presa né implementata qui.

## Contesto

- In **locale**, il piano workshop ha introdotto la rete target **`chat_edge`** e il progetto Compose **`chat_local_ingress`** sotto **`Traefik-locale-chat/infra-local/`**, con upstream Traefik verso alias su quella edge (senza `host.docker.internal` sugli upstream del Traefik target), come documentato in **`docs/docker_network_target_architecture.md`** e **`docs/docker_networks_runtime.md`**.
- In **produzione** e lab VPS, nei compose nel repo continuano ad essere usati il nome **`rete_per_instradamento`** (**external**) e le label Traefik esistenti, come da **`docs/docker_network_inventory.md`** e **`docs/docker_networks_runtime.md`** §3–§6.
- **`chat_edge`** nel piano è **solo** nome/convenzione per il contesto locale (workshop); un eventuale **rename dell’edge in prod** sarebbe cambiamento infra **coordination cross-service** e **fuori dall’ambito** del piano locale senza mandato separato esplicito VCS + operazioni VPS.

## Non-decisione (né implementazione ora)

Non si modificano **`docker-compose.prod.yml`** né altri compose di produzione in questo ramo né per effetto di questo ADR nella sua forma «bozza».

## Possibili contenuti futuri di un mandato VPS (solo con ticket/programma dedicato)

A titolo indicativo da aprire in **issue_tracker / change** del team quando si deciderà una milestone infra:

1. Valutazione se rinominare o unificare la rete **`rete_per_instradamento`** rispetto al modello **`chat_edge`** locale, inclusi impatti su **tutti** gli stack pubblicati sulla stessa edge (Club, Phoenix, rtc-media, SuperAdmin, eventualmente ingress condiviso).
2. Coordinare deploy **ordinati** Traefik e servizi, cutover TLS e DNS/host `traefik.docker.network`, rollback.
3. Riconciliazione **`host.docker.internal`**: in prod non coincide con scenario locale OrbStack/Mac; rimangono eventualmente extra host / LB gestiti infra.

## Riferimenti rapidi nel repo workshop

| Documento | Ruolo breve |
|-----------|--------------|
| `docs/docker_network_inventory.md` | Percorsi compose, `rete_per_instradamento`, porte MinIO |
| `docs/docker_network_target_architecture.md` | Prima/dopo, `chat_edge` vs legacy prod naming |
| `docs/docker_networks_runtime.md` | Operatività TLS/443 e checklist Fasi 8–9 |
| `Traefik-locale-chat/infra-local/docker-compose.chat-local-ingress.yml` | Compose target ingress locale |
