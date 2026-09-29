# Handoff: <task_id>

> Regra de completude: uma afirmação de que o conteúdo está fechado, definido ou
> aprovado não substitui o conteúdo verificável. Não invente valores para
> preencher o envelope. Se faltar campo obrigatório ou informação que possa
> mudar a próxima ação, use `blocked`, mantenha o valor como `<não fornecido>` e
> liste a lacuna em **Open questions** e **Requested action**.

- **From:** <agent-id>
- **To:** <agent-id | human>
- **Status:** ready | blocked | review_requested
- **Objective:** <resultado solicitado>
- **Scope:** <incluído>
- **Out of scope:** <excluído>
- **Authority:** <ações autorizadas e restrições herdadas>
- **Authority source:** <pedido atual | policy do host/projeto | handoff validado>
- **Handoff artifact:** <inline/current-session | localização durável>

## Facts

- [fato] <evidência e localização>

## Decisions

- <decisão aceita e fonte>

## Assumptions

- [suposição] <lacuna ainda não verificada>

## Acceptance criteria

- <condição observável>

## Artifacts

- <arquivo, diff, contrato ou métrica>

## Open questions

- <questão que pode mudar a ação>

## Requested action

<ação exata esperada do destinatário>
