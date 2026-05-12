#!/usr/bin/env bash
# Avvio locale deterministico: reti, mkcert, MEDIASOUP, ingress TLS unificato,
# Club (compose principale + overlay chat_edge), RealTimeChat (base+dev+rtc+attach), curl di verifica.
#
# Riferimenti: Traefik-locale-chat/docs/docker_networks_runtime.md (§5.1, §11.1), infra-local/certs/README.md,
# RealTimeChat/infra/scripts/rebuild_rtc_media_node_dev.sh (MKCERT + MEDIASOUP).
#
# Uso — monorepo con `Chat/` che contiene `Traefik-locale-chat/`, `club_dei_presidenti/`, `RealTimeChat/`:
#   bash Traefik-locale-chat/scripts/Intero-stack-chat--up.sh
#   bash Traefik-locale-chat/scripts/Intero-stack-chat--up.sh --build
#
# Prerequisiti: Docker, mkcert, file TLS in infra-local/certs/; Club: club_dei_presidenti/docker/.env.docker
# (copia da .env.docker.example). RealTimeChat: .env come da RealTimeChat/infra/README.md.
#
# Opzionale: TRAEFIK_HOST_HTTPS (default 443) — usato anche per le verifiche curl finali.
# Opzionale: MEDIASOUP_ANNOUNCED_IP (default: en0/en1 su macOS, altrimenti impostare a mano).
# Opzionale: SKIP_FINAL_CURL=1 per saltare solo gli ultimi curl.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Monorepo: parent di Traefik-locale-chat/ contiene club_dei_presidenti, RealTimeChat, …
readonly TRAEFIK_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly INFRA_LOCAL="${TRAEFIK_REPO_ROOT}/infra-local"
readonly CLUB_DOCKER="${WORKSPACE_ROOT}/club_dei_presidenti/docker"
readonly REALTIME_ROOT="${WORKSPACE_ROOT}/RealTimeChat"
readonly ATTACH_CLUB="${INFRA_LOCAL}/docker-compose.club-chat-edge.attach.yml"
readonly ATTACH_RTC="${INFRA_LOCAL}/docker-compose.rtc-chat-edge.attach.yml"
readonly CERT_PEM="${INFRA_LOCAL}/certs/cert.pem"
readonly CERT_KEY="${INFRA_LOCAL}/certs/cert-key.pem"

TRAEFIK_PORT="${TRAEFIK_HOST_HTTPS:-443}"

die() {
  printf '[Intero-stack-chat--up] %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[Intero-stack-chat--up] %s\n' "$*"
}

ensure_network() {
  local name="$1"
  if docker network inspect "$name" >/dev/null 2>&1; then
    info "rete ok: $name"
    return 0
  fi
  info "creo rete: $name"
  docker network create "$name" --driver bridge
}

if ! command -v docker >/dev/null 2>&1; then
  die "docker non in PATH"
fi

BUILD_ARGS=()
case "${1:-}" in
  "")
    ;;
  "--build")
    BUILD_ARGS=(--build)
    ;;
  *)
    die "argomento non riconosciuto: $1 (uso: bash Traefik-locale-chat/scripts/Intero-stack-chat--up.sh [--build])"
    ;;
esac

