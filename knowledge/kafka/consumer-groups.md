# Kafka — consumer groups

Em um grupo, cada partição é atribuída a no máximo um consumer ativo; mais consumers que partições ficam ociosos.

## Operação

- Monitore lag por partition, taxa de consumo e tempo de processamento.
- Reduza rebalance longo com processamento limitado e estratégia adequada.
- Não faça polling de trabalho ilimitado sem backpressure.
- Commit só deve avançar após o efeito considerado concluído.

Escalar consumers não corrige uma dependência downstream saturada.
