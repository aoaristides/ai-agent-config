# CQRS — Command Query Responsibility Segregation

CQRS separa o modelo de **escrita** do modelo de **leitura**. Não é "ter classes Command e Query" — é assumir que os dois modelos podem ter **estruturas, banco e ciclo de vida diferentes**.

**Use quando:** escrita e leitura têm requisitos divergentes; leitura tem volume muito maior e padrão de acesso específico (relatórios, dashboards, busca complexa); domínio de escrita é complexo (DDD tático aplicado).

**Não force quando:** leitura é simples (CRUD com `findById`, `findAll` filtrado); time pequeno; volume baixo.

CQRS adiciona complexidade. Adote em camadas — comece sem, evolua quando a dor aparecer.

## Níveis de CQRS

### Nível 1 — separação de modelos no mesmo banco

Mesma base de dados, mas:
- **Write side:** aggregate DDD, repository com operações de domínio.
- **Read side:** projeção em DTO/View, queries SQL otimizadas, sem passar pelo aggregate.

```java
// Write side
public class Pedido { /* aggregate, regras, invariantes */ }

@Service
class ConfirmarPedidoUseCase {
    @Transactional
    public void executar(PedidoId id) {
        var pedido = pedidoRepository.buscarPorId(id).orElseThrow();
        pedido.confirmar();
        pedidoRepository.salvar(pedido);
    }
}

// Read side — direto, otimizado
@Repository
class PedidoQueryRepository {
    private final JdbcTemplate jdbc;
    
    public List<PedidoListView> listarParaDashboard(ClienteId cliente, Periodo periodo) {
        return jdbc.query("""
            SELECT p.id, p.status, p.valor_total, c.nome as cliente_nome, 
                   COUNT(i.id) as qtd_itens
            FROM pedidos p
            JOIN clientes c ON c.id = p.cliente_id
            JOIN itens_pedido i ON i.pedido_id = p.id
            WHERE p.cliente_id = ? AND p.criado_em BETWEEN ? AND ?
            GROUP BY p.id, p.status, p.valor_total, c.nome
            """, ..., PedidoListView.ROW_MAPPER);
    }
}
```

**Vantagem:** sem complexidade extra de infra. Query usa JDBC/SQL direto, sem mapeamento JPA para o caminho de leitura.

**Custo:** baixo. Frequentemente vale a pena adotar mesmo em sistemas pequenos.

### Nível 2 — bancos separados (read replica)

Write side em um banco, read side em uma **réplica de leitura** (replicação nativa do banco). Mesmo schema.

**Vantagem:** distribui carga, isola queries pesadas.
**Custo:** lag de replicação (consistência eventual no read).

### Nível 3 — modelos de leitura projetados (CQRS pleno)

Write side mantém aggregate. Eventos de domínio alimentam **projeções** otimizadas para casos de leitura específicos. Pode ser banco diferente (Postgres → Elasticsearch para busca, ou → Redis para cache de view, ou → tabela desnormalizada).

```
[Write side]                    [Eventos]                [Read side]
  Aggregate ──confirmar()──→ PedidoConfirmado ──→ Projeção PedidoListView
                                                  Projeção PedidoBuscaIndex (ES)
                                                  Projeção PedidoMetricas
```

```java
@Component
class ProjecaoListView {
    private final ListViewRepository repo;
    
    @KafkaListener(topics = "pedidos.confirmados")
    public void on(PedidoConfirmadoEvent evento) {
        var view = new PedidoListView(
            evento.pedidoId(),
            evento.clienteId(),
            evento.clienteNome(),
            evento.valorTotal(),
            "CONFIRMADO",
            evento.itens().size(),
            evento.em()
        );
        repo.salvar(view);  // tabela desnormalizada otimizada para listagem
    }
}
```

**Vantagem:** cada read side é otimizado para seu caso. Escala independente.
**Custo:** consistência eventual, mais código, mais infra, mais pontos de falha.

## Quando subir de nível

Sintomas que indicam que vale evoluir:

- Listagem trava com JPA por causa de relacionamento (N+1, fetch desnecessário).
- Query de relatório precisa de view materializada ou cache.
- Domínio de escrita está complicado por causa de exigências de leitura ("preciso desse campo aqui só pra mostrar na tela").
- Read tem volume 10x+ maior que write.
- Busca full-text, faceted search, analytics — requisitos que SQL relacional resolve mal.

## Command, Query, Handler

Padrão de organização do código (independe do nível de CQRS):

```java
// Command — intenção de mudar estado
public record CriarPedidoCommand(
    ClienteId clienteId,
    List<ItemRequest> itens,
    EnderecoEntrega endereco
) {}

// Handler
@Service
class CriarPedidoHandler {
    @Transactional
    public PedidoId handle(CriarPedidoCommand cmd) {
        var pedido = Pedido.novo(cmd.clienteId(), traduzir(cmd.itens()));
        pedidoRepository.salvar(pedido);
        return pedido.id();
    }
}

// Query — pedido de leitura
public record ListarPedidosQuery(
    ClienteId clienteId,
    Periodo periodo,
    Pageable paginacao
) {}

@Service
class ListarPedidosHandler {
    private final PedidoQueryRepository queryRepo;
    
    public Page<PedidoListView> handle(ListarPedidosQuery q) {
        return queryRepo.listar(q.clienteId(), q.periodo(), q.paginacao());
    }
}
```

**Não use bibliotecas de "mediator" (MediatR-like)** sem necessidade — adicionam indireção. `@Service` injetado direto funciona.

## Consistência eventual — a pegadinha

No Nível 3, write e read **estão fora de sincronia por algum tempo**. Cliente confirma pedido e ainda não vê na listagem? Possível. Lida com isso:

- **UI mostra estado intermediário:** "pedido sendo processado".
- **Read-your-writes:** após mutação, retorna dado direto do write side (não da projeção).
- **Polling/SSE/WebSocket** quando confirmação é importante.
- **Idempotência no consumer** para reprocessar sem duplicar.
- **Monitoramento de lag** — alerta se a projeção atrasar.

Não esconda o problema. Estime e exponha a janela de inconsistência.

## CQRS + Event Sourcing

Combinação natural mas **não obrigatória**. Event Sourcing persiste eventos no write side; projeções alimentam o read. Os dois resolvem problemas diferentes — adote por necessidade, não por pacote.

Ver `event-driven.md` seção "Event Sourcing — cuidado".

## Quando recusar CQRS

- Domínio é CRUD genuíno, leitura e escrita usam o mesmo modelo sem dor.
- Time não entende a separação — vão escrever "command" e "query" como sinônimo de "POST" e "GET".
- Consistência forte é requisito não-negociável **e** o nível 1 (mesmo banco) não basta.
- Volume baixo, otimização prematura.

## Anti-padrões

- **CQRS "decorativo":** classes `XxxCommand` e `XxxQuery` sem separação real de modelo.
- **Reutilizar entidade JPA no read side:** perde o ponto. O read side é projeção, não a mesma entidade.
- **Projeção sem ownership claro:** quem mantém a coerência? Quem replay? Quem corrige drift?
- **Sem monitoramento de lag** entre write e read.
- **Esconder consistência eventual** do usuário e do cliente da API.
- **CQRS adotado por moda** em CRUD simples.

## Checklist

- Há motivo concreto para separar leitura de escrita (volume, complexidade, padrão de acesso)?
- Em qual nível vou começar (1, 2, 3)?
- Consistência eventual é aceitável no caso de uso? Como vou lidar com a janela?
- Projeção tem dono, replay, monitoramento?
- Read side está otimizado de fato, ou só mudou de pasta?

## Ver também

- **`event-driven.md`** — eventos como mecanismo de alimentação de projeções no read side.
- **`vertical-slice.md`** — combinação natural: cada feature = Command/Query + Handler dedicado.
- **`ddd.md`** — write side em CQRS opera sobre aggregates DDD; read side é projeção sem aggregate.
- **`gof.md`** — Command pattern é a base conceitual do write side.
