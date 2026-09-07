# Arquitetura Hexagonal (Ports & Adapters) — aplicação prática

Hexagonal (Alistair Cockburn, 2005) é a arquitetura organizada em torno de **portas** (interfaces que o domínio precisa) e **adapters** (implementações concretas das portas). A metáfora hexagonal vem da simetria entre entradas e saídas — não há "topo" nem "base", há **dentro** (domínio) e **fora** (infraestrutura).

**Ideia central:** domínio no centro, infraestrutura na periferia, dependências apontam **para dentro**.

**Use quando:** domínio complexo, intenção de testar regra de negócio sem infraestrutura, expectativa de trocar tecnologia (banco, fila, framework) sem reescrever o coração.

**Não force** em CRUD trivial ou em gateway fino sem regra de negócio. A cerimônia custa mais que entrega.

> **Veja também `clean-architecture.md`** para a visão de Uncle Bob (camadas concêntricas Entities/Use Cases/Interface Adapters/Frameworks). Os dois compartilham o núcleo (regra da dependência), mas Clean enfatiza camadas explícitas e casos de uso como artefato de primeira classe; Hexagonal enfatiza simetria de portas e adapters. Escolha **uma nomenclatura** e mantenha — misturar gera confusão.

## Conceitos essenciais

### Camadas (de dentro para fora)

1. **Domínio** — regra de negócio pura. Aggregate, value object, domain event, specification, port. Zero dependência de framework, JPA, HTTP, Kafka.
2. **Aplicação** — use cases / application services. Orquestra o domínio, abre transação, publica evento. Depende de **portas**, não de implementações.
3. **Infraestrutura** — adapters concretos. JPA repository, Kafka producer/consumer, HTTP client, REST controller, mensageria. Implementa portas.
4. **Framework/UI** — Spring Boot, controladores web, configuração. Conecta tudo.

A seta de dependência aponta **para dentro**: infra → aplicação → domínio. Nunca o contrário.

### Portas

- **Porta de entrada (driving / inbound):** o que o mundo externo faz com a aplicação. Geralmente é a interface do use case ou um command handler.
- **Porta de saída (driven / outbound):** o que a aplicação precisa do mundo externo. Repository, gateway, notificador, publisher.

## Estrutura de pacotes (Spring)

```
com.empresa.pedidos/
├── domain/                          ← núcleo, sem Spring/JPA
│   ├── model/
│   │   ├── Pedido.java              (aggregate root)
│   │   ├── ItemPedido.java
│   │   ├── PedidoId.java            (value object)
│   │   └── Status.java
│   ├── event/
│   │   └── PedidoConfirmado.java    (domain event)
│   ├── exception/
│   │   └── PedidoInvalidoException.java
│   └── port/
│       ├── PedidoRepository.java    (porta de saída)
│       └── NotificadorPedido.java   (porta de saída)
│
├── application/                     ← orquestração, Spring permitido
│   ├── usecase/
│   │   ├── CriarPedidoUseCase.java
│   │   └── ConfirmarPedidoUseCase.java
│   └── dto/
│       └── CriarPedidoCommand.java
│
├── infrastructure/                  ← adapters
│   ├── persistence/
│   │   ├── PedidoJpaEntity.java
│   │   ├── PedidoJpaRepository.java (Spring Data)
│   │   └── PedidoRepositoryAdapter.java (implementa port)
│   ├── messaging/
│   │   └── KafkaNotificadorAdapter.java
│   └── http/
│       └── StripePagamentoAdapter.java
│
└── api/                             ← entrada HTTP
    ├── PedidoController.java
    └── PedidoControllerAdvice.java  (RFC 7807)
```

**Pacotes por contexto, não por camada técnica global.** Errado: `com.empresa.controllers`, `com.empresa.services`. Certo: `com.empresa.pedidos.api`, `com.empresa.faturamento.api`.

## Exemplo: Use Case Confirmar Pedido

### Domínio (puro)

```java
package com.empresa.pedidos.domain.model;

public class Pedido {
    private final PedidoId id;
    private final ClienteId cliente;
    private final List<ItemPedido> itens;
    private Status status;
    
    public static Pedido reconstituir(PedidoId id, ClienteId cliente, 
                                       List<ItemPedido> itens, Status status) {
        return new Pedido(id, cliente, itens, status);
    }
    
    public PedidoConfirmado confirmar() {
        if (status != Status.RASCUNHO) {
            throw new TransicaoInvalida("pedido já confirmado ou cancelado");
        }
        if (itens.isEmpty()) {
            throw new PedidoInvalidoException("pedido sem itens");
        }
        this.status = Status.CONFIRMADO;
        return new PedidoConfirmado(id, cliente, Instant.now());
    }
    
    // getters, sem setters públicos
}
```

### Porta de saída (no domínio)

```java
package com.empresa.pedidos.domain.port;

public interface PedidoRepository {
    Optional<Pedido> buscarPorId(PedidoId id);
    void salvar(Pedido pedido);
}
```

### Use case (aplicação)

