# SOLID — princípios aplicados com critério

SOLID é guia de **coesão e acoplamento**, não checklist. Aplicar sem entender o problema gera abstração prematura e código pior. Cada princípio resolve um sintoma específico — sem o sintoma, não force.

## S — Single Responsibility Principle

> Uma classe deve ter uma única razão para mudar.

**O que significa na prática:** "razão para mudar" = stakeholder/contexto que pede a mudança. Não confunda com "fazer uma coisa só" — uma classe pode ter vários métodos e ainda ter uma responsabilidade.

**Sintoma de violação:**
- Mudança de regra fiscal mexe na mesma classe que mudança de layout de relatório.
- Classe tem `e` no nome ("ClienteEEnderecoService").
- Imports vêm de domínios sem relação entre si.

**Aplicação em Spring:**
```java
// Ruim: service faz validação, cálculo, persistência e envio de email
class PedidoService {
    void criar(PedidoRequest req) { /* 200 linhas */ }
}

// Bom: cada responsabilidade tem dono
class CriarPedidoUseCase {
    private final PedidoValidator validator;
    private final CalculadorFrete calculadorFrete;
    private final PedidoRepository repository;
    private final NotificadorPedido notificador;
    // orquestra, não decide
}
```

**Quando não forçar:** classe pequena, coesa, mesmo com 2-3 responsabilidades relacionadas. Extrair vira ruído.

## O — Open/Closed Principle

> Aberto para extensão, fechado para modificação.

**O que significa na prática:** adicionar comportamento novo sem alterar código existente. Usa polimorfismo, Strategy, plugin.

**Sintoma de violação:**
- `if-else` ou `switch` crescendo a cada nova regra (`if (tipo == FRETE_SEDEX) ... else if (tipo == PAC) ...`).
- Toda regra nova exige mexer na mesma classe.

**Aplicação:**
```java
interface CalculadorFrete {
    BigDecimal calcular(Pedido pedido);
}

@Component("sedex")
class SedexCalculador implements CalculadorFrete { ... }

@Component("pac")
class PacCalculador implements CalculadorFrete { ... }

@Service
class FreteService {
    private final Map<String, CalculadorFrete> estrategias; // Spring injeta o map
    
    BigDecimal calcular(Pedido pedido) {
        return estrategias.get(pedido.tipoFrete()).calcular(pedido);
    }
}
```

**Quando não forçar:** só há uma implementação e não há sinal real de novas. Crie a abstração quando a **segunda** implementação aparecer.

## L — Liskov Substitution Principle

> Subtipos devem ser substituíveis pelos seus tipos base sem quebrar o comportamento.

**O que significa na prática:** contrato da superclasse/interface vale para todos os filhos. Se a subclasse lança exceção que a base não lançava, ou ignora parâmetros, **viola LSP**.

**Sintoma de violação:**
- `if (obj instanceof TipoEspecifico)` espalhado.
- Método sobrescrito lança `UnsupportedOperationException`.
- Pré-condições mais fortes ou pós-condições mais fracas na subclasse.

**Exemplo clássico (anti-padrão):**
```java
class Retangulo {
    void setLargura(int l) { this.largura = l; }
    void setAltura(int a) { this.altura = a; }
}
class Quadrado extends Retangulo {
    void setLargura(int l) { this.largura = l; this.altura = l; } // viola LSP
}
```

**Fix:** `Quadrado` não é um `Retangulo` no sentido comportamental. Modele como tipos separados ou via composição.

## I — Interface Segregation Principle

> Clientes não devem depender de interfaces que não usam.

**O que significa na prática:** interface gorda força implementação de método irrelevante. Prefira interfaces pequenas e específicas.

**Sintoma de violação:**
- Implementação cheia de `throw new UnsupportedOperationException()`.
- Mock de teste implementando 15 métodos para usar 2.

**Aplicação:**
```java
// Ruim
interface PedidoRepository {
    Pedido buscar(Long id);
    void salvar(Pedido p);
    List<Pedido> relatorioMensal();
    void exportarParaCsv(OutputStream os);
}

// Bom
interface PedidoRepository { Pedido buscar(Long id); void salvar(Pedido p); }
interface PedidoRelatorio { List<Pedido> mensal(); }
interface PedidoExporter { void exportarCsv(OutputStream os); }
```

## D — Dependency Inversion Principle

> Dependa de abstrações, não de implementações concretas. Módulos de alto nível não dependem de módulos de baixo nível.

**O que significa na prática:** o domínio define a **porta** (interface); a infraestrutura implementa o **adapter**. Isso é o coração de Hexagonal/Clean Architecture.

**Aplicação:**
```java
// Domínio (alto nível) define a porta
package com.empresa.pedidos.domain;
public interface NotificadorPedido {
    void notificarConfirmacao(Pedido pedido);
}

// Application service usa a porta
@Service
class ConfirmarPedidoUseCase {
    private final NotificadorPedido notificador; // depende da abstração
}

// Infraestrutura (baixo nível) implementa o adapter
package com.empresa.pedidos.infra.email;
@Component
class EmailNotificadorAdapter implements NotificadorPedido {
    public void notificarConfirmacao(Pedido p) { /* envia email */ }
}
```

A seta de dependência aponta **para dentro** (infra → domínio), não o contrário.

## Anti-padrões SOLID

- **"SOLID religioso":** criar interface para classe que tem uma única implementação eterna, "por garantia". Gera ruído, prejudica navegação.
- **Single Responsibility levado ao extremo:** classe com um único método de 3 linhas, espalhada em 20 arquivos. Coesão também conta.
- **Open/Closed via herança profunda:** árvore de 5 níveis de subclasse. Prefira composição + Strategy.
- **DIP "decorativo":** interface no domínio que só existe por causa de teste, sem real inversão (a interface conhece detalhe da implementação).

## Checklist de revisão

- A classe tem mais de uma razão real para mudar? → considere quebrar (SRP).
- `if/switch` por tipo cresce com cada feature nova? → Strategy (OCP).
- Subclasse precisa de `instanceof` para funcionar? → herança errada (LSP).
- Interface tem método que metade dos implementadores ignora? → quebre (ISP).
- Classe de domínio importa pacote de infraestrutura (JPA, HTTP)? → inverta (DIP).

## Ver também

- **`gof.md`** — Strategy, Decorator, Adapter e outros padrões que implementam SOLID na prática (especialmente OCP e DIP).
- **`hexagonal.md`** e **`clean-architecture.md`** — DIP em escala arquitetural: portas no domínio, adapters fora.
- **`ddd.md`** — SRP aplicado a aggregates (uma razão de mudar = uma regra de invariante).
