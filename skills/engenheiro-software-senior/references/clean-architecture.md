# Clean Architecture — visão de Uncle Bob aplicada

Clean Architecture (Robert C. Martin, 2012/2017) é a síntese de várias arquiteturas que compartilham o mesmo objetivo: **independência do framework, da UI, do banco, e de qualquer agente externo**. O resultado é uma estrutura em **camadas concêntricas** com uma única regra inegociável de dependência.

**Veja também `hexagonal.md`.** Hexagonal e Clean compartilham o núcleo (regra da dependência). Clean é mais prescritivo: nomeia 4 camadas, eleva caso de uso a artefato de primeira classe, e introduz Screaming Architecture. Escolha uma nomenclatura e mantenha — misturar Use Case + Interactor + Application Service para o mesmo conceito gera confusão.

## A Regra da Dependência

> O código de fora pode depender do código de dentro. O código de dentro **não pode saber nada** do código de fora.

Esta é a única regra que importa. Tudo o resto deriva dela.

**Consequência prática:** uma entidade não importa uma classe de aplicação. Uma classe de aplicação não importa um controller, um repository JPA, um cliente HTTP. Quando você precisar atravessar a fronteira "para fora" (ex.: caso de uso precisa persistir), use **inversão de dependência** — defina uma interface dentro, implemente fora.

## As quatro camadas

Do centro para fora:

```
                ┌─────────────────────────────┐
                │   Frameworks & Drivers      │  ← Spring Boot, JPA, Kafka client,
                │                             │     drivers de banco, frameworks
                │   ┌─────────────────────┐   │
                │   │ Interface Adapters  │   │  ← Controllers, Presenters,
                │   │                     │   │     Gateways, Repositories (impl),
                │   │   ┌─────────────┐   │   │     DTOs, Mappers
                │   │   │ Use Cases   │   │   │
                │   │   │             │   │   │  ← Application business rules,
                │   │   │  ┌───────┐  │   │   │     Interactors, casos de uso
                │   │   │  │Entities│ │   │   │
                │   │   │  │       │  │   │   │  ← Enterprise business rules,
                │   │   │  └───────┘  │   │   │     entidades, value objects
                │   │   └─────────────┘   │   │
                │   └─────────────────────┘   │
                └─────────────────────────────┘
```

### Camada 1 — Entities (Enterprise Business Rules)

Regras de negócio que **independem da aplicação**. Se sua empresa tem 5 sistemas diferentes, as Entities seriam reutilizáveis entre eles. Ex.: regra "saldo não pode ficar negativo" vale em qualquer sistema da empresa.

Em DDD tático, esta camada hospeda **aggregates, value objects, domain events, specifications, domain services**.

```java
// Entity — pura, sem framework
public class Conta {
    private final ContaId id;
    private Dinheiro saldo;
    
    public void debitar(Dinheiro valor) {
        if (saldo.menorQue(valor)) {
            throw new SaldoInsuficienteException();
        }
        this.saldo = saldo.subtrair(valor);
    }
}
```

### Camada 2 — Use Cases (Application Business Rules)

Regras de negócio **específicas da aplicação** — orquestração de Entities para atingir um objetivo de usuário. Um caso de uso é **um verbo** observável do ponto de vista do usuário: `TransferirDinheiro`, `ConfirmarPedido`, `CancelarAssinatura`.

Cada caso de uso é **uma classe** (ou record + handler). Não agrupe em "Service" genérico.

```java
// Use case — depende de portas, não de implementações
public class TransferirDinheiroUseCase {
    private final ContaRepository contaRepo;
    private final NotificadorTransferencia notificador;
    
    public TransferirDinheiroUseCase(ContaRepository contaRepo, 
                                      NotificadorTransferencia notificador) {
        this.contaRepo = contaRepo;
        this.notificador = notificador;
    }
    
    public TransferenciaResult executar(TransferirDinheiroInput input) {
        var origem = contaRepo.buscarPorId(input.origemId()).orElseThrow();
        var destino = contaRepo.buscarPorId(input.destinoId()).orElseThrow();
        
        origem.debitar(input.valor());
        destino.creditar(input.valor());
        
        contaRepo.salvar(origem);
        contaRepo.salvar(destino);
        notificador.notificar(new TransferenciaRealizada(...));
        
        return TransferenciaResult.sucesso(...);
    }
}
```

