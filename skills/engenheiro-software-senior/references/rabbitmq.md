# RabbitMQ — uso prático em Spring

RabbitMQ é **message broker** tradicional (AMQP 0.9.1). Mensagem é entregue e descartada (não fica retida como em Kafka). Foco em **roteamento flexível**, **filas com prioridade**, **scheduled delivery** e **dead letter** nativo.

**Use quando:** filas de trabalho (task queue), roteamento por padrão (topic, headers), prioridade de mensagem, delay/schedule, integração entre serviços com fan-out controlado, volume baixo a médio.

**Não use quando:** alto throughput sustentado, replay necessário, múltiplos consumer groups independentes lendo o mesmo stream (use Kafka).

## Conceitos críticos

### Exchange, Queue, Binding

- **Exchange:** ponto de entrada da mensagem. Aplica regra de roteamento.
- **Queue:** onde a mensagem espera ser consumida.
- **Binding:** regra que conecta exchange a queue.
- **Routing key:** chave que o producer envia; usada pelo exchange para decidir destino.

Producer **nunca publica direto em queue** — sempre em exchange.

### Tipos de exchange

| Tipo | Roteamento |
|---|---|
| **Direct** | Routing key exata bate com binding key |
| **Topic** | Routing key com padrão (`pedido.*.confirmado`, `pedido.#`) |
| **Fanout** | Ignora routing key, envia para todas as queues vinculadas |
| **Headers** | Roteia por headers da mensagem |

**Recomendação:** **topic** cobre a maioria dos casos.

### Entrega

**At-least-once** com ack manual. Mensagem é redelivered se consumer não ackr. **Idempotência continua sendo obrigatória.**

## Configuração Spring (Spring AMQP)

```yaml
spring:
  rabbitmq:
    addresses: rabbit-1:5672,rabbit-2:5672
    username: ${RABBIT_USER}
    password: ${RABBIT_PASSWORD}
    virtual-host: /pedidos
    publisher-confirm-type: correlated      # confirma entrega ao broker
    publisher-returns: true                 # mensagem não-roteável volta
    listener:
      simple:
        acknowledge-mode: manual            # ack manual sempre
        prefetch: 10                        # quantas mensagens pegar de uma vez
        concurrency: 3
        max-concurrency: 10
        retry:
          enabled: true
          max-attempts: 3
          initial-interval: 1s
          multiplier: 2
```

## Declaração de topologia

Não dependa de criação manual no broker — declare na aplicação:

```java
@Configuration
class RabbitTopology {
    public static final String EXCHANGE_PEDIDOS = "pedidos.exchange";
    public static final String QUEUE_PEDIDO_CONFIRMADO = "pedidos.confirmados";
    public static final String DLX_PEDIDOS = "pedidos.dlx";
    public static final String DLQ_PEDIDO_CONFIRMADO = "pedidos.confirmados.dlq";
    
    @Bean
    TopicExchange exchangePedidos() {
        return ExchangeBuilder.topicExchange(EXCHANGE_PEDIDOS).durable(true).build();
    }
    
    @Bean
    TopicExchange dlxPedidos() {
        return ExchangeBuilder.topicExchange(DLX_PEDIDOS).durable(true).build();
    }
    
    @Bean
    Queue queuePedidoConfirmado() {
        return QueueBuilder.durable(QUEUE_PEDIDO_CONFIRMADO)
            .withArgument("x-dead-letter-exchange", DLX_PEDIDOS)
            .withArgument("x-dead-letter-routing-key", "pedido.confirmado.falha")
            .build();
    }
    
    @Bean
    Queue dlqPedidoConfirmado() {
        return QueueBuilder.durable(DLQ_PEDIDO_CONFIRMADO).build();
    }
    
    @Bean
    Binding bindingPedidoConfirmado() {
        return BindingBuilder.bind(queuePedidoConfirmado())
            .to(exchangePedidos())
            .with("pedido.*.confirmado");
    }
    
    @Bean
    Binding bindingDlq() {
        return BindingBuilder.bind(dlqPedidoConfirmado())
            .to(dlxPedidos())
            .with("pedido.confirmado.falha");
    }
}
```

## Producer

### Producer com publisher confirms

```java
@Component
@RequiredArgsConstructor
class PedidoEventoProducer {
    private final RabbitTemplate rabbit;
    
    public void publicar(PedidoConfirmadoEvent evento) {
        var routingKey = "pedido.%s.confirmado".formatted(evento.canal());
        var correlation = new CorrelationData(evento.messageId().toString());
        
        rabbit.convertAndSend(
            RabbitTopology.EXCHANGE_PEDIDOS,
            routingKey,
            evento,
            msg -> {
                msg.getMessageProperties().setMessageId(evento.messageId().toString());
                msg.getMessageProperties().setHeader("traceId", MDC.get("traceId"));
                msg.getMessageProperties().setHeader("eventType", "PedidoConfirmado");
                return msg;
            },
            correlation
        );
    }
}
```

Para publicação atômica com persistência, use **outbox** (ver `event-driven.md`). RabbitMQ não tem transação distribuída com banco.

### Confirmação de publicação

