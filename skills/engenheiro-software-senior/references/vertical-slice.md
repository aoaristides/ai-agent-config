# Vertical Slice Architecture — organização por feature

Vertical Slice (popularizada por **Jimmy Bogard**) organiza o código **por feature**, não por camada técnica. Cada feature é uma "fatia vertical" que atravessa todas as camadas (HTTP → validação → handler → persistência → resposta), mantida junta em um único lugar.

**Origem:** comunidade .NET, frequentemente combinada com MediatR. Em Java/Spring, é menos comum mas perfeitamente aplicável.

> **Confusão comum:** "pacotes por feature" (que recomendamos no SKILL.md) **não é** Vertical Slice. Pacotes por feature ainda usa camadas internas (controller/service/repository) dentro de cada pacote. Vertical Slice é mais radical: **menos abstração compartilhada, duplicação intencional preferida sobre acoplamento entre features**.

**Use quando:** projeto médio sem complexidade de domínio profunda, time prefere navegação por feature, CRUD-heavy com regras moderadas, microsserviço com poucas features bem definidas.

**Não use quando:** domínio rico com muitas invariantes compartilhadas (use Clean/Hexagonal + DDD), código tem alta reutilização real entre features (não duplicação superficial), time já está produtivo com arquitetura em camadas.

## Princípio central

**Minimize o que é compartilhado entre features. Maximize a coesão dentro de cada feature.**

Em arquitetura tradicional (por camada):
- Mudar uma feature exige tocar 4-5 arquivos em pastas diferentes.
- Reutilização "obrigatória" via service base, mapper compartilhado, exceção genérica.
- Acoplamento entre features cresce com o tempo.

Em Vertical Slice:
- Cada feature é uma unidade quase autossuficiente.
- Duplicação é aceita quando o custo de abstrair é maior que o custo de duplicar.
- Reutilização **emerge** depois da terceira ocorrência, não antes.

## Estrutura de pacotes

### Arquitetura tradicional (por camada)
```
com.empresa.pedidos/
├── controller/
│   ├── PedidoController.java
│   └── ItemController.java
├── service/
│   ├── PedidoService.java
│   └── ItemService.java
├── repository/
│   ├── PedidoRepository.java
│   └── ItemRepository.java
└── dto/
    ├── PedidoRequest.java
    ├── PedidoResponse.java
    └── ItemDto.java
```

### Vertical Slice
```
com.empresa.pedidos/
├── features/
│   ├── criar_pedido/
│   │   ├── CriarPedidoCommand.java      (record do request)
│   │   ├── CriarPedidoResponse.java
│   │   ├── CriarPedidoValidator.java
│   │   ├── CriarPedidoHandler.java      (lógica + persistência)
│   │   └── CriarPedidoController.java
│   │
│   ├── confirmar_pedido/
│   │   ├── ConfirmarPedidoCommand.java
│   │   ├── ConfirmarPedidoHandler.java
│   │   └── ConfirmarPedidoController.java
│   │
│   ├── listar_pedidos/
│   │   ├── ListarPedidosQuery.java
│   │   ├── PedidoListView.java          (DTO próprio, sem reuso)
│   │   ├── ListarPedidosHandler.java
│   │   └── ListarPedidosController.java
│   │
│   └── cancelar_pedido/
│       ├── CancelarPedidoCommand.java
│       ├── CancelarPedidoHandler.java
│       └── CancelarPedidoController.java
│
└── shared/                              ← APENAS o que é genuinamente compartilhado
    ├── Pedido.java                       (aggregate, se houver)
    └── PedidoId.java                     (value object)
```

**Cada feature é navegável como uma unidade.** Para entender "criar pedido", abra `features/criar_pedido/` — está tudo lá.

## Exemplo: feature completa

```java
// features/criar_pedido/CriarPedidoCommand.java
public record CriarPedidoCommand(
    UUID clienteId,
    List<ItemRequest> itens,
    EnderecoRequest endereco
) {
    public record ItemRequest(UUID produtoId, int quantidade) {}
    public record EnderecoRequest(String cep, String rua, String numero) {}
}
```