**Input e Output Boundaries (DTOs):**
```java
public record TransferirDinheiroInput(ContaId origemId, ContaId destinoId, Dinheiro valor) {}
public record TransferenciaResult(...) {}
```

### Camada 3 — Interface Adapters

Adapta dados entre o formato do mundo externo e o formato dos casos de uso/entities. **Controllers, Presenters, Gateways, Repositories (implementação), Mappers, DTOs HTTP.**

```java
// Adapter — implementa porta definida na camada interna
@Component
public class ContaRepositoryJpaAdapter implements ContaRepository {
    private final ContaJpaRepository jpa;
    private final ContaMapper mapper;
    
    public Optional<Conta> buscarPorId(ContaId id) {
        return jpa.findById(id.value()).map(mapper::paraDominio);
    }
    
    public void salvar(Conta conta) {
        jpa.save(mapper.paraJpa(conta));
    }
}

// Controller — adapter de entrada
@RestController
@RequestMapping("/transferencias")
public class TransferenciaController {
    private final TransferirDinheiroUseCase useCase;
    
    @PostMapping
    public ResponseEntity<TransferenciaHttpResponse> transferir(@RequestBody TransferenciaHttpRequest req) {
        var input = new TransferirDinheiroInput(...);
        var result = useCase.executar(input);
        return ResponseEntity.ok(TransferenciaHttpResponse.de(result));
    }
}
```

### Camada 4 — Frameworks & Drivers

Spring Boot, Hibernate, Kafka client, driver JDBC, servidor HTTP. **Detalhes**, no sentido de Uncle Bob — devem ser substituíveis. Idealmente, esta camada é configuração e *bootstrap*, não regra.

## Screaming Architecture

> A arquitetura do projeto deveria gritar o **domínio**, não o framework.

Ao abrir a raiz do projeto, você deveria ver pastas como `pedidos/`, `pagamentos/`, `estoque/` — não `controllers/`, `services/`, `repositories/`.

**Errado (grita o framework):**
```
src/main/java/com/empresa/
├── controllers/
├── services/
├── repositories/
└── entities/
```

**Certo (grita o domínio):**
```
src/main/java/com/empresa/
├── pedidos/
│   ├── domain/
│   ├── usecase/
│   ├── adapter/
│   └── web/
├── pagamentos/
│   ├── domain/
│   ├── usecase/
│   ├── adapter/
│   └── web/
└── estoque/
    └── ...
```

Esta organização é **por bounded context**, alinhada com DDD estratégico (ver `ddd.md`).

## Estrutura de pacotes recomendada (por bounded context)

```
com.empresa.pedidos/
├── domain/                          ← Entities (Camada 1)
│   ├── model/
│   │   ├── Pedido.java
│   │   ├── ItemPedido.java
│   │   └── PedidoId.java
│   ├── event/
│   │   └── PedidoConfirmado.java
│   └── exception/
│       └── PedidoInvalidoException.java
│
├── usecase/                         ← Use Cases (Camada 2)
│   ├── port/
│   │   ├── in/                      ← input boundary (interface do use case)
│   │   │   └── ConfirmarPedidoUseCase.java
│   │   └── out/                     ← output boundary (portas)
│   │       ├── PedidoRepository.java
│   │       └── NotificadorPedido.java
│   ├── ConfirmarPedidoInteractor.java
│   └── dto/
│       ├── ConfirmarPedidoInput.java
│       └── ConfirmarPedidoOutput.java
│
├── adapter/                         ← Interface Adapters (Camada 3)
│   ├── persistence/
│   │   ├── PedidoJpaEntity.java
│   │   ├── PedidoJpaRepository.java
│   │   ├── PedidoRepositoryJpaAdapter.java  (implementa port out)
│   │   └── PedidoMapper.java
│   ├── messaging/
│   │   └── KafkaNotificadorAdapter.java
│   └── web/
│       ├── PedidoController.java
│       ├── PedidoHttpRequest.java
│       └── PedidoHttpResponse.java
│
└── config/                          ← Frameworks & Drivers (Camada 4)
    └── PedidoBeansConfig.java
```

