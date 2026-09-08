# DDD — padrões de integração

- Customer/Supplier: upstream negocia com downstream.
- Conformist: downstream aceita o modelo externo conscientemente.
- Anti-Corruption Layer: traduz e protege o modelo interno.
- Published Language: contrato comum, versionado e explícito.
- Open Host Service: serviço estável para múltiplos consumidores.

Escolha relação por poder, custo de tradução e ritmo de mudança; não compartilhe entidades entre contextos.