```java
// features/criar_pedido/CriarPedidoResponse.java
public record CriarPedidoResponse(UUID pedidoId, BigDecimal valorTotal, String status) {}
```

```java
// features/criar_pedido/CriarPedidoHandler.java
@Component
@RequiredArgsConstructor
class CriarPedidoHandler {
    private final JdbcTemplate jdbc;
    private final EventPublisher publisher;
    
    @Transactional
    public CriarPedidoResponse handle(CriarPedidoCommand cmd) {
        // validação inline ou em validator dedicado da feature
        if (cmd.itens().isEmpty()) {
            throw new ValidacaoException("itens", "pedido sem itens");
        }
        
        // persistência direta — sem repository abstrato
        var pedidoId = UUID.randomUUID();
        jdbc.update("""
            INSERT INTO pedidos (id, cliente_id, status, valor_total, criado_em)
            VALUES (?, ?, 'RASCUNHO', ?, ?)
            """, pedidoId, cmd.clienteId(), calcularTotal(cmd.itens()), Instant.now());
        
        for (var item : cmd.itens()) {
            jdbc.update("""
                INSERT INTO itens_pedido (pedido_id, produto_id, quantidade)
                VALUES (?, ?, ?)
                """, pedidoId, item.produtoId(), item.quantidade());
        }
        
        publisher.publicar(new PedidoCriado(pedidoId, cmd.clienteId(), Instant.now()));
        
        return new CriarPedidoResponse(pedidoId, calcularTotal(cmd.itens()), "RASCUNHO");
    }
    
    private BigDecimal calcularTotal(List<CriarPedidoCommand.ItemRequest> itens) {
        // se essa lógica aparecer em outra feature, vai para shared. Não antes.
        return /* ... */;
    }
}
```

```java
// features/criar_pedido/CriarPedidoController.java
@RestController
@RequestMapping("/pedidos")
@RequiredArgsConstructor
class CriarPedidoController {
    private final CriarPedidoHandler handler;
    
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public CriarPedidoResponse criar(@Valid @RequestBody CriarPedidoCommand cmd) {
        return handler.handle(cmd);
    }
}
```

**Tudo da feature em um lugar.** Sem `PedidoService` gigante. Sem `PedidoRepository` que cresce a cada feature nova.

## Combinação natural com CQRS

Vertical Slice combina muito bem com CQRS (ver `cqrs.md`):

- Cada feature é um **Command** ou **Query** + seu **Handler**.
- Write side e read side **não compartilham model** — cada query tem seu DTO próprio.

Em .NET, o padrão típico é **MediatR**: `mediator.Send(command)` dispatcha para o handler certo. Em Java/Spring, basta injetar o handler diretamente — ou usar uma biblioteca tipo Axon Framework se quiser o pattern.

## Trade-offs honestos

### Ganhos
- **Navegação por feature** — entender uma funcionalidade é abrir uma pasta.
- **Onboarding mais rápido** — não precisa entender 4 camadas para tocar em 1 endpoint.
- **Mudança localizada** — feature nova não obriga refactor de service compartilhado.
- **Delete fácil** — feature obsoleta? Apaga a pasta inteira.
- **Menos abstração prematura** — cada handler decide como persistir, validar, mapear.

### Custos
- **Duplicação real** — mesma query SQL pode aparecer em 3 features. Aceito intencionalmente.
- **Regra de negócio dispersa** — se "pedido só pode ser confirmado em RASCUNHO" precisa estar em `confirmar_pedido/Handler.java` e em `cancelar_pedido/Handler.java`, duplicou. Sem domain model rico, regras viram comentário ou esquecidas.
- **Menos guard rails** — sem service compartilhado, é fácil cada feature implementar diferente.
- **Difícil em domínio rico** — quando há aggregate com 20 invariantes, espalhar por features quebra encapsulamento.

