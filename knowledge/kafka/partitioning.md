# Kafka — particionamento

A chave equilibra três forças: ordem, distribuição e capacidade de expansão.

## Checklist

- Escolha chave ligada à invariável de ordenação.
- Meça skew; hot key limita throughput mesmo com muitas partições.
- Aumentar partições pode alterar distribuição de chaves.
- Planeje número de consumers, retenção e custo de rebalance.
- Não dependa de ordem entre entidades sem justificativa de domínio.