**Variação comum:** algumas equipes preferem `infrastructure/` no lugar de `adapter/`. Funciona, mas "adapter" comunica mais o papel.

## Use Case como artefato de primeira classe — o diferencial

Em Clean, **cada caso de uso é uma classe nomeada com o verbo de negócio**. Não:

```java
@Service
public class PedidoService {
    public Pedido criar(...) { ... }
    public void confirmar(...) { ... }
    public void cancelar(...) { ... }
    public List<Pedido> listar(...) { ... }
    public void atualizar(...) { ... }
}  // ← service "balde", sem coesão
```

Sim:

```java
public class CriarPedidoUseCase { ... }
public class ConfirmarPedidoUseCase { ... }
public class CancelarPedidoUseCase { ... }
public class ListarPedidosUseCase { ... }
public class AtualizarPedidoUseCase { ... }
```

**Benefícios:**
- Cada classe pequena, foco único (SRP).
- Dependências injetadas são apenas o necessário para aquele caso (ISP).
- Teste isolado por caso de uso.
- O nome do arquivo conta a história do sistema — abrir `usecase/` é ler o catálogo de funcionalidades.

**Custo:** muitas classes pequenas. Aceitável quando a granularidade reflete intenção de negócio real.

## Input Boundary, Output Boundary, Presenter

Conceitos formais de Clean. Na prática Java moderna, frequentemente simplificados:

- **Input Boundary:** interface do caso de uso (`ConfirmarPedidoUseCase` é a interface; `ConfirmarPedidoInteractor` é a implementação). Permite que o controller dependa de abstração.
- **Output Boundary (Presenter):** interface que o caso de uso usa para *entregar* o resultado, em vez de retornar valor direto. Útil quando há múltiplas saídas (HTTP + evento + métrica) ou diferentes formatos.
- **DTO de Input/Output:** dados que cruzam a fronteira.

**Simplificação pragmática:** se o caso de uso retorna `Output` por valor e o controller decide o que fazer, você ganha simplicidade sem perder essência. Presenter explícito faz sentido quando há múltiplos canais de saída.

## Independência de framework — o que isso significa de verdade

Uncle Bob diz que o framework é "detalhe". Pragmaticamente, isso não significa que você **não usa** Spring — significa que **Spring não invade** as camadas internas.

**Aplicado:**
- Entities **nunca** têm `@Entity`, `@Column`, `@JsonProperty`, `@Component`.
- Use Cases podem ter `@Service` (é DI, aceitável), mas **nunca** `@Transactional` na camada interna ideal. **Pragmática:** colocar `@Transactional` no use case é tolerável em Spring se o time aceita o trade-off.
- Adapters podem ter qualquer anotação Spring — eles **são** o ponto de contato com o framework.

**Pragmatismo:** Clean Architecture pura proíbe Spring inclusive no use case. Na prática Spring brasileira, a maioria das equipes coloca `@Service` e `@Transactional` no use case e mantém Entities 100% limpas. É um trade-off consciente.

## Testes — o teste é a justificativa central

A vantagem maior de Clean é que **regra de negócio testa sem framework, sem banco, sem HTTP**:

```java
// Entity test — JUnit puro
class ContaTest {
    @Test
    void deve_recusar_debito_maior_que_saldo() {
        var conta = new Conta(id, new Dinheiro("100"));
        assertThatThrownBy(() -> conta.debitar(new Dinheiro("150")))
            .isInstanceOf(SaldoInsuficienteException.class);
    }
}

// Use case test — JUnit + mocks de port, sem Spring
class TransferirDinheiroUseCaseTest {
    ContaRepository repo = mock(ContaRepository.class);
    NotificadorTransferencia notif = mock(NotificadorTransferencia.class);
    TransferirDinheiroUseCase useCase = new TransferirDinheiroUseCase(repo, notif);
    
    @Test
    void deve_transferir_e_notificar() {
        when(repo.buscarPorId(origemId)).thenReturn(Optional.of(contaCom("1000")));
        when(repo.buscarPorId(destinoId)).thenReturn(Optional.of(contaCom("500")));
        
        useCase.executar(new TransferirDinheiroInput(origemId, destinoId, new Dinheiro("200")));
        
        verify(notif).notificar(any(TransferenciaRealizada.class));
        verify(repo, times(2)).salvar(any(Conta.class));
    }
}
```