```java
@Component
@RequiredArgsConstructor
class RabbitConfirmCallback implements RabbitTemplate.ConfirmCallback {
    public void confirm(CorrelationData correlation, boolean ack, String cause) {
        if (!ack) {
            log.error("falha publicando messageId={} causa={}", correlation.getId(), cause);
            // reenfileirar / alertar / persistir falha
        }
    }
}
```

## Consumer

```java
@Component
@RequiredArgsConstructor
class PedidoConfirmadoListener {
    private final ProcessadosRepository processados;
    private final AtualizarMetricasUseCase useCase;
    
    @RabbitListener(queues = RabbitTopology.QUEUE_PEDIDO_CONFIRMADO)
    public void on(
        @Payload PedidoConfirmadoEvent evento,
        @Header("messageId") String messageId,
        Channel channel,
        @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag
    ) throws IOException {
        try {
            if (processados.foiProcessado(messageId)) {
                channel.basicAck(deliveryTag, false);
                return;
            }
            
            useCase.executar(evento);
            processados.registrar(messageId);
            channel.basicAck(deliveryTag, false);
            
        } catch (EventoInvalidoException e) {
            // erro não recuperável → DLQ direto
            channel.basicReject(deliveryTag, false);
        } catch (Exception e) {
            // erro recuperável → requeue (mas cuidado com loop)
            channel.basicNack(deliveryTag, false, true);
        }
    }
}
```

**Atenção ao `requeue=true`:** se a falha for permanente, mensagem volta para a queue, é entregue de novo, falha de novo — loop infinito. Use contador de tentativas em header ou estratégia de DLQ com retry com delay.

## Padrões úteis

### Delayed messages (scheduling)

Plugin `rabbitmq_delayed_message_exchange`:

```java
@Bean
CustomExchange exchangeDelayed() {
    return new CustomExchange("pedidos.delayed", "x-delayed-message",
        true, false, Map.of("x-delayed-type", "topic"));
}

// publicar com delay
rabbit.convertAndSend("pedidos.delayed", "lembrete", payload, msg -> {
    msg.getMessageProperties().setHeader("x-delay", 60_000); // 1min
    return msg;
});
```

Alternativa sem plugin: TTL + DLQ — mensagem expira, vai pra DLQ, consumer real lê a DLQ.

### Priority queue

```java
@Bean
Queue queueComPrioridade() {
    return QueueBuilder.durable("trabalhos")
        .withArgument("x-max-priority", 10)
        .build();
}

rabbit.convertAndSend("...", "...", payload, msg -> {
    msg.getMessageProperties().setPriority(8);
    return msg;
});
```

### Retry com backoff via DLX

Padrão "shovel": queue principal → DLX em caso de erro → DLQ com TTL → volta para queue principal após delay. Implementa retry com delay sem bloquear consumer.

## Boas práticas

1. **Sempre `durable=true`** em queue e exchange de produção.
2. **`acknowledge-mode: manual`** — controle quando a mensagem é considerada processada.
3. **Prefetch razoável** (5-20) — alto demais desbalanceia consumers, baixo demais subutiliza.
4. **DLQ sempre.** Toda queue principal aponta para DLX.
5. **`messageId` em todo evento** para idempotência.
6. **Monitore tamanho das queues** — fila crescendo = consumer não acompanha.
7. **Connection pool dimensionado.** Connection é cara; channel é barato. Reuse connection, abra channel por thread.
8. **Cluster de pelo menos 3 nós em produção**, quorum queues para garantia.

## Anti-padrões

- **Publicar em queue direto** (sem exchange).
- **`auto-ack`** — perde mensagem se consumer crashar.
- **Sem DLQ.**
- **Mensagem sem messageId** para idempotência.
- **Requeue infinito** sem contador.
- **Lógica de roteamento no consumer** ("se eventType == X, processo; senão ignoro") — devia ser binding.
- **Connection por mensagem** (overhead absurdo).
- **Mensagem grande** (> 128KB começa a doer; > 1MB, dor real).
- **Persistência (`delivery_mode=2`) em mensagem efêmera** — custo desnecessário.

## Quando NÃO usar RabbitMQ

- Alto throughput sustentado (> 50k msg/s) → **Kafka**.
- Replay/auditoria de eventos → **Kafka**.
- Múltiplos consumer groups independentes → **Kafka**.
- AWS-first com volume baixo → **SQS/SNS**.
- Pub/sub interno de processo → `ApplicationEventPublisher`.

## Ver também

- **`event-driven.md`** — Outbox, Saga, idempotência, DLQ aplicados sobre RabbitMQ.
- **`kafka.md`** — alternativa quando o caso é event streaming, replay ou alto throughput.
- **RabbitMQ e equivalentes gerenciados em cloud:**
  - **AWS:** `aws.md` — Amazon MQ (RabbitMQ gerenciado), SQS para fila simples, SNS+SQS para fan-out.
  - **GCP:** `gcp.md` — não há RabbitMQ nativo; Pub/Sub cobre pub/sub básico; rodar self-managed em GKE quando precisar de AMQP.
  - **Azure:** `azure.md` — Service Bus tem semântica enterprise próxima do RabbitMQ (queues, topics, sessions, scheduled).
