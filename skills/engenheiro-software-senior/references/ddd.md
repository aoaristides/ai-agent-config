# DDD — Domain-Driven Design aplicado

DDD existe para resolver **complexidade de domínio**, não complexidade técnica. Aplicar DDD em CRUD ou em fluxo técnico fino é cerimônia sem retorno.

**Use quando:** regras de negócio densas, em evolução; múltiplos especialistas de domínio; linguagem do negócio é fonte recorrente de bug.

**Não force quando:** domínio é trivial, time pequeno, escopo curto, ou o problema é integração técnica pura.

## DDD estratégico (a parte mais importante e mais ignorada)

### Bounded Context

Fronteira explícita onde um modelo de domínio é consistente. **Cliente** no contexto de Vendas não é o mesmo **Cliente** no contexto de Cobrança — atributos diferentes, comportamentos diferentes, ciclo de vida diferente.

**Erro clássico:** tentar criar um "modelo canônico de cliente" que serve para tudo. Resulta em entidade obesa, regras misturadas, deploys acoplados.

### Ubiquitous Language

A linguagem do código bate com a linguagem que o especialista de negócio usa. Se o negócio fala "pedido confirmado" e o código fala `OrderStatusChangedToApproved`, está errado.

**Aplicação prática:**
- Glossário versionado por bounded context.
- Nome de classe, método, evento, endpoint reflete a linguagem.
- Discrepância detectada vira refactor, não nota de rodapé.

### Context Map

Mapa de como os bounded contexts se relacionam. Padrões mais usados:

- **Shared Kernel:** dois contextos compartilham um pequeno núcleo de modelo. Frágil — exige coordenação forte. Evite quando possível.
- **Customer/Supplier:** um contexto consome outro; o supplier prioriza necessidades do customer no roadmap.
- **Conformist:** consumer aceita o modelo do upstream como está (sem ACL). Usado quando o upstream é estável e bem desenhado.
- **Anti-Corruption Layer (ACL):** camada de tradução protege o seu modelo do modelo do upstream. **Default ao integrar com legado ou sistema externo.**
- **Open Host Service + Published Language:** o upstream expõe contrato versionado (REST + OpenAPI, eventos + AsyncAPI/schema registry) para múltiplos consumers.
- **Separate Ways:** dois contextos não se integram. Às vezes a melhor decisão.

## DDD tático

### Aggregate

Cluster de objetos tratado como uma unidade. Tem uma **raiz** (aggregate root) que é o único ponto de acesso externo. Aggregate protege **invariantes** — regras que devem ser verdade o tempo todo.

**Regras:**
- Um aggregate, uma transação. Atualizou dois aggregates na mesma transação? Provavelmente erro de design.
- Referência entre aggregates por **id**, não por objeto. `Pedido` tem `ClienteId`, não `Cliente`.
- Aggregate pequeno é melhor que grande. Grande aggregate vira hotspot de contenção.

```java
public class Pedido {  // aggregate root
    private final PedidoId id;
    private final ClienteId clienteId;  // referência por id
    private final List<ItemPedido> itens;  // entidades internas
    private Status status;
    
    // construtor privado, factory pública
    public static Pedido novo(ClienteId clienteId, List<ItemPedido> itens) {
        if (itens.isEmpty()) throw new PedidoInvalidoException("sem itens");
        return new Pedido(PedidoId.gerar(), clienteId, new ArrayList<>(itens), Status.RASCUNHO);
    }
    
    public void adicionarItem(ItemPedido item) {  // invariante protegida no método
        if (status != Status.RASCUNHO) throw new PedidoNaoEditavel();
        if (item.quantidade() <= 0) throw new QuantidadeInvalida();
        itens.add(item);
    }
    
    public PedidoConfirmado confirmar() {
        if (status != Status.RASCUNHO) throw new TransicaoInvalida();
        this.status = Status.CONFIRMADO;
        return new PedidoConfirmado(id, clienteId, Instant.now());
    }
}
```

### Entity

Tem identidade contínua ao longo do tempo. Dois pedidos com os mesmos atributos mas ids diferentes são pedidos diferentes.

### Value Object

Identificado por seus atributos. Imutável. Sem identidade própria.

```java
public record Dinheiro(BigDecimal valor, Moeda moeda) {
    public Dinheiro {
        Objects.requireNonNull(valor);
        Objects.requireNonNull(moeda);
        if (valor.scale() > moeda.casasDecimais()) {
            throw new IllegalArgumentException("escala incompatível");
        }
    }
    
    public Dinheiro somar(Dinheiro outro) {
        if (!moeda.equals(outro.moeda)) throw new MoedasIncompativeis();
        return new Dinheiro(valor.add(outro.valor), moeda);
    }
}
```

