# Java — concorrência

Concorrência exige ownership de estado e limites explícitos.

## Verificações

- Identifique estado compartilhado e região crítica.
- Prefira estruturas concorrentes e imutabilidade a locks manuais.
- Evite I/O bloqueante segurando lock.
- Defina cancelamento, timeout e propagação de contexto.
- Em virtual threads, limite a dependência escassa (pool, socket, API), não apenas threads.

Teste race conditions com repetição e observabilidade, não só pelo caminho feliz.
