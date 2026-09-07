# Cell-based Architecture — isolamento de falhas em escala

Cell-based Architecture é um **padrão operacional de resiliência**, não uma arquitetura de código. A aplicação é dividida em **células independentes**, cada uma servindo um subconjunto de usuários. Falha em uma célula não derruba o sistema inteiro — apenas degrada a parte que ela atendia.

Popularizada por **AWS**, **Slack**, **Roblox**, **Doordash**. É padrão de **escala extrema e disponibilidade extrema**.

> **Nota sobre ambiguidade do termo:** "cell-based architecture" também é usado pela **WSO2** como modelo de organização de microsserviços em "células" como unidade de governança, com gateway próprio por célula. Esta referência cobre o **significado operacional (AWS-style)** — isolamento de falhas. Para a versão WSO2, ver docs próprios da plataforma.

**Use quando:** SLA muito alto (99.99%+), blast radius é requisito não-funcional, escala global, multi-tenant com tenants isoláveis, custo de outage é alto demais para tolerar falha em cascata.

**Não use quando:** sistema é pequeno/médio, time não tem maturidade operacional para multiplicar instâncias, multi-AZ + multi-region tradicional já atende ao SLA. Cell-based é **caro** — instâncias replicadas, infra multiplicada, complexidade de roteamento.

## Conceitos essenciais

### Cell (célula)
**Unidade de isolamento.** Uma célula contém todos os componentes necessários para servir um subconjunto de requisições: app, banco, cache, fila. Células são **independentes** — não compartilham banco, não compartilham cache, não compartilham estado.

Pensar como **mini-instâncias completas do sistema**, cada uma servindo um shard de usuários.

### Cell Router (Roteador)
**Único ponto compartilhado** entre células. Recebe a requisição, decide qual célula atende, encaminha. Frequentemente é um load balancer ou gateway HTTP fino com lógica de roteamento.

**Regra crítica:** o roteador precisa ser **extremamente simples e estável**. É o único componente cuja falha derruba todas as células. Sem lógica de negócio, sem persistência, sem dependência externa complexa.

### Cell Partition Key
Como decidir qual célula atende a requisição. Opções comuns:

| Estratégia | Quando usar | Cuidado |
|---|---|---|
| **Tenant ID / Account ID** | SaaS multi-tenant. Cada cliente vive em uma célula. | Hot tenant (cliente gigante) desbalanceia. |
| **User ID hash** | App consumer-facing com muitos usuários parecidos. | Distribuição uniforme, mas usuário sempre na mesma célula. |
| **Geographic region** | Workload global com afinidade regional. | Falha regional afeta tudo dali. |
| **Random + sticky** | Sessões anônimas. | Reroteamento em failover requer estado. |

### Blast Radius (raio de explosão)
**Métrica central do padrão.** Quantos usuários são afetados por uma falha? Em sistema monolítico tradicional, blast radius = 100%. Em cell-based com 10 células, blast radius por célula = 10%.

Trade-off: mais células = menor blast radius por célula, mas mais infra para operar.

## Arquitetura típica

```
                ┌──────────────────────┐
                │   Cell Router        │  ← simples, estável, sem estado
                │   (LB + lookup)      │
                └──────────┬───────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Cell A      │  │   Cell B      │  │   Cell C      │
│ ┌─────────┐   │  │ ┌─────────┐   │  │ ┌─────────┐   │
│ │ Apps    │   │  │ │ Apps    │   │  │ │ Apps    │   │
│ ├─────────┤   │  │ ├─────────┤   │  │ ├─────────┤   │
│ │ DB      │   │  │ │ DB      │   │  │ │ DB      │   │
│ ├─────────┤   │  │ ├─────────┤   │  │ ├─────────┤   │
│ │ Cache   │   │  │ │ Cache   │   │  │ │ Cache   │   │
│ ├─────────┤   │  │ ├─────────┤   │  │ ├─────────┤   │
│ │ Queue   │   │  │ │ Queue   │   │  │ │ Queue   │   │
│ └─────────┘   │  │ └─────────┘   │  │ └─────────┘   │
└───────────────┘  └───────────────┘  └───────────────┘
   Tenants 1-100      Tenants 101-200    Tenants 201-300
```

Cada célula é **uma stack completa**. Falha em Cell B → tenants 101-200 afetados; Cells A e C seguem normais.

## Estratégias importantes

### Bulkhead estendido
Cell-based é Bulkhead pattern levado ao extremo arquitetural. Em vez de isolar pool de threads ou conexões dentro de uma instância, isola **toda a stack** entre subgrupos de usuários.

### Shuffle Sharding
Variante poderosa: em vez de mapear cada tenant para **uma** célula, mapeia para **um subconjunto pequeno** de células (ex.: 2 entre 10). Probabilidade de dois tenants compartilharem o mesmo conjunto exato é baixa. Falha em uma célula → cada tenant afetado tem outra(s) célula(s) para fallback.

Trade-off: mais complexidade de roteamento, mas resiliência muito maior. AWS Route 53 usa shuffle sharding internamente.

### Cell Migration
Tenant pode mudar de célula (rebalanceamento, hot tenant, manutenção). Exige:
- **Dual-write temporário** durante migração.
- **Lookup atualizado** no Cell Router após corte.
- **Idempotência** em todas as operações para tolerar entregas duplicadas durante a janela.

