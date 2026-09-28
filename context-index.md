# Context Index

Roteador da biblioteca. Selecione a menor combinação que cubra a tarefa.

## Carregamento base

1. `core/kernel.md`
2. `context/agent-core.md`
3. uma role em `roles/`
4. um workflow em `workflows/`
5. zero ou mais context packs e um projeto, somente quando identificáveis

Use modo `economical` por padrão. Ative `deep` somente por pedido explícito ou
quando o risco exigir referências adicionais.

## Rotas

| Sinal da tarefa | Role | Workflow | Contexto adicional |
| --- | --- | --- | --- |
| decisão estrutural, ADR, decomposição | `roles/architect.brief.md` | `workflows/architecture-decision.md` | projeto + packs pertinentes |
| feature ou alteração de código | `roles/senior-engineer.brief.md` | `workflows/feature-development.md` | projeto + stack necessária |
| bug reproduzível | `roles/senior-engineer.brief.md` | `workflows/bugfix.md` | projeto + arquivos afetados |
| incidente ou causa incerta | `roles/senior-engineer.brief.md` | `workflows/incident-debug.md` | projeto + evidências do incidente |
| revisão de código | `roles/reviewer.brief.md` | `workflows/code-review.md` | diff + contratos afetados |
| review arquitetural | `roles/architect.brief.md` | `workflows/architecture-review.md` | proposta + NFRs + projeto |
| coordenação de entrega | `roles/tech-lead.brief.md` | workflow conforme objetivo | dependências + owners |
| análise de performance | `roles/performance-engineer.brief.md` | `workflows/incident-debug.md` | baseline + métricas |
| segurança | `roles/security-engineer.brief.md` | workflow conforme objetivo | trust boundaries + evidências |
| entendimento do Catalog Intelligence | role conforme objetivo | workflow conforme objetivo | `projects/catalog-intelligence-platform/PROJECT.md` + `context-packs/ecommerce/catalog-intelligence.md` |

## Context packs prioritários

- VTEX: `context-packs/ecommerce/vtex.md`;
- SAP Commerce/Hybris: `context-packs/ecommerce/sap-hybris.md`;
- Kafka: `context-packs/infra/kafka.md`;
- Kubernetes: `context-packs/infra/kubernetes.md`;
- Data Mesh: `context-packs/data/data-mesh.md`.

## Regras anti-overload

- Não carregue duas roles sem uma razão explícita.
- Não carregue uma árvore inteira quando o índice de um projeto apontar arquivos.
- Não carregue `knowledge/` por associação vaga; comece pela dúvida concreta.
- Pare de expandir quando os requisitos e as evidências já sustentarem a ação.
- Contexto vivo e decisões reais pertencem ao cofre; aqui ficam contratos
  portáteis, índices e templates.

## Lacunas

Se a rota não estiver coberta, registre a lacuna em vez de escolher módulos ao
acaso. Só transforme uma recorrência observada em nova role, workflow ou pack.