# Con `set -u`, su alcune Bash (es. 3.2 Apple) `"${BUILD_ARGS[@]}"` con array vuoto dà "unbound variable".
compose_up_d() {
  if [[ ${#BUILD_ARGS[@]} -gt 0 ]]; then
    docker compose "$@" up -d "${BUILD_ARGS[@]}"
  else
    docker compose "$@" up -d
  fi
}

[[ -f "${CLUB_DOCKER}/docker-compose.yml" ]] || die "manca ${CLUB_DOCKER}/docker-compose.yml"
[[ -f "$ATTACH_CLUB" ]] || die "manca overlay Club: $ATTACH_CLUB"
[[ -f "$ATTACH_RTC" ]] || die "manca overlay RTC: $ATTACH_RTC"
[[ -f "${REALTIME_ROOT}/infra/docker-compose.yml" ]] || die "manca RealTimeChat infra/docker-compose.yml"
[[ -f "$CERT_PEM" && -f "$CERT_KEY" ]] || die "certificati TLS assenti — vedi ${INFRA_LOCAL}/certs/README.md (cert.pem, cert-key.pem)"
[[ -f "${CLUB_DOCKER}/.env.docker" ]] || die "manca ${CLUB_DOCKER}/.env.docker — copia da .env.docker.example e compila"

if [[ ! -f "${REALTIME_ROOT}/.env" ]]; then
  die "manca ${REALTIME_ROOT}/.env — vedi RealTimeChat/infra/README.md"
fi

info "preflight reti (chat_edge + rete_per_instradamento da manifest/flag)"
bash "${TRAEFIK_REPO_ROOT}/scripts/docker-networks-preflight.sh" local --with-legacy-edge

info "reti esterne Club (compose principale)"
ensure_network rete_club_dei_presidenti
ensure_network rete_redis

if ! MKCERT_CAROOT="$(mkcert -CAROOT 2>/dev/null)" || [[ -z "${MKCERT_CAROOT}" ]]; then
  die "mkcert -CAROOT vuoto — installa mkcert"
fi
export MKCERT_CAROOT
info "MKCERT_CAROOT esportato (path omesso dal log)"

if [[ -z "${MEDIASOUP_ANNOUNCED_IP:-}" ]]; then
  MEDIASOUP_ANNOUNCED_IP=""
  if command -v ipconfig >/dev/null 2>&1; then
    MEDIASOUP_ANNOUNCED_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
    [[ -n "$MEDIASOUP_ANNOUNCED_IP" ]] || MEDIASOUP_ANNOUNCED_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
  fi
  if [[ -z "$MEDIASOUP_ANNOUNCED_IP" ]]; then
    die "MEDIASOUP_ANNOUNCED_IP vuoto — impostalo nell'ambiente (IPv4 LAN host) o usa macOS con en0/en1"
  fi
fi
export MEDIASOUP_ANNOUNCED_IP
info "MEDIASOUP_ANNOUNCED_IP=${MEDIASOUP_ANNOUNCED_IP}"

info "validazione merge compose (Club)"
(
  cd "$CLUB_DOCKER"
  docker compose --env-file .env.docker \
    -f docker-compose.yml \
    -f "$ATTACH_CLUB" \
    config >/dev/null
)

info "validazione merge compose (RealTimeChat)"
(
  cd "$REALTIME_ROOT"
  docker compose \
    -f infra/docker-compose.yml \
    -f infra/docker-compose.dev.yml \
    -f infra/docker-compose.rtc-dev.yml \
    -f "$ATTACH_RTC" \
    config >/dev/null
)

info "avvio chat_local_ingress (Traefik → chat_edge)"
(
  cd "$INFRA_LOCAL"
  compose_up_d -f docker-compose.chat-local-ingress.yml
)

info "avvio Club (redis su rete_redis con alias dichiarato nel compose — niente docker network connect manuale)"
(
  cd "$CLUB_DOCKER"
  compose_up_d --env-file .env.docker \
    -f docker-compose.yml \
    -f "$ATTACH_CLUB"
)

info "avvio RealTimeChat (Phoenix + MinIO + rtc-media-node su chat_edge)"
(
  cd "$REALTIME_ROOT"
  compose_up_d \
    -f infra/docker-compose.yml \
    -f infra/docker-compose.dev.yml \
    -f infra/docker-compose.rtc-dev.yml \
    -f "$ATTACH_RTC"
)

if [[ "${SKIP_FINAL_CURL:-0}" == "1" ]]; then
  info "SKIP_FINAL_CURL=1 — salto verifiche curl (Traefik-locale-chat/docs/docker_networks_runtime.md §11.1)"
  exit 0
fi

# Curl finali: TLS + routing Traefik → alias su chat_edge. Per Club la GET sulla root non è un health
# applicativo Django: serve solo da smoke di raggiungibilità upstream (405 = route/metodo non per GET root, ok).
info "verifiche HTTPS: GET con --resolve *.loc:${TRAEFIK_PORT}→127.0.0.1 (criteri Traefik-locale-chat/docs/docker_networks_runtime.md §11.1)"
code_club=$(curl -sk --max-time 15 --resolve "clubdeipresidenti.loc:${TRAEFIK_PORT}:127.0.0.1" \
  -X GET -o /dev/null -w "%{http_code}" "https://clubdeipresidenti.loc/") || die "curl Club fallito (rete/TLS)"
code_phoenix=$(curl -sk --max-time 15 --resolve "phoenix.clubdeipresidenti.loc:${TRAEFIK_PORT}:127.0.0.1" \
  -o /dev/null -w "%{http_code}" "https://phoenix.clubdeipresidenti.loc/api/public-config") || die "curl Phoenix fallito"
code_s3=$(curl -sk --max-time 15 --resolve "s3.clubdeipresidenti.loc:${TRAEFIK_PORT}:127.0.0.1" \
  -o /dev/null -w "%{http_code}" "https://s3.clubdeipresidenti.loc/minio/health/live") || die "curl MinIO fallito"
code_media=$(curl -sk --max-time 15 --resolve "media.clubdeipresidenti.loc:${TRAEFIK_PORT}:127.0.0.1" \
  -o /dev/null -w "%{http_code}" "https://media.clubdeipresidenti.loc/health") || die "curl rtc-media fallito"

info "codici HTTP: club=${code_club} phoenix=${code_phoenix} s3=${code_s3} media=${code_media}"

if [[ "$code_club" != "405" && "$code_club" != "200" ]]; then
  if [[ "$code_club" == "502" ]]; then
    info "Club GET / → 502 — diagnosi upstream obbligatoria"
    bash "${WORKSPACE_ROOT}/club_dei_presidenti/docker/diagnose-club-https-upstream.sh" || true
  fi
  die "Club smoke upstream (GET /): atteso 405 o 200 (non è health applicativa), ottenuto ${code_club}"
fi
[[ "$code_phoenix" == "200" ]] || die "Phoenix GET /api/public-config: atteso 200, ottenuto ${code_phoenix}"
[[ "$code_s3" == "200" ]] || die "MinIO health: atteso 200, ottenuto ${code_s3}"
[[ "$code_media" == "200" ]] || die "rtc-media GET /health: atteso 200, ottenuto ${code_media}"

info "fine — smoke §11.1 ok; health applicativi Club usare /health/ o percorsi dedicati, non la root con GET"
