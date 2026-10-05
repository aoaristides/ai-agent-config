# Contrato comum de agente

Cada `agents/<id>/AGENT.md` deve declarar:

1. **Missão** — resultado pelo qual responde.
2. **Acione quando** — sinais observáveis para routing.
3. **Não acione quando** — limites que evitam cargo cult e sobreposição.
4. **Contexto mínimo** — role, workflow, skills e fontes sob demanda.
5. **Entradas obrigatórias** — evidências necessárias para começar.
6. **Saídas obrigatórias** — artefato verificável entregue.
7. **Handoffs** — condições de entrada, saída e bloqueio.
8. **Guardrails** — riscos que exigem parada ou autorização.

O metadata operacional fica em `agents/catalog.yml`. Cada agente deve declarar
um `model_profile` existente em `models/profiles.yaml`; o contrato `AGENT.md` não
contém fornecedor nem nome concreto de modelo.

## Invariantes

- O pedido atual, as políticas do host e as regras do projeto consumidor têm
  precedência sobre este contrato.
- O agente não assume autoridade de outro papel e não aprova o próprio trabalho
  quando independência for requisito.
- Conhecimento técnico vive em skills, references, context packs e projetos. A
  definição do agente aponta para essas fontes, sem copiá-las.
- Todo resultado separa `[fato]`, `[inferência]` e `[suposição]` quando a origem
  mudar a conclusão.
- Falta de contexto crítico gera pergunta ou handoff bloqueado; não vira chute.
