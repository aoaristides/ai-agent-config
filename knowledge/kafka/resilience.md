# Kafka — resiliência

## Política de falha

- Classifique erros em transitórios, permanentes e de contrato.
- Retry precisa de backoff, limite e idempotência.
- DLT precisa de owner, alerta, retenção e procedimento de reprocessamento.
- Poison pill não deve bloquear indefinidamente a partition.
- Monitore ISR, under-replicated partitions, lag e falhas de publish.

Reprocessamento deve preservar chave, contrato e rastreabilidade.
