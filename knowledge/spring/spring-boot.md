# Spring Boot

## Princípios

- Use auto-configuration conscientemente; investigue o que foi criado quando houver ambiguidade.
- Centralize configuração tipada e validada com `@ConfigurationProperties`.
- Mantenha controllers na borda e transações na aplicação.
- Não exponha entidade de persistência como contrato HTTP.
- Probes devem indicar capacidade de servir, sem executar consultas caras.

Versões e propriedades devem ser verificadas na documentação oficial da linha usada.
