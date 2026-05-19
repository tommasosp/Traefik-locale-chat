#!/usr/bin/env bash
# Rigenera cert mkcert (TeamArtist + Club) e riavvia Traefik.
# Traefik NON ricarica /certs/ automaticamente: senza restart serve TRAEFIK DEFAULT CERT
# per host aggiunti dopo l'ultimo avvio → Chrome segnala certificato non valido.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

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

# Forza reload TLS (file provider watcha solo dynamic/, non /certs/)
touch ../traefik/dynamic/00-tls.yml

echo "==> Riavvio Traefik (carica nuovo cert.pem)..."
docker compose -f ../docker-compose.chat-local-ingress.yml restart traefik

sleep 2
if echo | openssl s_client -connect teamartist.local:443 -servername teamartist.local 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null | grep -q mkcert; then
  echo "OK: teamartist.local serve certificato mkcert."
else
  echo "ERRORE: teamartist.local non usa mkcert — controllare Traefik." >&2
  exit 1
fi
