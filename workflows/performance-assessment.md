# Workflow: análise de performance

Este workflow não amplia o gatilho do `performance-engineer`. Sem sintoma de
performance, métrica relevante e baseline ou janela comparável, o owner do
diagnóstico permanece responsável por levantar a evidência inicial; só então
faz o handoff para performance.

1. Confirme sintoma, ambiente, baseline e meta fornecida; valores ausentes continuam
   desconhecidos.
2. Confirme se a métrica observa o comportamento que pretende representar.
3. Formule hipóteses falsificáveis e priorize pelo custo do experimento.
4. Altere uma variável relevante por vez quando o ambiente permitir.
5. Compare resultado com baseline e registre variância e limitações.
6. Diferencie causa, correlação, teto externo e gargalo deslocado.
7. Recomende mudança somente com evidência e plano de regressão.

## Saída mínima

Baseline, hipótese, experimento, métricas, resultado, conclusão e risco residual.
