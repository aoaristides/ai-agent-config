---
name: arquiteto-solucoes
description: >-
  Conhecimento aprofundado de arquitetura de soluções carregado sob demanda.
  Use ao desenhar sistema distribuído, decidir entre monolito e
  microsserviços, aplicar DDD estratégico/tático, projetar comunicação
  event-driven com Outbox, Saga, DLQ e schema registry, planejar migração
  de monolito com Strangler Fig ou registrar uma decisão arquitetural ADR.
  Complementa o perfil global de arquiteto carregado pelo agente e herda
  suas regras universais, persona, guardrails e formato de resposta; não
  os duplica. NÃO use para code review, código novo ou debug; isso pertence
  à skill `engenheiro-software-senior`.
---

# Arquiteto de Soluções — Aprofundamento

Conhecimento condicional do perfil global de arquiteto.

As instruções globais do agente mantêm o núcleo sempre ativo:
- Regras universais;
- persona;
- guardrails;
- formato de resposta.

Esta skill complementa esse perfil com conhecimento aprofundado que só deve ser carregado quando a tarefa envolver decisões estruturais de arquitetura.

## Hierarquia de instruções

As instruções globais do agente são a fonte canônica para persona, regras universais, segurança, guardrails e formato de resposta.

Quando houver conflito entre esta skill e as instruções globais do agente, as instruções globais prevalecem.

Esta skill não duplica essas regras.

O conteúdo abaixo serve para escolher soluções com critério, explicitar trade-offs e aprofundar decisões arquiteturais, nunca para empilhar padrões sem justificativa.

## DDD — quando e como

| Use DDD tático quando | Não force quando |
|---|---|
| Regras de negócio densas, em evolução | CRUD com regras triviais |
| Múltiplos especialistas de domínio envolvidos | Time pequeno, escopo pequeno |
| Linguagem do negócio é fonte frequente de bug | Integração técnica pura (ETL, gateway fino) |

- Comece pelo **bounded context** e pela linguagem ubíqua, não pelas anotações JPA.
- Aggregate protege invariantes; **um aggregate, uma transação**.
- Não vaze entidade de domínio em controller. DTO/Record na borda.
- Domain events são fato passado, no particípio (`PedidoConfirmado`, não `ConfirmarPedido`).
- Detalhe tático profundo (specification, ACL, context map) → `references/ddd.md` da skill `engenheiro-software-senior`.

## Event-Driven & Microsserviços

- **Quebre em microsserviço** quando houver: bounded contexts claros, autonomia de time, escala heterogênea, ciclos de release distintos. Caso contrário: **monolito modular com Spring Modulith**.
- **Comunicação:** síncrona (REST/gRPC) para query e operação dependente; assíncrona (eventos) para integração entre contextos.
- **Padrões obrigatórios:** Outbox (persistência + publicação atômica); Saga (orquestrada quando crítico/auditável, coreografada quando o acoplamento puder ser mínimo); idempotency key em todo consumer; DLQ com reprocessamento definido; schema registry (Avro/Protobuf) para evolução de contrato.
- **Recuse:** banco compartilhado entre serviços, retry sem idempotência, evento como RPC disfarçado, 2PC distribuído.
- Implementação concreta (producer/consumer Spring, particionamento, acks) → `references/event-driven.md`, `references/kafka.md` da skill `engenheiro-software-senior`.

## Migração de monolito (Strangler Fig)

Antes de migrar, valide: **o monolito é o problema real?** Se a dor for deploy lento ou time acoplado, modularização (Spring Modulith) pode resolver sem custo de distribuição.

1. **Mapeie bounded contexts** sobre o código atual (event storming ou análise de acoplamento). Identifique os *seams*.
2. **Escolha o primeiro candidato:** alto valor de negócio + baixo acoplamento + dor real.
3. **Crie a anti-corruption layer** entre monolito e novo serviço. O legado não dita o modelo do novo.
4. **Estrangule por leitura primeiro** (CQRS): replique via CDC ou eventos, sirva queries pelo novo serviço, escrita no legado.
5. **Mova a escrita** com dual-write por feature flag e reconciliação. Outbox no legado se possível.
6. **Desligue o caminho antigo** só com métricas estáveis e rollback testado.

**Quando parar:** se os próximos candidatos não têm dor concreta, **pare**. Monolito modular + alguns serviços extraídos é destino legítimo.

**Recuse:** big-bang rewrite, extração por camada técnica, microsserviço sem dono.

## ADR — toda decisão difícil de reverter

```text
# ADR-NNNN: Título
## Status: Proposto | Aceito | Substituído por ADR-XXXX
## Contexto
## Decisão
## Consequências (positivas, negativas, neutras)
## Alternativas consideradas
```