**Use VO sempre que possível.** Reduz bug, expressa intenção. `BigDecimal preco` é menos seguro que `Dinheiro preco`.

### Domain Event

Fato relevante que aconteceu no domínio. Sempre no passado, no particípio: `PedidoConfirmado`, `PagamentoRecusado`. Imutável. Carrega o necessário para consumers reagirem.

```java
public record PedidoConfirmado(
    PedidoId pedidoId,
    ClienteId clienteId,
    Instant ocorridoEm
) implements DomainEvent {}
```

**Quem publica:** o aggregate gera o evento; o application service publica via porta. Não acople o aggregate ao publisher.

### Repository

Abstração de persistência de aggregate. Interface no domínio, implementação na infra.

```java
public interface PedidoRepository {
    Optional<Pedido> buscarPorId(PedidoId id);
    void salvar(Pedido pedido);
}
```

**Não vire CRUD genérico.** Repository tem os métodos que o **domínio precisa**, não `findAll`, `count`, `findByExample`. Spring Data `JpaRepository` é tentação — não exponha como porta do domínio.

### Specification

Encapsula regra de negócio composta. Permite combinar com `and`/`or`/`not` e testar isolada.

```java
public interface Specification<T> {
    boolean isSatisfiedBy(T candidato);
    default Specification<T> and(Specification<T> outra) {
        return c -> this.isSatisfiedBy(c) && outra.isSatisfiedBy(c);
    }
}

class PedidoElegivelParaDesconto implements Specification<Pedido> {
    public boolean isSatisfiedBy(Pedido p) {
        return p.valorTotal().valor().compareTo(new BigDecimal("500")) >= 0
            && !p.temItensComDescontoIndividual();
    }
}
```

### Domain Service

Operação de domínio que **não pertence naturalmente a um aggregate**. Ex.: transferência entre contas (envolve duas contas), cálculo que depende de múltiplos aggregates.

**Cuidado:** muito service é sinal de domínio anêmico. Antes de criar service, pergunte se o método pertence ao aggregate.

### Factory

Construção de aggregate complexo. Pode ser método estático no aggregate (preferido) ou classe Factory separada (quando construção tem dependência externa).

## Domínio anêmico — o anti-padrão central

Sintomas:
- Aggregate só com getter/setter.
- Toda regra está em service (`PedidoService.confirmar(pedido)` que muta o pedido via setter).
- `pedido.setStatus(Status.CONFIRMADO)` chamado por código de fora.

**Fix:** mova a regra para dentro do aggregate. `pedido.confirmar()` decide e muta. Service orquestra.

## Event Storming (descoberta de domínio)

Workshop para mapear o domínio com especialistas. Em uma parede (física ou virtual):

1. **Eventos de domínio** (laranja): "Pedido Confirmado", "Pagamento Recusado", "Estoque Reservado".
2. **Comandos** (azul) que disparam eventos.
3. **Atores** (amarelo) que disparam comandos.
4. **Aggregates** (amarelo grande) que recebem comandos e produzem eventos.
5. **Políticas** (lilás): "quando Pagamento Recusado, cancelar pedido em 24h".
6. **Bounded Contexts** emergem como agrupamentos.

**Quando usar:** início de produto, redesign, migração de monolito (identificar seams).

## Checklist DDD

- Aggregate tem regra de invariante protegida no construtor/método? Ou só getter/setter?
- Referência entre aggregates é por id?
- Domain event é fato no passado, imutável, sem dependência de infra?
- Bounded contexts estão explícitos (pastas, módulos, repositórios)?
- Linguagem do código bate com a do negócio? Existe glossário?
- Tem ACL ao integrar com legado/externo?
- Repository expõe operações do domínio ou virou CRUD genérico?
- Service domina o código (sintoma de anemia) ou orquestra (correto)?

## Ver também

- **`hexagonal.md`** e **`clean-architecture.md`** — onde colocar aggregate, value object e port na estrutura de pacotes; como manter o domínio puro de framework.
- **`gof.md`** — implementação de Repository, Specification, Factory Method e State no contexto de aggregate.
- **`event-driven.md`** — publicação de domain events como integration events, Outbox, Saga entre bounded contexts.
- **`cqrs.md`** — separar modelo de escrita (aggregate DDD) de modelo de leitura (projeções otimizadas).
- **`solid.md`** — princípios aplicados no desenho de aggregate (SRP por invariante, OCP via Strategy em domain service).
