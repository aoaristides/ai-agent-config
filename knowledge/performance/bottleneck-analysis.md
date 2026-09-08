# Análise de gargalos

O gargalo é o recurso que limita throughput no cenário medido.

## Heurística

- localize onde a fila cresce;
- compare utilização e saturação de CPU, memória, pools, disco, rede e dependências;
- verifique locks, GC, queries e rate limits;
- aplique Little's Law quando chegada, concorrência e tempo forem estáveis;
- confirme removendo ou deslocando o limite.

Depois da correção, espere que o próximo gargalo apareça.
