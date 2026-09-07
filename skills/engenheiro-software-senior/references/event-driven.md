# Event-Driven Architecture — padrões e implementação

Event-driven resolve **acoplamento temporal e de conhecimento** entre serviços. Não resolve "comunicação distribuída" genericamente — usar evento como RPC disfarçado piora o sistema.

**Use quando:** integração entre bounded contexts, alta escrita, auditoria forte, processamento assíncrono, decoupling de produtor e consumer.

**Não force quando:** fluxo é inerentemente síncrono (consulta com resposta), regra de negócio simples, latência crítica e previsível.

## Tipos de evento — distinção crucial

### Event Notification
"Algo aconteceu, talvez você queira saber". Evento carrega referência (id), consumer busca detalhe se precisar.

```java
record PedidoConfirmadoEvent(PedidoId pedidoId, Instant em) {}
```

**Prós:** evento pequeno, consumer puxa dado fresco.
**Contras:** acoplamento temporal (se produtor cair, consumer não consulta), múltiplas chamadas extra.

### Event-Carried State Transfer
Evento carrega estado relevante. Consumer mantém réplica local.

```java
record PedidoConfirmadoEvent(
    PedidoId pedidoId,
    ClienteId clienteId,
    List<ItemSnapshot> itens,
    Dinheiro valorTotal,
    EnderecoEntrega endereco,
    Instant em
) {}
```

**Prós:** consumer autônomo, não consulta produtor.
**Contras:** evento maior, duplicação de dado, schema evolution mais complexo.

**Regra prática:** use ECST quando consumers leem muito mais do que o produtor produz; use Notification quando o estado muda rápido ou é sensível.

### Domain Event vs Integration Event
- **Domain Event:** publicado dentro de um bounded context. Pode ser tratado in-process (Spring `ApplicationEventPublisher`).
- **Integration Event:** publicado para outros bounded contexts. Sempre via broker (Kafka, RabbitMQ, SNS).

Não exponha domain event direto como integration event — viola encapsulamento. Traduza no application service.

## Padrões essenciais

### Outbox Pattern

Problema: como persistir aggregate **e** publicar evento atomicamente? Sem outbox, há cenários de inconsistência (commit no banco + falha no broker, ou vice-versa).

Solução: persiste evento na **mesma transação** do aggregate, em uma tabela `outbox`. Processo separado lê a tabela e publica no broker.

```sql
CREATE TABLE outbox (
    id UUID PRIMARY KEY,
    aggregate_type VARCHAR(100) NOT NULL,
    aggregate_id VARCHAR(100) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    occurred_at TIMESTAMP NOT NULL,
    published_at TIMESTAMP NULL,
    INDEX idx_outbox_unpublished (published_at) WHERE published_at IS NULL
);
```

```java
@Service
@RequiredArgsConstructor
class ConfirmarPedidoUseCase {
    private final PedidoRepository pedidoRepo;
    private final OutboxRepository outbox;
    
    @Transactional
    public void executar(PedidoId id) {
        var pedido = pedidoRepo.buscarPorId(id).orElseThrow();
        var evento = pedido.confirmar();
        
        pedidoRepo.salvar(pedido);                // mesma transação
        outbox.gravar(OutboxEntry.de(evento));    // mesma transação
    }
}

@Component
@RequiredArgsConstructor
class OutboxPublisher {
    private final OutboxRepository outbox;
    private final KafkaTemplate<String, String> kafka;
    
    @Scheduled(fixedDelay = 1000)
    public void publicar() {
        var pendentes = outbox.buscarNaoPublicados(100);
        for (var entry : pendentes) {
            kafka.send(entry.topico(), entry.aggregateId(), entry.payload());
            outbox.marcarComoPublicado(entry.id());
        }
    }
}
```

**Alternativas ao polling:** CDC (Debezium lê o WAL/binlog do Postgres/MySQL e publica direto no Kafka). Reduz latência, mais infra.

### Saga — transação distribuída

Quando um processo de negócio atravessa múltiplos serviços e precisa manter consistência eventual com **compensação em caso de falha**.

#### Saga Orquestrada
Coordenador central conhece o fluxo. Recomendado para fluxos críticos, auditáveis.

```
Orquestrador → ReservarEstoque → ProcessarPagamento → AgendarEntrega
            ←                  ←                   ←  
            (compensações em caso de falha)
```

```java
@Service
class CheckoutSaga {
    void executar(CheckoutCommand cmd) {
        var estado = SagaEstado.iniciar(cmd);
        try {
            var reserva = estoqueClient.reservar(cmd.itens());
            estado.registrar("estoque_reservado", reserva);
            
            var pagamento = pagamentoClient.processar(cmd.pagamento());
            estado.registrar("pagamento_processado", pagamento);
            
            entregaClient.agendar(cmd.endereco());
            estado.concluir();
        } catch (Exception e) {
            compensar(estado);
            throw e;
        }
    }
    
    private void compensar(SagaEstado estado) {
        if (estado.contem("pagamento_processado")) {
            pagamentoClient.estornar(estado.get("pagamento_processado"));
        }
        if (estado.contem("estoque_reservado")) {
            estoqueClient.liberar(estado.get("estoque_reservado"));
        }
    }
}
```

**Persistência do estado da saga obrigatória** (não pode estar só em memória). Crash do orquestrador não pode deixar processo pendente.

#### Saga Coreografada
Sem coordenador. Cada serviço escuta evento e publica próximo.

```
PedidoConfirmado → EstoqueReservado → PagamentoProcessado → EntregaAgendada
                                                                ↓
                              (em caso de falha, eventos de compensação)
```

