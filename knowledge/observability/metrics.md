# Métricas

Use RED para serviços (rate, errors, duration) e USE para recursos (utilization, saturation, errors).

## Guardrails

- evite labels de alta cardinalidade;
- defina unidade e semântica;
- histogramas sustentam percentis agregáveis;
- gauge representa estado atual, counter acumula eventos;
- dashboard deve responder uma pergunta operacional.

Alerta deve indicar impacto ou risco acionável, com owner e runbook.
