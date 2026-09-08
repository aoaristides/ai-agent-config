---
name: troubleshooting
description: >-
  Investiga incidentes e defeitos por hipótese, evidência e experimentos de baixo
  risco até isolar causa raiz. Use para latência, erros, consumo de recursos,
  falhas distribuídas e comportamento intermitente; não use para design greenfield.
---

# Troubleshooting

## Método

1. Fixe sintoma, impacto, janela temporal e mudança recente.
2. Separe fatos observados de inferências e suposições.
3. Forme poucas hipóteses falsificáveis. Priorize testes com maior poder de
   discriminação, probabilidade plausível, baixo custo e baixo risco.
4. Colete a evidência mínima que distingue as hipóteses: métricas, logs, traces, dump ou teste isolado.
5. Proponha mitigação sem destruir evidência. Aplique somente quando o pedido
   autorizar a mudança; diagnóstico isolado não autoriza executar mitigação.
6. Confirme causa raiz reproduzindo ou eliminando o sintoma.
7. Defina correção, validação, rollback e prevenção.

## Guardrails

Não execute ação destrutiva nem script em produção sem autorização explícita.
Oculte ou anonimize segredos e dados pessoais antes de registrar evidências.
Evite alterar várias variáveis ao mesmo tempo.

## Saída

Mantenha um log conciso de: evidência, hipótese, teste, resultado e próximo passo. Feche com causa raiz ou incerteza residual declarada.

Esta skill é autossuficiente. Se o repositório central estiver disponível, o
template `templates/incident-analysis.md` é opcional. Se a skill de engenharia
estiver disponível e houver código, use seus critérios técnicos sem duplicar
a investigação. Não dependa desses recursos para começar pelo sintoma.
