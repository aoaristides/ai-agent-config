# Onion Architecture — aplicação prática

Onion (Jeffrey Palermo, 2008) organiza o sistema em **anéis concêntricos** com uma regra única e estrita: **dependências apontam para dentro, nunca para fora**. Cada anel só conhece os anéis mais internos.

> **Veja também `hexagonal.md` e `clean-architecture.md`.** Onion, Hexagonal e Clean compartilham o mesmo núcleo conceitual (regra da dependência). Onion enfatiza os **anéis concêntricos** e dá lugar explícito para **domain services** entre domain model e application services. Hexagonal enfatiza simetria ports/adapters. Clean é mais prescritiva (4 camadas nomeadas + Use Cases como artefato de primeira classe). Escolha uma — não misture vocabulário.

**Use quando:** domínio complexo, regra estrita de dependência radial, time confortável com "anéis" como metáfora.

**Não force quando:** Hexagonal ou Clean já são adotadas pelo time. Onion raramente adiciona algo que essas não cobrem, e mudar vocabulário sem ganho concreto gera confusão.

## Os anéis (de dentro para fora)

```
┌─────────────────────────────────────────┐
│  Infrastructure (UI, DB, External APIs)  │  ← anel mais externo
│  ┌───────────────────────────────────┐  │
│  │  Application Services             │  │  ← orquestra use cases
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Domain Services            │  │  │  ← regra que atravessa aggregates
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │  Domain Model         │  │  │  │  ← entidade, value object, port
│  │  │  └───────────────────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### 1. Domain Model (centro)
Aggregate, entity, value object, **interfaces de repositório/serviço (ports)**. Zero dependência de framework. Idêntico em propósito ao "domínio" de Hexagonal e às "Entities" de Clean.

### 2. Domain Services
Regra de domínio que **atravessa múltiplos aggregates** ou não pertence naturalmente a nenhum (ex.: cálculo que depende de duas contas, política que envolve cliente + pedido + estoque). Aqui está a **diferença mais visível** de Onion para Hexagonal: Onion dá um anel próprio para isso; Hexagonal coloca tudo dentro do "domínio" sem subdividir.

### 3. Application Services
Orquestra os use cases. Abre transação, chama domain services, persiste via port, publica evento. Equivalente aos "Use Cases" da Clean Architecture e aos "application services" da Hexagonal.

### 4. Infrastructure
Adapters concretos: JPA repository, Kafka producer/consumer, HTTP client, REST controller, mensageria, framework Spring. Implementa as ports definidas no domain model.

## Regra única e estrita

**Dependência aponta para dentro, sempre.** Nunca o contrário. Isso vale dentro do código (imports) e na ordem dos pacotes/módulos:

- ✅ Application Service usa Domain Service.
- ✅ Domain Service usa Domain Model.
- ✅ Infrastructure implementa port do Domain Model.
- ❌ Domain Model importa Application Service.
- ❌ Domain Service importa Infrastructure.
- ❌ Domain Model importa JPA, Spring, HTTP, Kafka.

## Estrutura de pacotes (Spring)

```
com.empresa.pedidos/
├── domain/                          ← anel 1: Domain Model
│   ├── model/
│   │   ├── Pedido.java              (aggregate root)
│   │   ├── ItemPedido.java
│   │   ├── PedidoId.java            (value object)
│   │   └── Status.java
│   ├── event/
│   │   └── PedidoConfirmado.java
│   └── port/
│       ├── PedidoRepository.java    (definido no anel mais interno)
│       └── NotificadorPedido.java
│
├── domainservice/                   ← anel 2: Domain Services
│   ├── CalculadoraFrete.java        (depende de Pedido + Endereco + Transportadora)
│   └── PoliticaDesconto.java        (depende de Cliente + Pedido + Cupom)
│
├── application/                     ← anel 3: Application Services
│   ├── CriarPedidoService.java
│   └── ConfirmarPedidoService.java
│
└── infrastructure/                  ← anel 4: Infrastructure
    ├── persistence/
    │   └── PedidoRepositoryJpaAdapter.java
    ├── messaging/
    │   └── KafkaNotificadorAdapter.java
    └── api/
        ├── PedidoController.java
        └── PedidoControllerAdvice.java
```

**Diferença prática vs Hexagonal:** o pacote `domainservice/` existe como anel separado. Em Hexagonal, isso fica em `domain/` mesmo, sem subdivisão.

## Exemplo: Domain Service em Onion

```java
// Anel 2 — Domain Service
package com.empresa.pedidos.domainservice;

import com.empresa.pedidos.domain.model.Pedido;
import com.empresa.pedidos.domain.model.Endereco;
import com.empresa.pedidos.domain.model.Transportadora;

