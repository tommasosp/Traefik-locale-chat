# Certificati TLS — Traefik `chat_local_ingress`

Directory **persistente** nel workspace: qui devono stare **`cert.pem`** e **`cert-key.pem`** (mkcert), montata da `../docker-compose.chat-local-ingress.yml` come `./certs` → `/certs` nel container.

## Generazione (una tantum per clone / dopo rotazione)

Dalla directory **`Traefik-locale-chat/infra-local/certs/`** (root monorepo **`Chat/`**):

```bash
cd "/Users/tommasosalvagnini/Movies/Workspace cursor/Chat/Traefik-locale-chat/infra-local/certs"
mkcert -cert-file cert.pem -key-file cert-key.pem \
  clubdeipresidenti.loc "*.clubdeipresidenti.loc" superadminappchat.local
```

Installare la **CA mkcert** nel trust del sistema/browser come da documentazione ufficiale `mkcert`. I file `*.pem` sono in **`.gitignore`** (non vanno in VCS).

Variabile **`MKCERT_CERT_DIR`** non è più necessaria per l’ingress target: il mount è fisso su questa directory.
