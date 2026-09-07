# Referência: Backend e Cloud

Consulte este arquivo quando o pedido envolver design de backend, sistemas distribuídos, dados, infraestrutura ou operação em cloud.

## Índice
- Java e Spring (stack principal)
- Checklist de design de API
- Escolha de armazenamento de dados
- Comunicação síncrona vs assíncrona
- Resiliência e produção
- Observabilidade
- Segurança backend
- Custo em cloud

## Java e Spring (stack principal)

Profundidade de sênior esperada aqui. Pontos de julgamento e armadilhas comuns:

- **Camadas claras**: Controller (borda HTTP, validação, sem regra de negócio) → Service (regra de negócio, transações) → Repository (acesso a dados). Não vaze `Entity` JPA na API; use DTOs.
- **Transações**: `@Transactional` no Service, não no Controller. Cuidado com self-invocation (chamada de método interno não passa pelo proxy e ignora a anotação) e com o `readOnly = true` para leituras.
- **JPA/Hibernate — o clássico N+1**: relacionamentos `LAZY` acessados em loop disparam uma query por item. Use `JOIN FETCH`, `@EntityGraph` ou projeções. Saiba quando *não* usar JPA (relatórios pesados pedem query nativa ou JdbcTemplate).
- **Injeção de dependência por construtor** (não `@Autowired` em campo) — facilita teste e deixa dependências explícitas e imutáveis.
- **Validação**: Bean Validation (`@Valid`, `@NotNull`, etc.) na borda; tratamento centralizado de erros com `@RestControllerAdvice` / `@ExceptionHandler` para resposta de erro consistente.
- **Configuração**: `application.yml` por profile, segredos via variáveis de ambiente / Spring Cloud Config / secret manager — nunca commitados.
- **Concorrência e bloqueio**: para o caso de débito/saldo, lock otimista com `@Version` ou update atômico condicional; pessimista (`PESSIMISTIC_WRITE`) só quando justificado.
- **Resiliência**: Resilience4j para circuit breaker, retry e rate limiter. Configure timeouts no `RestClient`/`WebClient`/`RestTemplate` — o default costuma ser sem timeout.
- **Observabilidade**: Spring Boot Actuator + Micrometer para métricas; logs estruturados (Logback) com trace id (Micrometer Tracing), OpenTelemetry.
- **Testes**: JUnit 5 + Mockito para unidade; `@SpringBootTest`/`@WebMvcTest`/`@DataJpaTest` por fatia; Testcontainers para integração real com banco em vez de H2.

### Convenções não-negociáveis

- **Java 17+**. Use `record` para DTO/command/query/event imutável. `sealed interface` para estados e `Result` types. Pattern matching em `switch` quando ajudar.
- **Pacotes por feature/contexto**, nunca por camada técnica. `com.empresa.pedidos.{domain,application,infra,api}` é OK; `com.empresa.{controllers,services,repositories}` não.
- **Construtor injection com `final`.** Nunca `@Autowired` em field. Nunca setter injection.
- **`@Transactional` no application service.** Nunca em controller, nunca em repository. Nunca envolvendo chamada HTTP externa.
- **DTO/Record na borda.** Entidade JPA não sai de service — vira `record` antes de chegar no controller.
- **Exceção de domínio específica** (`PedidoNaoEncontradoException`, não `RuntimeException`). Tradução central em `@ControllerAdvice` para RFC 7807 (`application/problem+json`).
- **Validation na entrada**: Bean Validation (`jakarta.validation`) em DTO; regras de negócio dentro do aggregate.

### Padrões aplicados na prática

| Padrão | Quando aplicar (Spring) |
|---|---|
| **Repository** | Acesso a aggregate. `interface PedidoRepository` no domínio, `JpaPedidoRepository implements PedidoRepository` na infra. Domínio não conhece JPA. |
| **Specification** | Regras de negócio compostas (`pedido.elegivelParaDesconto()`). Permite testar e combinar com `and`/`or`. |
| **Strategy** | Variação de regra (cálculo de frete, política de desconto). Injete via `Map<String, FreteStrategy>` que Spring monta com `@Component` + qualifier. |
| **Factory** | Construção de aggregate com invariante complexa. Construtor privado + factory method estático nomeado (`Pedido.novo(...)`, `Pedido.reconstituir(...)`). |
| **Builder** | Use `record` com construtor canônico antes de pensar em Builder. Builder só quando há muitos campos opcionais legítimos. |
| **Decorator** | Cross-cutting (cache, log, retry). Prefira `@Cacheable`, `@Retryable`, AOP do Spring antes de escrever Decorator manual. |
| **Saga** | Transação distribuída. Orquestrada (state machine explícita) para fluxo crítico/auditável; coreografada (eventos) para acoplamento mínimo. |
| **Outbox** | Persistir + publicar evento atomicamente. Tabela `outbox` na mesma transação, publisher separado lê e publica. |
| **Idempotency** | Mutação HTTP recebe header `Idempotency-Key`, consumer de evento deduplica por `eventId` + tabela de processados. |
| **Circuit Breaker** | Integração externa instável. Resilience4j com threshold + janela. Combine com timeout e retry com jitter. |

