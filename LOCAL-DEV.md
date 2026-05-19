# Sviluppo locale — Traefik chat

> **Workspace:** [`../ta-devops/WORKSPACE.md`](../ta-devops/WORKSPACE.md) · [`../ta-devops/docker/CHAT-STACK.md`](../ta-devops/docker/CHAT-STACK.md)

Ingress TLS unificato (:443) per Club, Phoenix, MinIO, SuperAdmin in locale.

```bash
bash scripts/Intero-stack-chat--up.sh --build
```

Certificati: `infra-local/certs/README.md`  
Reti e routing: `docs/docker_networks_runtime.md`