**Vantagem:** acoplamento mínimo, autonomia.
**Desvantagem:** fluxo emerge dos eventos — difícil entender e debugar. Compensação mais complexa.

**Decisão:** orquestrada para fluxo crítico com auditoria; coreografada quando o acoplamento precisa ser mínimo e o fluxo é simples.

### Idempotência em consumers

Broker entrega **pelo menos uma vez** (at-least-once). Consumer **vai** receber a mesma mensagem mais de uma vez. Consumer não-idempotente = bug em produção.

Estratégias:

**1. Idempotência natural** — operação é idempotente por construção (`UPDATE saldo SET valor = ?` com valor absoluto, não incremento).

**2. Deduplicação com tabela de processados:**
```java
@KafkaListener(topics = "pedidos.confirmados")
@Transactional
public void on(PedidoConfirmadoEvent evento, @Header("messageId") String messageId) {
    if (processados.foiProcessado(messageId)) {
        return;  // já vimos, ignora
    }
    
    aplicar(evento);
    processados.registrar(messageId);
}
```

**3. Idempotency key em mutação HTTP** — cliente envia `Idempotency-Key: uuid`. Servidor armazena resposta e devolve a mesma se a key repetir.

### Dead Letter Queue (DLQ)

Mensagem que falha após N tentativas vai para DLQ — não bloqueia o consumer principal nem causa loop infinito.

**Estratégia obrigatória:**
1. Limite de tentativas (3 é razoável, com backoff).
2. DLQ recebe mensagem + contexto da falha.
3. **Alerta** quando DLQ tem mensagem (não silencie).
4. Processo de reprocessamento manual ou automático após correção.

```java
@Bean
public RetryTopicConfiguration retryTopicConfig(KafkaTemplate<String, String> template) {
    return RetryTopicConfigurationBuilder.newInstance()
        .maxAttempts(3)
        .exponentialBackoff(1000, 2, 10000)
        .dltHandlerMethod("dlqHandler")
        .create(template);
}
```

### Schema Evolution

Evento publicado hoje pode ser consumido por código antigo amanhã (ou vice-versa). Schema precisa evoluir sem quebrar consumers.

**Regras:**
- **Adicionar campo opcional:** sempre seguro.
- **Remover campo:** quebra consumers que leem. Deprecate primeiro, remova depois.
- **Renomear campo:** **nunca**. Adicione o novo, mantenha o antigo, deprecate.
- **Mudar tipo:** quebra. Crie versão nova do evento.

**Schema Registry** (Confluent, Apicurio) força compatibilidade no momento da publicação. Use Avro ou Protobuf. JSON sem schema é frágil em produção.

### Event Sourcing — cuidado

Persistir o aggregate como **sequência de eventos** em vez de estado atual. Estado é reconstruído ao re-aplicar os eventos.

**Use quando:** auditoria forte é requisito (financeiro, regulado), time-travel necessário, replay para reconstruir projeções.

**Não use por moda.** Event Sourcing tem custo alto: schema evolution complexo, queries difíceis (precisa de CQRS), snapshots, performance de reconstrução, debugging mais difícil.

Não confunda **publicar eventos** (event-driven, sempre OK) com **Event Sourcing** (persistir como eventos, casos específicos).

## Implementação em Spring

Para Kafka vs RabbitMQ específico, ver `kafka.md` e `rabbitmq.md`.

### Publicar evento de domínio (local, mesmo processo)

```java
@Component
@RequiredArgsConstructor
class PedidoEventPublisher implements EventPublisher {
    private final ApplicationEventPublisher publisher;
    
    public void publicar(DomainEvent evento) {
        publisher.publishEvent(evento);
    }
}

@Component
class EnviarEmailConfirmacao {
    @EventListener
    @Async
    public void on(PedidoConfirmado evento) { /* ... */ }
}
```

### Publicar integration event (broker)

Use outbox. Não publique direto do use case — vaza acoplamento e quebra atomicidade.

## Anti-padrões

- **Evento como RPC:** `SolicitarCalculoFreteEvent` esperando resposta — isso é comando, não evento. Use request/reply ou REST.
- **Evento sem dono:** quem publica não é claro, quem consome também não. Documente.
- **Evento publicado dentro da transação direto no broker:** sem outbox = perda em falha de rede.
- **Consumer não-idempotente.**
- **Sem DLQ ou DLQ sem alerta.**
- **Acoplamento via evento:** consumer espera campo específico que produtor pode mudar. Use schema registry.
- **Saga sem persistência de estado.**
- **Event Sourcing por moda.**
- **Evento com nome de comando:** `ConfirmarPedido` (comando), `PedidoConfirmado` (evento).

## Ver também

- **`kafka.md`** e **`rabbitmq.md`** — brokers self-managed, configuração Spring, particionamento, DLQ, schema evolution.
- **`cqrs.md`** — projeções alimentadas por eventos, consistência eventual entre write side e read side.
- **`ddd.md`** — domain events vs integration events; quem publica, quando, com que payload.
- **`cell-based.md`** — comunicação entre células é sempre assíncrona; padrões deste arquivo aplicam.
- **Mensageria gerenciada em cloud:**
  - **AWS:** `aws.md` — SQS, SNS, EventBridge, MSK, Amazon MQ.
  - **GCP:** `gcp.md` — Pub/Sub, Pub/Sub Lite, alternativas para Kafka.
  - **Azure:** `azure.md` — Service Bus, Event Hubs, Event Grid.
