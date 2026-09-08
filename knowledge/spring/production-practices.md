# Spring em produção

## Checklist mínimo

- graceful shutdown e readiness coerentes;
- timeouts em clientes, banco e mensageria;
- pools dimensionados pela dependência limitante;
- logs estruturados com correlation ID;
- métricas RED/USE e traces nos caminhos críticos;
- migrations reproduzíveis e rollback operacional;
- configuração e segredos validados no startup.

Teste falhas de dependência e saturação antes do go-live.