### Hexagonal aplicada

- **Domínio** (centro): aggregate, value object, domain event, specification, port. Zero dependência de Spring, JPA, HTTP. Testável com JUnit puro.
- **Aplicação**: use case / application service. Orquestra domínio, abre transação, publica evento. Depende de portas, não de implementações.
- **Infraestrutura** (adapters): JPA repository, Kafka producer/consumer, HTTP client, REST controller. Implementa portas. Traduz exceção técnica em exceção de domínio.

Recuse hexagonal "decorativa": domínio anêmico (só getter/setter) com regra toda no service é hexagonal só na pasta.

### Testes

- **Domínio**: JUnit 5 puro, sem Spring context. Rápido, determinístico.
- **`@DataJpaTest`** para repository (com Testcontainers PostgreSQL, não H2 — H2 mente sobre comportamento).
- **`@WebMvcTest`** para controller, com `MockMvc` + mock dos use cases.
- **`@SpringBootTest`** + Testcontainers para integração end-to-end. Use com parcimônia (lento).
- **Contract test** (Pact ou Spring Cloud Contract) quando há acoplamento de API entre serviços.
- Teste descreve **comportamento**, não implementação. Nome no formato `deve_<comportamento>_quando_<condicao>`.

### Anti-padrões a recusar imediatamente

- N+1 query escondida em `@OneToMany` lazy sem `JOIN FETCH` / `@EntityGraph`.
- `Optional` como parâmetro de método.
- `Optional.get()` sem `isPresent()` ou `orElseThrow`.
- `catch (Exception e)` engolindo sem log nem rethrow.
- `@Autowired` em field, especialmente em teste.
- `synchronized` em controller (pinning de virtual thread).
- WebFlux + JDBC bloqueante no mesmo fluxo.
- `String` concatenando SQL (use prepared statement / JPQL).
- Lógica de negócio em controller ou em repository.
- Service estático "Utils" com 30 métodos sem coesão.

## Python (stack secundária)

Use quando o problema casar: scripts, automação, glue code, data processing, ML serving, prototipação rápida. **Não proponha Python como stack principal** para sistema transacional sem motivo forte (time já domina, ecossistema específico).

### Convenções

- **Python 3.11+**. Type hints obrigatórios em código de produção (`def processar(pedido: Pedido) -> Resultado:`).
- **Formatter**: Black ou Ruff. **Linter**: Ruff (rápido, cobre flake8 + isort + mais). **Type checker**: mypy ou pyright em modo estrito.
- **Gerenciador de dependência**: Poetry ou uv. `requirements.txt` pinado com hash quando for distribuir.
- **Virtual env sempre**. Nunca `pip install` no Python do sistema.
- **`pydantic` v2** para modelo de dados com validação. `dataclass` para estrutura simples sem validação.
- **FastAPI** como default para HTTP (async-first, validation por pydantic, OpenAPI automático). Flask só em código legado.
- **`async`/`await`** quando há I/O concorrente real. Não use async "por estar na moda" em código CPU-bound ou sequencial.
- **Estrutura de projeto**: `src/` layout, não pacote no root. `tests/` separado.

### Padrões

- **Pytest** como framework de teste. Fixtures > setUp/tearDown. Parametrize para casos múltiplos.
- **Dependency injection** via parâmetro de função ou via `Depends` do FastAPI. Evite singleton global.
- **Erro de domínio** como exceção específica. Não use `assert` para validação em produção (é removido com `-O`).
- **Log estruturado** com `structlog` ou `logging` configurado para JSON. Nunca `print` em produção.

### Anti-padrões

- Mutar default argument (`def f(x=[])`).
- `except:` sem tipo (captura `KeyboardInterrupt`).
- Import circular resolvido com import dentro de função (sintoma de design ruim).
- Dependência sem versão pinada em produção.
- Lógica em `__init__.py`.

## Go (stack secundária)

Use para CLI, sidecar, serviço de alta concorrência/baixa latência, ferramenta de infra. Footprint pequeno, cold start rápido, deploy simples.

### Convenções

- **Go 1.22+**. Siga `gofmt`/`goimports` sem discussão. Lint com `golangci-lint`.
- **Erro como valor**. Sempre `if err != nil`. Embrulhe com `fmt.Errorf("contexto: %w", err)` para preservar a cadeia. Nunca ignore erro com `_` em produção.
- **Não use exceção/panic para controle de fluxo.** `panic` é para bug irrecuperável.
- **Context** (`context.Context`) como primeiro parâmetro em função que faz I/O, RPC ou pode cancelar. Propague sempre.
- **Interface pequena, definida no consumidor.** "Accept interfaces, return structs."
- **Goroutine com dono claro.** Quem cria sabe quando termina. Use `errgroup`, `context` para cancelar. Goroutine vazada é bug.
- **Channel para comunicação, mutex para estado.** Não force channel onde mutex resolve.
- **Dependência via `go.mod`** com versão semântica. `go mod tidy` no CI.