```java
package com.empresa.pedidos.application.usecase;

@Service
@RequiredArgsConstructor
public class ConfirmarPedidoUseCase {
    private final PedidoRepository pedidoRepository;
    private final EventPublisher eventPublisher;
    
    @Transactional
    public void executar(PedidoId id) {
        var pedido = pedidoRepository.buscarPorId(id)
            .orElseThrow(() -> new PedidoNaoEncontradoException(id));
        
        var evento = pedido.confirmar();      // domínio decide
        
        pedidoRepository.salvar(pedido);       // persistência via porta
        eventPublisher.publicar(evento);       // notificação via porta
    }
}
```

### Adapter de persistência (infra)

```java
package com.empresa.pedidos.infrastructure.persistence;

@Component
@RequiredArgsConstructor
class PedidoRepositoryAdapter implements PedidoRepository {
    private final PedidoJpaRepository jpaRepo;
    
    public Optional<Pedido> buscarPorId(PedidoId id) {
        return jpaRepo.findById(id.value())
            .map(this::paraDominio);
    }
    
    public void salvar(Pedido pedido) {
        jpaRepo.save(paraJpa(pedido));
    }
    
    private Pedido paraDominio(PedidoJpaEntity e) {
        return Pedido.reconstituir(...);
    }
}
```

### Controller (api)

```java
@RestController
@RequestMapping("/pedidos")
@RequiredArgsConstructor
class PedidoController {
    private final ConfirmarPedidoUseCase confirmar;
    
    @PostMapping("/{id}/confirmacao")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void confirmar(@PathVariable UUID id) {
        confirmar.executar(new PedidoId(id));
    }
}
```

## Regras de ouro

1. **Domínio não importa Spring, JPA, Jackson, Kafka.** Se importar, vazou.
2. **Aggregate protege invariantes no método, não no service.** `pedido.confirmar()`, não `pedidoService.confirmar(pedido)` decidindo regra.
3. **Entidade JPA ≠ aggregate de domínio.** Tradução explícita no adapter. Sim, dá trabalho. Sim, é o ponto.
4. **DTO/Record na borda.** Controller recebe `CriarPedidoRequest`, retorna `PedidoResponse`. Nunca entidade JPA serializada.
5. **Exceção de domínio específica**, traduzida para HTTP no `@ControllerAdvice` (RFC 7807).
6. **Transação no use case**, nunca no controller ou repository.
7. **Use case faz uma coisa.** Se chama três use cases internos, considere se é um único caso de uso composto ou se está orquestrando demais.

## Hexagonal "decorativa" — recuse

Sinais de que a arquitetura é só pasta:

- **Domínio anêmico:** classe só com getter/setter, regra toda no service.
- **Porta com nome de implementação:** `JpaPedidoRepository` no domínio.
- **Tipo de infra no domínio:** `LocalDateTime` é OK; `JpaEntity`, `ResponseEntity`, `KafkaRecord` não.
- **Use case importando `RestTemplate`** diretamente — devia ser uma porta.
- **Adapter que vaza exceção técnica:** `SQLException` chegando no controller.
- **Mapeamento "automático" `entity → domain` via reflection sem cuidado:** acopla os dois modelos para sempre.

## Testes

A grande vantagem da hexagonal é o domínio testável sem framework:

```java
// Teste de domínio puro — sem Spring, sem banco, sem mock
class PedidoTest {
    @Test
    void deve_confirmar_pedido_em_rascunho() {
        var pedido = Pedido.reconstituir(id, cliente, List.of(item), Status.RASCUNHO);
        var evento = pedido.confirmar();
        assertThat(pedido.status()).isEqualTo(Status.CONFIRMADO);
        assertThat(evento).isInstanceOf(PedidoConfirmado.class);
    }
    
    @Test
    void deve_recusar_confirmacao_de_pedido_sem_itens() {
        var pedido = Pedido.reconstituir(id, cliente, List.of(), Status.RASCUNHO);
        assertThatThrownBy(pedido::confirmar)
            .isInstanceOf(PedidoInvalidoException.class);
    }
}
```

Use case testa com **stub de portas**, não com `@SpringBootTest`:

```java
class ConfirmarPedidoUseCaseTest {
    PedidoRepository repo = mock(PedidoRepository.class);
    EventPublisher publisher = mock(EventPublisher.class);
    ConfirmarPedidoUseCase useCase = new ConfirmarPedidoUseCase(repo, publisher);
    
    @Test
    void publica_evento_apos_confirmar() {
        when(repo.buscarPorId(any())).thenReturn(Optional.of(pedidoRascunho()));
        useCase.executar(new PedidoId(UUID.randomUUID()));
        verify(publisher).publicar(any(PedidoConfirmado.class));
    }
}
```

Integração com Spring + Testcontainers cobre o adapter, não o domínio.

## Ver também

- **`clean-architecture.md`** — abordagem irmã, mais prescritiva, com Use Cases como artefato de primeira classe.
- **`onion.md`** — abordagem irmã, com anéis concêntricos e domain services em anel próprio.
- **`vertical-slice.md`** — alternativa que organiza por feature em vez de camada técnica. Útil em CRUD-heavy.
- **`ddd.md`** — aggregate, value object e port no centro da arquitetura hexagonal.
- **`solid.md`** — DIP em escala arquitetural: a inversão entre port (interna) e adapter (externo).