public class CalculadoraFrete {
    public Dinheiro calcular(Pedido pedido, Endereco destino, List<Transportadora> opcoes) {
        // regra que atravessa aggregates: precisa de Pedido + Endereco + Transportadora
        return opcoes.stream()
            .map(t -> t.calcularPara(pedido.peso(), pedido.dimensoes(), destino))
            .min(Comparator.comparing(Dinheiro::valor))
            .orElseThrow(() -> new SemFretePossivelException(destino));
    }
}
```

```java
// Anel 3 — Application Service usa o Domain Service
package com.empresa.pedidos.application;

@Service
@RequiredArgsConstructor
class CriarPedidoService {
    private final PedidoRepository repository;          // port do anel 1
    private final CalculadoraFrete calculadoraFrete;    // anel 2
    private final TransportadoraRepository transportadoraRepo;  // port do anel 1
    
    @Transactional
    public PedidoId executar(CriarPedidoCommand cmd) {
        var pedido = Pedido.novo(cmd.cliente(), cmd.itens());
        var transportadoras = transportadoraRepo.listarAtivas();
        var frete = calculadoraFrete.calcular(pedido, cmd.destino(), transportadoras);
        pedido.aplicarFrete(frete);
        repository.salvar(pedido);
        return pedido.id();
    }
}
```

## Quando o domain service é cheiro de domínio anêmico

**Atenção:** muito domain service é sintoma de anemia, não de aplicação correta do padrão. Antes de criar `CalculadoraFrete`, pergunte se a regra pertence a algum aggregate. Pertence ao `Pedido.calcularFrete(destino, transportadoras)`? Em geral, sim — só vire domain service quando a regra realmente precisar de **múltiplos aggregates** e não puder caber em nenhum sem violar invariantes.

Regra prática: se você tem 5 domain services e cada aggregate só tem getter/setter, **isso é Transaction Script disfarçado de Onion**, não DDD.

## Diferenças Onion vs Hexagonal vs Clean

| Aspecto | Hexagonal | Onion | Clean |
|---|---|---|---|
| Metáfora | Hexágono (simetria entrada/saída) | Anéis concêntricos | Círculos concêntricos com camadas nomeadas |
| Ênfase | Ports + Adapters | Regra de dependência radial | Use Cases + Screaming Architecture |
| Domain Service | Dentro do domínio, sem anel | Anel próprio (anel 2) | Dentro de Entities ou Use Cases |
| Use Case | Application Service | Application Service | Use Case / Interactor (artefato de primeira classe) |
| Boundary explícito | Port | Interface no anel mais interno | Input/Output Boundary + Presenter |
| Estrutura de pasta sugerida | Menos prescritiva | Anéis explícitos | 4 camadas nomeadas |
| Quem criou | Cockburn (2005) | Palermo (2008) | Uncle Bob (2012) |

**Na prática:** as três resolvem o mesmo problema (proteger o domínio de detalhes de infraestrutura). Diferem em vocabulário e nível de prescrição.

**Recomendação:** se está começando, escolha entre **Hexagonal** (mais leve) ou **Clean** (mais estruturada). **Onion é uma terceira opção** que faz sentido principalmente quando o time já gosta da metáfora de anéis e quando há volume real de domain services que justifica o anel próprio.

## Anti-padrões

- **"Onion" só na pasta:** anéis declarados, mas domínio anêmico e regra toda em service.
- **Muito domain service:** sintoma de Transaction Script, não de Onion bem feito.
- **Vazamento entre anéis:** Application Service importando `EntityManager` direto.
- **Mistura de vocabulário:** falar "Use Case" + "Interactor" + "Application Service" para o mesmo conceito.
- **Migrar de Hexagonal para Onion sem ganho concreto:** mudar nomenclatura por estética gera refactor sem retorno.
- **Port no anel errado:** Onion exige ports no anel mais interno (Domain Model). Definir port em Application Service viola a regra.

## Checklist

- Anéis estão claros como pacotes ou módulos?
- A regra de dependência radial é validada (test, ArchUnit)?
- Domain services existem porque há regra entre aggregates, ou são Transaction Script disfarçado?
- Ports estão definidos no anel mais interno (Domain Model)?
- O time entende e usa a metáfora de anéis, ou só herdou o nome?

## Ver também

- **`hexagonal.md`** — abordagem irmã, mais minimalista, com ênfase em ports/adapters.
- **`clean-architecture.md`** — abordagem irmã, mais prescritiva, com Use Cases como artefato de primeira classe.
- **`ddd.md`** — Onion combina naturalmente com DDD tático. Aggregate, value object, domain event são os habitantes do anel mais interno.
- **`solid.md`** — DIP em escala arquitetural: as ports no anel interno são a inversão de dependência canônica.
