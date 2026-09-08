# Resiliência

Resiliência limita impacto e acelera recuperação; não torna dependências infalíveis.

## Controles

- timeout baseado no orçamento de latência;
- retry com backoff, jitter e operação idempotente;
- circuit breaker para falha persistente, não para erro de negócio;
- bulkhead para conter saturação;
- fallback somente quando semanticamente correto;
- rollback e degradação testados.

Monitore taxa de erro, latência, saturação e efeito da política de retry.