### Padrões

- **Estrutura**: `cmd/<binario>/main.go` + pacotes internos em `internal/`. Não exporte o que não precisa ser usado fora.
- **Teste com `testing` padrão**. Table-driven test é o idioma. `testify` opcional para assertion mais legível.
- **HTTP**: `net/http` padrão resolve quase tudo. Frameworks (Gin, Echo, Chi) quando justificar.
- **Log estruturado**: `slog` (stdlib desde 1.21). Nunca `fmt.Println` em serviço.

### Anti-padrões

- Ignorar erro com `_`.
- Goroutine sem mecanismo de parada.
- `interface{}` / `any` sem necessidade real.
- Pacote `util` ou `common` gigante.
- Init function fazendo I/O ou tendo efeito colateral.

## Checklist de design de API

- **Contrato claro**: versionamento, formato de erro consistente, paginação para listas.
- **Idempotência** em operações de escrita sensíveis (especialmente com retries) — use chaves de idempotência.
- **Validação** de entrada na borda; nunca confie no cliente.
- **Status codes** corretos; erros que dizem *o que* fazer, não vazam stack trace.
- **Paginação** baseada em cursor para grandes coleções (offset degrada em escala).
- **Rate limiting** e backpressure desde o começo se houver consumidores externos.

## Escolha de armazenamento de dados

Não há padrão universal. Decida pelo padrão de acesso:

- **Relacional (Postgres, MySQL)** — default sólido. Transações ACID, joins, integridade. Comece aqui salvo motivo forte.
- **Documento (MongoDB, DynamoDB)** — esquema flexível, acesso por chave, escala horizontal simples; péssimo para queries relacionais complexas.
- **Chave-valor / cache (Redis)** — leitura ultrarrápida, sessões, filas leves, rate limiting.
- **Busca (Elasticsearch/OpenSearch/Solr)** — busca textual e agregações; não é fonte da verdade.
- **Colunar / OLAP (ClickHouse, BigQuery, Redshift)** — analytics sobre grandes volumes; não para transacional.

Trade-off recorrente: **consistência forte vs disponibilidade/latência**. Defina por caso de uso, não para o sistema inteiro.

## Comunicação síncrona vs assíncrona

- **Síncrono (REST/gRPC)** — quando o chamador precisa da resposta agora e o acoplamento é aceitável.
- **Assíncrono (filas, eventos: SQS, Kafka, RabbitMQ)** — desacopla, absorve picos, permite retry e processamento posterior. Custa complexidade: ordenação, entrega ao-menos-uma-vez, idempotência no consumidor, dead-letter queue.

Regra prática: se a operação pode ser feita depois e não bloqueia o usuário, considere assíncrono.

## Resiliência e produção

O que separa "funciona" de "funciona em produção":

- **Timeouts** em toda chamada de rede. Sem timeout = falha em cascata.
- **Retries com backoff exponencial + jitter**, e apenas em erros idempotentes/transitórios.
- **Circuit breaker** para dependências instáveis.
- **Graceful degradation** — o que servir quando uma dependência cai.
- **Idempotência** para sobreviver a retries e entregas duplicadas.
- **Limites de concorrência / bulkheads** para isolar falhas.
- **Migrations** com compatibilidade para frente (deploy sem downtime).

## Observabilidade

Três pilares — sem eles, você opera no escuro:

- **Logs** estruturados (JSON), com correlação por request/trace id, sem dados sensíveis.
- **Métricas** — latência (use percentis p50/p95/p99, não média), throughput, taxa de erro, saturação de recursos.
- **Tracing** distribuído para enxergar a requisição cruzando serviços.

Defina **SLIs/SLOs** e alerte sobre sintomas que o usuário sente, não sobre cada flutuação de CPU.

## Segurança backend

- Segredos fora do código (secret manager, variáveis de ambiente), nunca commitados.
- Princípio do menor privilégio em IAM e acesso a banco.
- Autenticação e **autorização** (são coisas diferentes — verifique permissão por recurso).
- Proteção contra injeção: queries parametrizadas, sempre.
- Criptografia em trânsito (TLS) e em repouso para dados sensíveis.
- Validação e sanitização de toda entrada externa.

## Custo em cloud

Decisões de arquitetura são decisões de custo:

- Egress de dados e cross-AZ costumam ser custos silenciosos.
- Serverless x instância dedicada: serverless ganha em carga intermitente, perde em carga alta e constante.
- Storage por tier (quente/frio/arquivo) conforme padrão de acesso.
- Dimensione pelo uso real (métricas), não pelo medo. Autoscaling antes de superprovisionar.