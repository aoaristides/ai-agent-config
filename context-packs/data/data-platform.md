# Pack: Data Platform

## Carregar quando

A tarefa depender de ownership de dados, contratos, lineage, qualidade,
processamento batch/stream ou serving analítico.

## Checklist seletivo

- fonte, owner e classificação do dado;
- volume, frequência, retenção e freshness;
- schema, compatibilidade e contrato de qualidade;
- consistência, reprocessamento e deduplicação;
- lineage, observabilidade e custo;
- consumidores e impacto de indisponibilidade.

## Referências sob demanda

Carregue apenas os arquivos de `knowledge/databases/`, `knowledge/kafka/` ou
`knowledge/observability/` necessários à decisão concreta.
