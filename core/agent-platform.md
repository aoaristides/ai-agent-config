# Kernel da plataforma de agentes

Esta camada define como descobrir e combinar agentes sem transformar cada host
em uma implementação independente.

- `agents/catalog.yml` é o catálogo canônico dos agentes disponíveis.
- `agents/_shared/agent-contract.md` define o formato mínimo de cada agente.
- `agents/_shared/routing-context-policy.md` governa seleção e contexto.
- `agents/_shared/handoff-protocol.md` governa passagem de trabalho.
- `agents/<id>/AGENT.md` descreve ownership e aponta para roles, workflows e
  skills existentes; não replica conhecimento técnico.

Use um único agente enquanto ele for suficiente. Acione especialistas somente
quando houver mudança real de ownership, revisão independente ou requisito
específico. Se o host não suportar agentes paralelos, execute os mesmos contratos
sequencialmente e preserve os handoffs como artefatos explícitos.
