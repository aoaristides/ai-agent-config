# Agentes

Camada operacional e agnóstica sobre o contexto já existente.

## Fontes de verdade

- `catalog.yml`: descoberta dos agentes e dependências de contexto.
- `_shared/agent-contract.md`: contrato mínimo de definição.
- `_shared/routing-context-policy.md`: escolha do agente e composição de contexto.
- `_shared/handoff-protocol.md`: envelope de passagem entre agentes.
- `<agente>/AGENT.md`: missão, ownership e limites do agente.

Roles descrevem comportamento; workflows descrevem processo; skills concentram
conhecimento especializado. No catálogo, workflows e skills são candidatos, não
um pacote para carregar inteiro: os gatilhos da tarefa selecionam o subconjunto.
Um agente apenas compõe essas fontes. Não copie uma skill para dentro de
`AGENT.md`.

Hosts com delegação nativa podem materializar cada definição como subagente.
Hosts sem essa capacidade executam os mesmos contratos em sequência. Os adapters
não carregam todos os agentes: o catálogo e os contratos são consultados sob
demanda para preservar contexto.
