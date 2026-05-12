#!/usr/bin/env bash
# Preflight reti Docker per il workshop Chat (workspace root: directory che contiene
# infra-local/networks.local.manifest).
#
# Uso dalla root monorepo `Chat/` (path assoluto al manifest: `Traefik-locale-chat/infra-local/networks.local.manifest`):
#   bash Traefik-locale-chat/scripts/docker-networks-preflight.sh local
#
# Flag opzionale:
#   --with-legacy-edge   Crea anche la rete `rete_per_instradamento` se manca (solo
#                        quando servono gli stack legacy locali SuperAdmin / prod-like).
#                        In modalità predefinita questa rete NON viene creata qui.
#
# Exit code 0 se tutte le reti richieste esistono o sono state create correttamente.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") local [--with-legacy-edge]" >&2
  exit 2
}

find_chat_root() {
  local here
  here="$(cd "$(dirname "$0")" && pwd)"
  # Script in Traefik-locale-chat/scripts → radice repo Traefik è il parent (contiene infra-local/).
  dirname "$here"
}

network_exists() {
  docker network inspect "$1" >/dev/null 2>&1
}

ensure_network() {
  local name="$1"
  local driver="${2:-bridge}"
  if network_exists "$name"; then
    echo "[preflight] network exists: $name"
    return 0
  fi
  echo "[preflight] creating network: $name (driver=$driver)"
  docker network create "$name" --driver "$driver"
}

parse_manifest_lines() {
  local manifest="$1"
  [[ -r "$manifest" ]] || {
    echo "ERROR: manifest not readable: $manifest" >&2
    exit 1
  }
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue
    read -r net_name net_driver <<<"$line"
    if [[ -z "$net_name" ]]; then
      continue
    fi
    printf '%s %s\n' "$net_name" "${net_driver:-bridge}"
  done <"$manifest"
}

cmd_local() {
  local with_legacy=false
  for arg in "$@"; do
    case "$arg" in
      --with-legacy-edge)
        with_legacy=true
        ;;
      *)
        echo "ERROR: unknown argument: $arg" >&2
        usage
        ;;
    esac
  done

  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker CLI not found in PATH" >&2
    exit 1
  fi

  CHAT_ROOT="$(find_chat_root)"
  MANIFEST="${CHAT_ROOT}/infra-local/networks.local.manifest"
  parse_manifest_lines "$MANIFEST" | while read -r nm drv; do
    ensure_network "$nm" "$drv"
  done

  if [[ "$with_legacy" == true ]]; then
    ensure_network "rete_per_instradamento" "bridge"
  fi

  echo "[preflight] done (local)."
}

main() {
  [[ "${1:-}" == "local" ]] || usage
  shift
  cmd_local "$@"
}

main "$@"
