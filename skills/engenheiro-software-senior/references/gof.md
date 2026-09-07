# GoF Design Patterns — aplicação prática em Java/Spring

GoF é vocabulário compartilhado para descrever soluções recorrentes. **Use para comunicar intenção, não para enfeitar.** Padrão aplicado sem necessidade é overhead cognitivo.

Padrões agrupados por categoria. Para cada um: quando usar, quando recusar, exemplo aplicado em Spring quando relevante.

## Criacionais

### Factory Method
**Quando:** construção de objeto com invariante complexa ou que varia por contexto. Particularmente útil para aggregate DDD.

**Spring idiom:** método estático nomeado no próprio aggregate.
```java
public class Pedido {
    private Pedido(...) { /* privado */ }
    
    public static Pedido novo(ClienteId cliente, List<Item> itens) {
        if (itens.isEmpty()) throw new PedidoInvalidoException("sem itens");
        return new Pedido(PedidoId.gerar(), cliente, itens, Status.RASCUNHO);
    }
    
    public static Pedido reconstituir(PedidoId id, ..., Status status) {
        // sem validação — usado pelo repository ao carregar do banco
        return new Pedido(id, ..., status);
    }
}
```

**Recuse:** Factory para `new SimpleClasse()` sem regra de criação.

### Abstract Factory
**Quando:** família de objetos relacionados precisa ser criada junto (UI multiplataforma, drivers de banco).

**Em Spring:** raramente necessário. O container já é a factory abstrata via `@Bean` + `@Profile`/`@ConditionalOn...`.

### Builder
**Quando:** objeto com muitos campos opcionais legítimos.

**Antes de usar:** considere `record` com construtor canônico + factory methods nomeados. Builder só compensa em 6+ campos com combinações reais.

```java
Pedido pedido = Pedido.builder()
    .cliente(clienteId)
    .adicionarItem(item1)
    .adicionarItem(item2)
    .cupomDesconto("BLACK10")
    .enderecoEntrega(endereco)
    .build();
```

**Recuse:** Builder para POJO de 3 campos. Use construtor.

### Prototype
**Quando:** clonar objeto caro de criar. Raro em backend Java moderno.

**Recuse na maioria dos casos.** Java tem `Cloneable` problemático; prefira copy constructor explícito ou `record` com `with...()`.

### Singleton
**Quando:** uma única instância faz sentido global (cache, registry, container).

**Em Spring:** **não escreva Singleton manual.** Beans são singleton por padrão. `Singleton` manual quebra teste, cria estado oculto, dificulta substituição.

## Estruturais

### Adapter
**Quando:** adaptar interface incompatível. Coração de Hexagonal — porta de saída é interface no domínio, adapter na infra.

```java
// Porta no domínio
interface PagamentoGateway { ResultadoPagamento processar(Pagamento p); }

// Adapter para Stripe
@Component
class StripeAdapter implements PagamentoGateway {
    private final StripeClient stripe;
    public ResultadoPagamento processar(Pagamento p) {
        var charge = stripe.charges().create(...);
        return traduzirParaDominio(charge);
    }
}
```

### Bridge
**Quando:** separar abstração de implementação para variarem independentemente. Útil em drivers, sistemas multi-banco.

**Raramente necessário em aplicação de negócio típica.**

### Composite
**Quando:** estrutura em árvore tratada uniformemente (menu, organograma, expressão).

```java
sealed interface ComponenteRelatorio permits Item, Grupo {}
record Item(String nome, BigDecimal valor) implements ComponenteRelatorio {}
record Grupo(String titulo, List<ComponenteRelatorio> filhos) implements ComponenteRelatorio {}
```

### Decorator
**Quando:** adicionar comportamento sem alterar a classe (log, cache, retry, métrica).

**Em Spring:** prefira AOP (`@Cacheable`, `@Retryable`, `@Transactional`) — é Decorator implementado pelo container. Decorator manual só quando AOP não couber.

```java
// AOP cobre 90% dos casos
@Cacheable("produtos")
public Produto buscar(Long id) { ... }

// Decorator manual quando precisar de controle fino
class CachedProdutoRepository implements ProdutoRepository {
    private final ProdutoRepository delegate;
    private final Cache<Long, Produto> cache;
    
    public Produto buscar(Long id) {
        return cache.get(id, k -> delegate.buscar(k));
    }
}
```

### Facade
**Quando:** simplificar API complexa para o cliente. Application Service em Hexagonal é Facade do domínio.

```java
@Service
class CheckoutFacade {
    void executar(CheckoutRequest req) {
        var carrinho = carrinhoService.carregar(req.clienteId());
        var frete = freteService.calcular(carrinho, req.endereco());
        var pagamento = pagamentoService.processar(...);
        pedidoService.criar(...);
        notificacaoService.confirmar(...);
    }
}
```

### Flyweight
**Quando:** muitos objetos com estado parcialmente compartilhável (caracteres em editor de texto, ícones em mapa).

**Raro em backend.** JVM já faz interning de String, autoboxing de Integer pequenos.

### Proxy
**Quando:** controle de acesso, lazy loading, remoting.

