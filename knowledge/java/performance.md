# Java — performance

Otimize após medir com carga representativa.

## Sequência

1. Defina SLO e workload.
2. Observe CPU, memória, GC, threads, pools e I/O.
3. Capture profile e identifique o gargalo dominante.
4. Mude uma variável por vez.
5. Compare percentis e custo, não apenas média.

Evite tuning de JVM para mascarar query, alocação ou dependência lenta.
