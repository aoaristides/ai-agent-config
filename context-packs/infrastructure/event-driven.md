# Pack: Event-driven

## Carregar quando

Eventos forem parte confirmada do problema ou da solução, não apenas uma opção
genérica de arquitetura.

## Perguntas mínimas

- Qual fato de domínio é publicado e quem é o owner?
- Qual garantia de entrega e ordenação é realmente necessária?
- Como producer e consumer tratam idempotência e evolução de schema?
- Como funcionam retry, DLQ, reprocessamento e observabilidade?
- Como publicação e persistência evitam dual-write inconsistente?

## Referências sob demanda

Use `knowledge/kafka/` e as referências da skill de engenharia apenas para as
questões presentes na tarefa.
