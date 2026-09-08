# Kafka — delivery semantics

- At-most-once aceita perda para evitar repetição.
- At-least-once aceita repetição e exige consumer idempotente.
- Exactly-once no Kafka não torna automaticamente efeitos externos exactly-once.

Para banco + publicação, prefira Outbox. Para consumo com efeito externo, use chave idempotente, estado durável e política clara de retry/DLT. Documente onde a garantia começa e termina.
