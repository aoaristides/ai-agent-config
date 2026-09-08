# Kubernetes — networking

## Mapa mínimo

- Service fornece descoberta estável para Pods efêmeros.
- Ingress/Gateway controla entrada; NetworkPolicy restringe comunicação lateral.
- DNS e connection tracking também saturam.
- Timeout deve caber no orçamento ponta a ponta.

Documente fluxos permitidos, TLS termination, egress e dependências externas. Teste falhas de DNS e conexão, não apenas HTTP 500.
