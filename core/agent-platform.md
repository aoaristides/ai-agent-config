# Kernel da plataforma de agentes

Esta camada define como descobrir e combinar agentes sem transformar cada host
em uma implementação independente.

- `agents/catalog.yml` é o catálogo canônico dos agentes disponíveis.
- `agents/_shared/agent-contract.md` define o formato mínimo de cada agente.
- `agents/_shared/routing-context-policy.md` governa seleção e contexto.
- `agents/_shared/handoff-protocol.md` governa passagem de trabalho.
- `agents/<id>/AGENT.md` descreve ownership e aponta para roles, workflows e
  skills existentes; não replica conhecimento técnico.
- `models/profiles.yaml` define capacidades agnósticas; o adapter do runtime
  resolve o perfil usando seu próprio `models.yaml` e a política de fallback.

## Roteamento padrão

1. Classifique o pedido pelo `context-index.md` e identifique objetivo, escopo,
   autoridade e como verificar o aceite. Use as fontes disponíveis e pergunte
   somente pelo que ainda impedir a próxima ação. Respeite o pedido e as regras
   do host e do projeto.
2. Siga direto com o agente responsável quando ele puder concluir. Use o
   `orchestrator` para coordenar dependências ou mudanças de responsabilidade.
   Carregue os contratos e skills conforme cada etapa precisar deles.
3. Para uma etapa de planejamento substancial, decisão de arquitetura ou revisão
   crítica, resolva `--phase plan`. Para implementação com escopo e aceite
   definidos, resolva `--phase execute`. Nas demais etapas, use o `model_profile`
   do catálogo. Siga `models/selection-policy.md` e `models/fallback-policy.md`.
   Nome concreto fica no adapter; falha de resolução deve ser explícita.
4. Delegue quando a tarefa e o host permitirem. Para selecionar o modelo de um
   subagente, use `host_selector` apenas se a sessão aceitar essa seleção e o
   resolver retornar `materializable: true`. Se a delegação não estiver
   disponível, siga os contratos em sequência e informe esse modo de execução.
   A resolução de modelo não altera a sessão principal em andamento.
5. Em cada troca de responsável, preserve escopo, autoridade e critérios no
   handoff canônico. Quando a próxima etapa exigir outra sessão, entregue um
   handoff verificável. Decisões reservadas ao usuário ficam com ele. Conclua
   com as evidências proporcionais à tarefa e os bloqueios que persistirem.
