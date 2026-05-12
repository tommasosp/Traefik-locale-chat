#!/usr/bin/env bash
# Avvio / ricreazione **solo** dell'ingress Traefik unificato locale (progetto Compose
# `chat_local_ingress`, file `infra-local/docker-compose.chat-local-ingress.yml`).
# **Non** avvia Club, RealTimeChat né SuperAdmin.
#
# Esegue prima il preflight reti documentato in `infra-local/networks.local.manifest`
# (in pratica `chat_edge`), delegando a `docker-networks-preflight.sh local`.
#
# Uso dalla root monorepo `Chat/`:
#   bash Traefik-locale-chat/scripts/traefik-chat-locale-up.sh
#   bash Traefik-locale-chat/scripts/traefik-chat-locale-up.sh --build
#   bash Traefik-locale-chat/scripts/traefik-chat-locale-up.sh --pull
#   bash Traefik-locale-chat/scripts/traefik-chat-locale-up.sh --build --pull
#
# Opzionale: `TRAEFIK_HOST_HTTPS` (default 443) — vedi `docker-compose.chat-local-ingress.yml`.
#
# Rete legacy `rete_per_instradamento`: **non** creata da questo script. Se serve:
#   bash Traefik-locale-chat/scripts/docker-networks-preflight.sh local --with-legacy-edge

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TRAEFIK_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly INFRA_LOCAL="${TRAEFIK_REPO_ROOT}/infra-local"
readonly COMPOSE_FILE="${INFRA_LOCAL}/docker-compose.chat-local-ingress.yml"
readonly PREFLIGHT="${SCRIPT_DIR}/docker-networks-preflight.sh"
readonly CERT_PEM="${INFRA_LOCAL}/certs/cert.pem"
readonly CERT_KEY="${INFRA_LOCAL}/certs/cert-key.pem"

die() {
  printf '[traefik-chat-locale-up] %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[traefik-chat-locale-up] %s\n' "$*"
}

usage() {
  sed -n '2,18p' "$0"
  exit "${1:-0}"
}

if ! command -v docker >/dev/null 2>&1; then
  die "docker non in PATH"
fi

EXTRA_UP_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)
      EXTRA_UP_ARGS+=(--build)
      ;;
    --pull)
      EXTRA_UP_ARGS+=(--pull always)
      ;;
    -h | --help)
      usage 0
      ;;
    *)
      die "argomento non riconosciuto: $1 (uso: bash Traefik-locale-chat/scripts/traefik-chat-locale-up.sh [--build] [--pull])"
      ;;
  esac
  shift
done

[[ -f "$COMPOSE_FILE" ]] || die "manca compose: $COMPOSE_FILE"
[[ -f "$PREFLIGHT" ]] || die "manca preflight: $PREFLIGHT"
[[ -f "$CERT_PEM" && -f "$CERT_KEY" ]] || die "certificati TLS assenti — vedi ${INFRA_LOCAL}/certs/README.md"

info "preflight reti (chat_edge)"
bash "$PREFLIGHT" local

info "avvio chat_local_ingress (solo Traefik, cwd=${INFRA_LOCAL})"
(
  cd "$INFRA_LOCAL"
  if [[ ${#EXTRA_UP_ARGS[@]} -gt 0 ]]; then
    docker compose -f docker-compose.chat-local-ingress.yml up -d "${EXTRA_UP_ARGS[@]}"
  else
    docker compose -f docker-compose.chat-local-ingress.yml up -d
  fi
)

info "fine — stack Traefik locale aggiornato (nessun altro repo)"