**Em Spring:** o container usa Proxy massivamente (CGLIB/JDK Proxy para `@Transactional`, `@Async`, `@Cacheable`). Você raramente escreve Proxy manual.

**Gotcha:** método `private` ou chamada `this.metodo()` **não passa pelo proxy** — anotações são ignoradas.

## Comportamentais

### Chain of Responsibility
**Quando:** pipeline de validação/processamento onde cada passo decide se trata ou passa adiante.

```java
interface ValidadorPedido {
    void validar(Pedido p, ValidadorPedido proximo);
}

@Component @Order(1)
class ValidadorEstoque implements ValidadorPedido { ... }

@Component @Order(2)
class ValidadorCredito implements ValidadorPedido { ... }
```

**Em Spring:** filtros HTTP (`Filter`, `HandlerInterceptor`) são Chain of Responsibility nativos.

### Command
**Quando:** encapsular operação como objeto. Base de CQRS (write side), undo/redo, fila de tarefas.

```java
record CriarPedidoCommand(ClienteId cliente, List<ItemRequest> itens) {}

@Service
class CriarPedidoHandler {
    public PedidoId handle(CriarPedidoCommand cmd) { ... }
}
```

### Interpreter
**Quando:** DSL própria (regex, query language).

**Raro.** Use parser combinator ou biblioteca pronta antes de escrever Interpreter.

### Iterator
**Quando:** percorrer coleção sem expor estrutura.

**Em Java moderno:** `Iterable`, `Stream`, `for-each` resolvem. Não escreva Iterator manual.

### Mediator
**Quando:** múltiplos objetos colaboram via hub central, reduzindo acoplamento mútuo.

**Sinal de uso:** componentes não conhecem uns aos outros, falam via mediator. Spring `ApplicationEventPublisher` é Mediator interno.

### Memento
**Quando:** capturar/restaurar estado interno (undo, snapshot, save game).

**Em DDD:** snapshot de aggregate para Event Sourcing usa Memento.

### Observer
**Quando:** reagir a evento sem acoplamento direto. **Base de event-driven.**

**Em Spring:**
- Síncrono local: `ApplicationEventPublisher` + `@EventListener`.
- Assíncrono local: `@EventListener` + `@Async`.
- Distribuído: Kafka/RabbitMQ.

```java
// Publica
applicationEventPublisher.publishEvent(new PedidoConfirmado(pedidoId));

// Escuta
@EventListener
public void on(PedidoConfirmado evento) { ... }
```

### State
**Quando:** comportamento varia com estado interno; `if (status == X)` espalhado.

```java
sealed interface EstadoPedido {
    EstadoPedido confirmar();
    EstadoPedido cancelar();
}
record Rascunho(...) implements EstadoPedido {
    public EstadoPedido confirmar() { return new Confirmado(...); }
    public EstadoPedido cancelar() { return new Cancelado(...); }
}
record Confirmado(...) implements EstadoPedido {
    public EstadoPedido confirmar() { throw new TransicaoInvalida(); }
    public EstadoPedido cancelar() { return new Cancelado(...); }
}
```

### Strategy
**Quando:** algoritmo varia por contexto (frete, desconto, cálculo de imposto).

Ver exemplo em SOLID/OCP. Em Spring, injete `Map<String, Strategy>` ou `List<Strategy>` com `@Component` + qualifier.

### Template Method
**Quando:** algoritmo com esqueleto fixo e passos variáveis.

**Cuidado:** acoplamento por herança. Prefira Strategy via composição na maioria dos casos. Use Template Method quando há reuso real de estrutura e os passos são intrinsecamente parte do mesmo algoritmo.

### Visitor
**Quando:** operação que varia, estrutura que não. Útil em AST, hierarquia fechada.

**Em Java 21:** pattern matching em `switch` + `sealed` substitui Visitor com menos boilerplate.

```java
sealed interface Forma permits Circulo, Retangulo, Triangulo {}

double area(Forma f) {
    return switch (f) {
        case Circulo c -> Math.PI * c.raio() * c.raio();
        case Retangulo r -> r.largura() * r.altura();
        case Triangulo t -> t.base() * t.altura() / 2;
    };
}
```

## Padrões além do GoF (referenciados frequentemente)

- **Repository** — abstrai persistência de aggregate. Ver `ddd.md`.
- **Specification** — encapsula regra de negócio composta. Ver `ddd.md`.
- **Unit of Work** — agrupa operações em transação. Em JPA, o `EntityManager` é Unit of Work.
- **Saga** — transação distribuída. Ver `event-driven.md`.
- **Outbox** — publicação atômica de evento. Ver `event-driven.md`.
- **CQRS** — separação leitura/escrita. Ver `cqrs.md`.

## Anti-padrões transversais

- **Padrão como martelo:** aplicar GoF sem identificar o problema que ele resolve.
- **Nome do padrão escondendo intenção:** `OrderProcessor` é melhor que `OrderCommandStrategy`.
- **Combo desnecessário:** Factory + Builder + Strategy + Observer para criar um pedido.
- **Padrão para "futura flexibilidade":** crie a abstração quando a segunda implementação aparecer, não antes.
