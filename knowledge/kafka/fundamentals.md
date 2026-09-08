# Kafka — fundamentos

Topic organiza o log; partition define ordem local e paralelismo; offset representa posição do consumer.

## Decisões iniciais

- Chave: qual entidade precisa de ordenação?
- Partições: qual throughput e paralelismo futuros?
- Retenção: Kafka é transporte, replay ou fonte de histórico?
- Contrato: como o schema evolui sem quebrar consumidores?

Ordem global não existe entre partições.
