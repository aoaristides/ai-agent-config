# Sistemas distribuídos

Distribuição troca simplicidade local por falhas parciais, latência, consistência e custo operacional.

## Checklist

- Defina contrato, timeout e ownership de cada chamada.
- Assuma duplicação, reordenação e indisponibilidade em mensagens.
- Escolha explicitamente consistência forte ou eventual por invariável.
- Use idempotência antes de retry; evite transação distribuída 2PC.
- Observe filas, dependências, saturação e correlação ponta a ponta.

Só distribua quando autonomia, escala ou isolamento justificarem o custo.