## Vertical Slice vs Clean/Hexagonal/Onion

| Aspecto | Clean/Hexagonal/Onion | Vertical Slice |
|---|---|---|
| Organização | Por camada técnica | Por feature |
| Foco principal | Proteger domínio de infra | Coesão dentro da feature |
| Compartilhamento | Abundante (use case usa domain service usa repository) | Mínimo (cada feature autossuficiente) |
| Reutilização | Premiada | Postergada (duplica até 3ª ocorrência) |
| Domínio rico | Excelente | Difícil |
| CRUD-heavy | Cerimônia desnecessária | Excelente |
| Time grande compartilhando código | Funciona com disciplina | Funciona melhor (features isoladas) |
| Onboarding | Curva mais alta | Curva menor |

**Não são mutuamente exclusivas:** é possível organizar por feature **dentro** de uma Clean Architecture. A feature `criar_pedido/` pode conter `application/`, `domain/`, `infrastructure/` internos. Mas aí já é híbrido — e híbridos exigem disciplina dobrada.

**Recomendação prática:** se o domínio é rico (DDD), prefira Clean/Hexagonal/Onion + pacotes por contexto. Se é CRUD com regras moderadas e o time valoriza navegabilidade, considere Vertical Slice puro.

## Aplicação parcial — slices "anêmicos" e "ricos"

Padrão útil de Bogard: **nem toda feature precisa do mesmo peso**.

- **Slice anêmico:** CRUD trivial. Handler curto, persistência direta, sem domain model.
- **Slice rico:** regra complexa. Handler delega para aggregate de domínio dentro da própria feature.

Pragmático: features simples ficam simples; features complexas ganham estrutura. Sem forçar todas no mesmo nível de cerimônia.

## Anti-padrões

- **"Shared" gigante** — se `shared/` cresce mais que `features/`, perdeu o ponto.
- **Service base obrigatório** que todas as features estendem — voltou para arquitetura em camadas mal disfarçada.
- **Vertical Slice em domínio rico** sem aggregate, com regra duplicada em 5 handlers — bug em produção garantido.
- **MediatR/dispatcher cult** — em Spring, `@Autowired` no handler resolve sem indireção. Não importe complexidade .NET sem motivo.
- **Refatorar Clean Architecture grande para Vertical Slice "porque está na moda"** — custo enorme, ganho duvidoso.
- **Vertical Slice + DDD tático completo** — frequentemente conflitam. Escolha.

## Quando migrar para Vertical Slice

Sintomas que sugerem benefício:
- `PedidoService` com 30 métodos sem coesão.
- Mudar uma feature toca 6 arquivos em pastas diferentes.
- Onboarding de dev novo demora porque "tem que entender a estrutura inteira".
- Feature flag para feature nova é dor porque o código está espalhado.
- Apagar feature antiga é refactor de uma semana.

**Cuidado:** migração não precisa ser big-bang. Pode-se começar isolando uma feature nova em `features/nova_feature/` e migrar as antigas só quando tocá-las.

## Checklist

- O domínio é simples o suficiente para suportar duplicação sem virar bug?
- O time aceita que reutilização vem depois, não antes?
- Há aggregate ou value object genuinamente compartilhado em `shared/`?
- Cada feature consegue ser entendida abrindo apenas sua pasta?
- A pasta `shared/` está sob controle (não cresce sem critério)?
- Existe regra para "promover" código duplicado para shared (ex.: 3ª ocorrência)?

## Ver também

- **`cqrs.md`** — Vertical Slice combina naturalmente com Command/Query/Handler.
- **`clean-architecture.md`** e **`hexagonal.md`** — alternativas para domínio rico; podem coexistir parcialmente com Vertical Slice em projeto híbrido.
- **`ddd.md`** — para entender quando o domínio é rico demais para Vertical Slice puro.
- **`gof.md`** — Command pattern é a base conceitual do handler por feature.
