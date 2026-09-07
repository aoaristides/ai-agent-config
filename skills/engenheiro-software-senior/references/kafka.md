# Kafka — uso prático em Spring

Kafka é **log distribuído**, não fila tradicional. Mensagem fica retida (por tempo ou tamanho), consumers leem por offset, múltiplos consumers leem o mesmo tópico independentemente. Isso muda como você desenha o sistema.

**Use quando:** alto throughput, replay necessário, múltiplos consumers consomem o mesmo evento, integração entre serviços via event streaming, log de auditoria, CDC.

**Não use quando:** filas tradicionais com prioridade, scheduled delivery, exchange routing complexo (use RabbitMQ); volume baixo e SQS gerenciado resolve.

## Conceitos críticos

### Tópico, partição, offset

- **Tópico:** stream nomeado de mensagens.
- **Partição:** subdivisão do tópico. Ordem é garantida **dentro da partição**, não entre partições.
- **Offset:** posição da mensagem na partição. Imutável.
- **Mensagem:** key + value + headers + timestamp.

**Chave de particionamento define ordem.** Mensagens com a mesma chave vão para a mesma partição → ordem preservada para aquela chave.

```java
// Garante que eventos do mesmo pedido vão para a mesma partição,
// preservando ordem (Confirmado antes de Enviado antes de Entregue)
kafkaTemplate.send("pedidos.eventos", pedidoId.toString(), eventoSerializado);
```

### Consumer Group

Grupo de consumers que se dividem o trabalho. Kafka distribui partições entre consumers do grupo. **Uma partição é consumida por um único consumer dentro do grupo.**

Implicação: paralelismo máximo de um consumer group = número de partições. 4 partições → no máximo 4 consumers efetivos. Mais que isso ficam ociosos.

### Entrega

**At-least-once por padrão.** Consumer pode receber a mesma mensagem mais de uma vez. **Idempotência é obrigatória.**

Exactly-once é possível mas custoso (transactions, idempotent producer). Default em produção: at-least-once + idempotência no consumer.

## Configuração Spring

```yaml
spring:
  kafka:
    bootstrap-servers: kafka-1:9092,kafka-2:9092,kafka-3:9092
    producer:
      acks: all                            # espera replicação para durabilidade
      enable-idempotence: true              # evita duplicação em retry interno
      compression-type: snappy
      properties:
        max.in.flight.requests.per.connection: 5
    consumer:
      group-id: pedidos-service
      auto-offset-reset: earliest           # primeiro consumo: lê do início
      enable-auto-commit: false             # commit manual após processar
      isolation-level: read_committed
      properties:
        max.poll.records: 100
        max.poll.interval.ms: 300000        # 5min para processar batch
    listener:
      ack-mode: manual                      # commit manual
      concurrency: 3                        # threads do consumer = mín(partições, este valor)
```

## Producer

### Producer básico (sem outbox — apenas quando perda eventual é aceitável)

```java
@Component
@RequiredArgsConstructor
class PedidoEventoProducer {
    private final KafkaTemplate<String, String> kafka;
    private final ObjectMapper mapper;
    
    public void publicar(PedidoConfirmadoEvent evento) {
        try {
            var payload = mapper.writeValueAsString(evento);
            kafka.send("pedidos.confirmados", evento.pedidoId().toString(), payload)
                .whenComplete((result, ex) -> {
                    if (ex != null) log.error("falha publicando evento", ex);
                });
        } catch (JsonProcessingException e) {
            throw new EventoSerializacaoException(e);
        }
    }
}
```

**Para produção com garantia, use outbox.** Ver `event-driven.md` seção Outbox Pattern. Publicar direto no Kafka dentro de transação de banco **não é atômico** — se o broker estiver fora, perdeu o evento.

## Consumer

### Consumer com idempotência e commit manual

```java
@Component
@RequiredArgsConstructor
class PedidoConfirmadoListener {
    private final ProcessadosRepository processados;
    private final AtualizarMetricasUseCase useCase;
    
    @KafkaListener(topics = "pedidos.confirmados", containerFactory = "kafkaListenerContainerFactory")
    @Transactional
    public void on(
        ConsumerRecord<String, String> record,
        Acknowledgment ack
    ) {
        var messageId = extrairMessageId(record);  // pode vir em header ou no payload
        
        if (processados.foiProcessado(messageId)) {
            ack.acknowledge();
            return;
        }
        
        var evento = parse(record.value());
        useCase.executar(evento);
        processados.registrar(messageId);
        
        ack.acknowledge();
    }
}
```

### Tratamento de erro e DLQ