### Deploy Independente por Célula
**Padrão obrigatório em cell-based maduro:** deploy primeiro em 1 célula, valida métricas, expande. Bug grave fica contido em uma célula enquanto se reverte.

## Implementação em cloud

### AWS
- **Route 53** com health check + DNS failover ou **API Gateway** custom authorizer com lookup de célula.
- **Cell Router** como Lambda + DynamoDB de mapeamento, ou ALB com regras de routing.
- **Cada célula** = sua própria VPC ou conjunto de subnets, RDS próprio, ElastiCache próprio, SQS próprio.
- **Isolamento de conta AWS por célula** em casos extremos — falha em conta não afeta outras (limite de blast radius máximo).
- Ver `aws.md` para serviços base; nada específico de cell-based é "AWS-only", mas a documentação AWS é a fonte mais rica do padrão.

### GCP
- **Cloud Load Balancing** global como Cell Router.
- **Cada célula** = projeto GCP próprio, ou conjunto de recursos com rótulos consistentes.
- **Cloud SQL / Spanner** por célula.
- Ver `gcp.md`.

### Azure
- **Front Door** como Cell Router com health probes.
- **Cada célula** = resource group próprio.
- Ver `azure.md`.

## Aplicação em Java/Spring — o que muda no código?

**Honestidade primeiro:** cell-based é decisão **operacional/infraestrutural**, não de código. O Spring Boot que roda dentro de cada célula é **idêntico** ao monolito ou microsserviço tradicional. O que muda:

### Identificação de célula no contexto
Toda requisição precisa carregar o `cellId` ou ser roteável para a célula correta. Em Spring:

```java
@Component
class CellContextFilter implements Filter {
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) {
        var httpReq = (HttpServletRequest) req;
        var cellId = httpReq.getHeader("X-Cell-Id");  // injetado pelo Cell Router
        MDC.put("cellId", cellId);  // entra em todo log
        CellContext.set(cellId);
        try {
            chain.doFilter(req, res);
        } finally {
            CellContext.clear();
            MDC.remove("cellId");
        }
    }
}
```

### Configuração por célula
Cada célula tem sua config (banco diferente, fila diferente). Use Spring Profiles ou config externa:

```yaml
spring:
  profiles:
    active: ${CELL_ID:cell-a}

---
spring:
  config:
    activate:
      on-profile: cell-a
  datasource:
    url: jdbc:postgresql://cell-a-db:5432/pedidos
```

### Cross-cell calls — evite
**Regra de ouro:** célula **não chama outra célula** em fluxo síncrono. Se um usuário em Cell A precisa de dado de Cell B, há erro de design — ou o usuário está na célula errada, ou o sharding está mal definido.

Quando comunicação entre células é necessária (analytics agregada, billing cross-tenant), faça **assíncrono** via eventos/Kafka/Pub/Sub centralizados, fora das células. Ver `event-driven.md`.

## Anti-padrões

- **"Microsserviços = células"** — não. Microsserviço é decomposição por bounded context. Célula é replicação isolada da stack inteira por shard de usuários. São ortogonais; pode ter microsserviços **dentro** de cada célula.
- **Router gordo** com lógica de negócio — o router precisa ser estúpido e estável. Lógica vai para dentro da célula.
- **Banco compartilhado** entre células — anula o padrão. Cada célula tem seu banco.
- **Shared cache global** entre células — idem.
- **Cell-based sem deploy independente** — perde-se a vantagem de blast radius reduzido.
- **Cell-based em sistema pequeno** — overhead absurdo, multi-AZ resolveria.
- **Hot tenant em uma única célula** sem shuffle sharding — uma célula vira gargalo.
- **Falta de runbook para migração de célula** — quando vira necessário, é tarde.
- **Custo não monitorado** — multiplicar infra multiplica custo.

## Quando NÃO usar Cell-based

- **Sistema pequeno/médio** com SLA 99.9% — multi-AZ tradicional resolve com fração do custo.
- **Time sem maturidade SRE** — operar 10 células é operar 10 sistemas. Sem automação, é insustentável.
- **Workload sem afinidade natural** (sem tenant, sem region, sem shard óbvio) — força de partition key vira hack.
- **Quando o custo de outage é menor que o custo de operar células** — análise fria.

## Checklist antes de adotar

- O SLA exige isolamento de falhas além de multi-AZ?
- Existe partition key natural (tenant, region, user shard)?
- Time tem maturidade para operar N stacks paralelas, com deploy independente, monitoramento por célula, runbook de migração?
- Roteador foi desenhado simples e estável?
- Estratégia para hot partition (shuffle sharding, manual rebalancing)?
- Plano para comunicação cross-cell (assíncrono, fora das células)?
- Custo estimado e aprovado?

## Ver também

- **`event-driven.md`** — comunicação cross-cell é sempre assíncrona; padrões de evento, outbox, schema registry aplicam.
- **`cqrs.md`** — agregações cross-cell (analytics, billing) frequentemente são read models alimentados por eventos das células.
- **`aws.md`**, **`gcp.md`**, **`azure.md`** — serviços de roteamento (Route 53, Cloud LB, Front Door), isolamento (VPC, project, resource group) e mensageria entre células.
- **Não é alternativa a Hexagonal/Clean/Onion** — cell-based opera em outra dimensão. Dentro de cada célula, você ainda escolhe entre essas para organizar o código.