Adapters testam com Testcontainers ou MockMvc. Integração end-to-end é a ponta da pirâmide — minoria dos testes.

## Quando NÃO usar Clean Architecture

- **CRUD genuíno** sem regra de negócio. A cerimônia de 4 camadas custa mais do que entrega.
- **Microserviço fino** (gateway, proxy, transformação). Adapter direto basta.
- **Prototipação / spike** com prazo curto. Adote depois se o código sobreviver.
- **Time sem maturidade** — Clean exige disciplina, sem ela vira "pastas vazias" e domínio anêmico (ver `ddd.md`).

## Diferenças entre Clean e Hexagonal — quando elas importam

| Aspecto | Hexagonal | Clean |
|---|---|---|
| **Foco** | Simetria portas/adapters | Camadas concêntricas com regra da dependência |
| **Use Case** | Não é conceito formal (pode estar em "application service") | Conceito de primeira classe, classe por caso de uso |
| **Camadas nomeadas** | Não impõe nomes | Impõe: Entities, Use Cases, Interface Adapters, Frameworks |
| **Screaming Architecture** | Não enfatiza | Enfatiza explicitamente |
| **Vocabulário** | Mais simples (porta, adapter) | Mais rico (boundary, interactor, presenter, gateway) |

**Na prática:** se você está em Java/Spring com domínio complexo, **Clean dá mais estrutura** (mais nomes, mais arquivos, mais clareza). Se o domínio é médio e o time prefere mínima cerimônia, **Hexagonal é mais leve**.

Combine o que faz sentido. Estrutura de pacotes do exemplo acima é Clean por dentro (camadas) e Hexagonal por fora (portas/adapters explícitos). Não há conflito — há complementaridade.

## Anti-padrões específicos de Clean

- **Clean "decorativa":** 4 pastas vazias com `Service` gigante chamando tudo. Domínio anêmico travestido de Clean.
- **Pastas por camada técnica global** (`com.empresa.controllers/`, `com.empresa.usecases/`). Quebra Screaming Architecture. Pacotes devem ser **por contexto**, e camadas dentro de cada contexto.
- **`@Entity` JPA na camada Entities.** Polui o domínio com framework. Use entidade JPA separada no adapter e mapeie.
- **Use Case que retorna `Entity` ou `JpaEntity`** para o controller. Use Output DTO.
- **Controller chamando Repository direto**, pulando Use Case. Use Case **é** a aplicação — sem ele, virou MVC tradicional com pastas a mais.
- **Use Case que chama outro Use Case sem necessidade.** Geralmente sinal de orquestração mal-modelada. Considere se é um caso de uso composto legítimo ou se está acoplando demais.
- **Presenter para tudo.** Use quando há múltiplos canais de saída ou formatos. Em CRUD HTTP simples, retornar Output direto basta.

## Checklist de revisão

- Estrutura grita o domínio (pacotes por contexto), não o framework?
- Entities têm regra de negócio (métodos com invariante) ou só getter/setter?
- Cada caso de uso é uma classe própria, com nome verbal?
- Use Cases dependem de **portas** (interfaces na camada interna), não de implementações JPA/HTTP?
- Implementações dos adapters traduzem entre o modelo externo (JPA, HTTP, Kafka) e o modelo de domínio?
- Há DTO de Input/Output explícito atravessando as fronteiras?
- Teste de Entity e Use Case roda sem Spring, sem banco, sem HTTP?
- Spring/JPA/Jackson **não vazam** para domínio nem use case (exceto `@Service`/`@Transactional` se trade-off aceito)?

## Ver também

- **`hexagonal.md`** — abordagem irmã, mais minimalista, com ênfase em ports/adapters simétricos.
- **`onion.md`** — abordagem irmã, com anéis concêntricos e domain services em anel próprio.
- **`vertical-slice.md`** — alternativa que organiza por feature; pode coexistir parcialmente com Clean em projeto híbrido.
- **`ddd.md`** — Entities da Clean correspondem aos aggregates e value objects do DDD; Use Cases consomem domain services.
- **`solid.md`** — Clean é a aplicação sistemática de DIP em escala arquitetural.
