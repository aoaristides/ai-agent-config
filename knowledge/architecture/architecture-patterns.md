# Padrões arquiteturais

Escolha padrões pelo problema e pelo custo de mudança.

| Contexto | Candidato | Custo principal |
| --- | --- | --- |
| Domínio coeso, time pequeno | Monólito modular | disciplina de limites |
| Contextos e times autônomos | Microsserviços | operação distribuída |
| Integração desacoplada | Event-driven | consistência eventual |
| Leitura e escrita divergentes | CQRS | projeções e reconciliação |
| Migração incremental | Strangler Fig | coexistência temporária |

Padrão não substitui requisitos, modelo de domínio nem medição.
