# Kafka — performance

Meça producer, broker, consumer e downstream separadamente.

## Alavancas

- batching, compressão e `linger` trocam latência por throughput;
- `acks` e replicação trocam desempenho por durabilidade;
- tamanho de mensagem afeta rede, heap e page cache;
- partições aumentam paralelismo e também custo operacional;
- consumer lento pode ser CPU, I/O, commit ou dependência externa.

Use percentis e backlog sob carga sustentada.
