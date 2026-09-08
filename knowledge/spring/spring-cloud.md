# Spring Cloud

Use componentes Cloud apenas quando houver uma necessidade distribuída concreta.

## Pontos de controle

- Gateway: autenticação, roteamento e limites; não concentre regra de negócio.
- OpenFeign/HTTP clients: timeout, erro tipado, métricas e retry idempotente.
- Config: propriedade versionada, segredo fora do repositório e rollback.
- Circuit breaker: política por dependência e operação.

Confirme compatibilidade entre Spring Boot e Spring Cloud no release train oficial.
