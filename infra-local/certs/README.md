# Certificati TLS — Traefik `chat_local_ingress`

Directory **persistente** nel workspace: qui devono stare **`cert.pem`** e **`cert-key.pem`** (mkcert), montata da `../docker-compose.chat-local-ingress.yml` come `./certs` → `/certs` nel container.

## Generazione (una tantum per clone / dopo rotazione)

Dalla directory **`Traefik-locale-chat/infra-local/certs/`**:

```bash
cd traefik-locale-chat/infra-local/certs
mkcert -cert-file cert.pem -key-file cert-key.pem \
  clubdeipresidenti.loc "*.clubdeipresidenti.loc" superadminappchat.local \
  teamartist.local local.teamartist.org \
  demo.teamartist.local accounting.teamartist.local \
  testlogin.sportbay.org login.teamartist.local \
  wpui.teamartist.local wpui.wpdevel.loc \
  wpdevel.loc www.wpdevel.loc "*.wpdevel.loc" \
  pei.teamartist.local profeta.teamartist.local profeta.sportbay.local \
  mm.teamartist.local \
  cdn.sportbay.local cdn0.sportbay.local cdn1.sportbay.local \
  cdn2.sportbay.local cdn3.sportbay.local
```

Installare la **CA mkcert** nel trust del sistema/browser come da documentazione ufficiale `mkcert`. I file `*.pem` sono in **`.gitignore`** (non vanno in VCS).

Dopo rigenerazione: **obbligatorio** riavviare Traefik — altrimenti per i nuovi SAN resta il certificato di default (`TRAEFIK DEFAULT CERT`) e Chrome segnala errore TLS anche con mkcert installato.

```bash
./regenerate-and-reload.sh
# oppure manualmente:
# mkcert ... (comando sotto)
# docker compose -f ../docker-compose.chat-local-ingress.yml restart traefik
```

Traefik osserva solo `traefik/dynamic/`; i file in `./certs/` **non** triggerano reload automatico.

## TeamArtist HTTPS

Traefik termina TLS su `:443` e inoltra a `ta_dev_gateway` (alias `teamartist_gateway` su rete `chat_edge`). Route in `../traefik/dynamic/30-teamartist.routes.yml`. Il gateway nginx fa redirect HTTP→HTTPS e propaga `X-Forwarded-Proto` alle app Rails.
