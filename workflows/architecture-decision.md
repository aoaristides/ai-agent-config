# Workflow: decisão arquitetural

1. Confirme problema, escopo, NFRs, volume, consistência, time, prazo e custo.
2. Trate todo parâmetro quantitativo ausente como desconhecido. Não crie faixa,
   valor, multiplicador ou limiar para volume, SLO, latência, time, prazo, custo,
   escala ou readiness, nem mesmo marcado como `[suposição]` ou exemplo.
3. Separe fatos, inferências e suposições. Para lacunas que mudem a conclusão,
   faça uma pergunta ou proponha medição; mantenha a recomendação condicional.
4. Compare ao menos duas opções, incluindo manter o estado atual quando válido.
5. Avalie reversibilidade, operação, lock-in, migração e rollback.
6. Recomende com critérios explícitos e sem números não fornecidos; a decisão
   final continua com o usuário.
7. Se for difícil de reverter, registre com `templates/architecture-decision.md`.

## Saída mínima

Premissas, opções, recomendação, consequências, riscos e experimento ou ADR.
