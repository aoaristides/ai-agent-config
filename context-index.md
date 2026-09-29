# Context Index

Roteador da biblioteca. Selecione a menor combinação que cubra a tarefa.

## Carregamento base

1. `core/kernel.md`
2. `context/agent-core.md`
3. para trabalho multiagente, o contrato em `agents/<id>/AGENT.md` selecionado
   pelo `agents/catalog.yml`
4. uma role em `roles/`
5. um workflow em `workflows/`
6. zero ou mais context packs e um projeto, somente quando identificáveis

Use modo `economical` por padrão. Ative `deep` somente por pedido explícito ou
quando o risco exigir referências adicionais. Siga
`agents/_shared/routing-context-policy.md` quando houver troca de ownership.

## Rotas

| Sinal da tarefa | Agente | Role | Workflow | Contexto adicional |
| --- | --- | --- | --- | --- |
| coordenação entre owners | `orchestrator` | `roles/tech-lead.brief.md` | `workflows/delivery-orchestration.md` | dependências + handoffs |
| problema, valor, escopo ou aceite ambíguo | `product-manager` | `roles/product-manager.brief.md` | `workflows/product-discovery.md` | produto + domínio |
| decisão estrutural, ADR, decomposição | `architect` | `roles/architect.brief.md` | `workflows/architecture-decision.md` | projeto + packs pertinentes |
| feature ou alteração de código | `software-engineer` | `roles/senior-engineer.brief.md` | `workflows/feature-development.md` | projeto + stack necessária |
| bug reproduzível | `software-engineer` | `roles/senior-engineer.brief.md` | `workflows/bugfix.md` | projeto + arquivos afetados |
| incidente ou causa incerta | `software-engineer` | `roles/senior-engineer.brief.md` | `workflows/incident-debug.md` | projeto + evidências do incidente |
| validação independente | `tester` | `roles/tester.brief.md` | `workflows/test-validation.md` | aceite + ambiente + mudança |
| revisão de código | `code-reviewer` | `roles/reviewer.brief.md` | `workflows/code-review.md` | diff + contratos afetados |
| review arquitetural | `architect` | `roles/architect.brief.md` | `workflows/architecture-review.md` | proposta + NFRs + projeto |
| análise de performance | `performance-engineer` | `roles/performance-engineer.brief.md` | `workflows/performance-assessment.md` | baseline + métricas |
| segurança | `security-engineer` | `roles/security-engineer.brief.md` | `workflows/security-review.md` | trust boundaries + evidências |
| entendimento do Catalog Intelligence | agente conforme objetivo | role conforme objetivo | workflow conforme objetivo | `projects/catalog-intelligence-platform/PROJECT.md` + `context-packs/ecommerce/catalog-intelligence.md` |

## Context packs prioritários

- VTEX: `context-packs/ecommerce/vtex.md`;
- SAP Commerce/Hybris: `context-packs/ecommerce/sap-hybris.md`;
- Kafka: `context-packs/infra/kafka.md`;
- Kubernetes: `context-packs/infra/kubernetes.md`;
- Data Mesh: `context-packs/data/data-mesh.md`.

## Regras anti-overload

- Não carregue duas roles sem uma razão explícita.
- Não acione vários agentes quando um único owner puder concluir a tarefa.
- Não carregue uma árvore inteira quando o índice de um projeto apontar arquivos.
- Não carregue `knowledge/` por associação vaga; comece pela dúvida concreta.
- Pare de expandir quando os requisitos e as evidências já sustentarem a ação.
- Contexto vivo e decisões reais pertencem ao cofre; aqui ficam contratos
  portáteis, índices e templates.

## Lacunas

Se a rota não estiver coberta, registre a lacuna em vez de escolher módulos ao
acaso. Só transforme uma recorrência observada em nova role, workflow ou pack.