```java
@Bean
public DefaultErrorHandler errorHandler(KafkaTemplate<String, String> template) {
    var recoverer = new DeadLetterPublishingRecoverer(template,
        (record, ex) -> new TopicPartition(record.topic() + ".DLT", record.partition()));
    
    var handler = new DefaultErrorHandler(
        recoverer,
        new ExponentialBackOff(1000L, 2.0)  // 1s, 2s, 4s, 8s...
    );
    handler.setRetryListeners((record, ex, attempt) -> 
        log.warn("retry {} para offset {}", attempt, record.offset()));
    handler.addNotRetryableExceptions(EventoInvalidoException.class);
    return handler;
}
```

Após N tentativas, mensagem vai para tópico `*.DLT` (Dead Letter Topic). Alerte sobre mensagens em DLT.

## Headers e correlação

Use headers para metadata (não polua o payload):

```java
ProducerRecord<String, String> record = new ProducerRecord<>("pedidos.confirmados", key, payload);
record.headers()
    .add("messageId", UUID.randomUUID().toString().getBytes())
    .add("traceId", MDC.get("traceId").getBytes())
    .add("schemaVersion", "v1".getBytes())
    .add("eventType", "PedidoConfirmado".getBytes());
```

No consumer:
```java
@KafkaListener(topics = "...")
public void on(
    @Payload String payload,
    @Header("messageId") String messageId,
    @Header("traceId") String traceId
) { ... }
```

## Schema evolution

Use **Schema Registry** (Confluent, Apicurio) com Avro ou Protobuf em produção. JSON sem schema = bomba-relógio.

Compatibilidade:
- **Backward:** consumer novo lê dado antigo (default).
- **Forward:** consumer antigo lê dado novo.
- **Full:** ambos.

Adicionar campo opcional = backward compatible. Remover/renomear = breaking.

```yaml
spring:
  kafka:
    producer:
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
      properties:
        schema.registry.url: http://schema-registry:8081
```

## Boas práticas

1. **Nomeie tópicos consistentemente:** `<contexto>.<aggregate>.<eventos>`, ex.: `pedidos.confirmados.v1`. Inclua versão quando schema for breaking change.
2. **Particione por chave de negócio** que preserve a ordem necessária (`pedidoId`, `clienteId`).
3. **Dimensione partições para crescimento:** começar com 6-12 partições para serviço novo, aumentar é difícil (não preserva ordem antiga).
4. **Replication factor 3** em produção. `min.insync.replicas=2` + `acks=all` para durabilidade.
5. **Monitore lag por consumer group.** Lag crescente = consumer não acompanha produção.
6. **Não use Kafka como banco.** Retenção é log de eventos, não tabela de consulta.
7. **Cuidado com mensagem grande:** > 1MB começa a doer. Para arquivo, suba para S3 e mande a URL.
8. **Compactação:** snappy ou lz4. Custo CPU pequeno, ganho de rede grande.

## Anti-padrões

- **Sem chave de partição** quando ordem importa.
- **Auto-commit habilitado** + processamento que pode falhar = perda silenciosa.
- **Consumer não idempotente.**
- **Publicar dentro de transação JPA sem outbox.**
- **Tópico genérico tipo `eventos`** com todos os tipos misturados.
- **Sem DLQ ou DLT sem alerta.**
- **Schema sem registry em produção** (`String` JSON sem validação).
- **Concurrency do consumer > número de partições** (threads ociosas).
- **Reprocessar do início (`earliest`) em produção sem entender o efeito.**

## Quando NÃO usar Kafka

- Fila com priorização, scheduled delivery, dead letter automático, routing complexo → **RabbitMQ**.
- Pub/sub simples interno de aplicação → `ApplicationEventPublisher` do Spring.
- AWS-first, baixo volume, sem necessidade de replay → **SQS/SNS**.
- Tráfego pequeno, evitar operar broker → broker gerenciado (MSK, Confluent Cloud, Aiven).

## Ver também

- **`event-driven.md`** — padrões (Outbox, Saga, idempotência, schema evolution) que se aplicam sobre Kafka.
- **`rabbitmq.md`** — alternativa quando o caso de uso pede roteamento complexo ou scheduled delivery.
- **`cqrs.md`** — Kafka como infraestrutura para projeções e read models.
- **Kafka gerenciado em cloud:**
  - **AWS:** `aws.md` — MSK e MSK Serverless.
  - **GCP:** `gcp.md` — não há Kafka nativo; Pub/Sub é equivalente parcial; Confluent Cloud disponível.
  - **Azure:** `azure.md` — Event Hubs com endpoint Kafka-compatível.
