# Azure — serviços relevantes para aplicação Java/Spring

Foco em serviços usados em produção para sistema transacional. **Não é catálogo completo.**

## Quando escolher Azure

- **Ecossistema Microsoft**: AD/Entra ID, Office 365, Windows Server, .NET, SQL Server — integração nativa.
- **Enterprise B2B** com contrato MS existente (EA Agreement, descontos).
- **Híbrido** real (Azure Arc, Stack HCI) — Azure historicamente forte em on-prem + cloud.
- **Regulação** específica (governo, saúde) com regiões dedicadas.

**Apesar do estereótipo .NET**, Java em Azure tem suporte de primeira linha. Microsoft mantém builds da OpenJDK (Microsoft Build of OpenJDK) e parceria forte com a comunidade Spring.

## Compute

### Azure Container Apps
Container serverless com KEDA-based autoscaling. Equivalente conceitual ao Cloud Run / Fargate. Suporta scale-to-zero, microsserviços com Dapr nativo.

**Use quando:** quer container sem operar Kubernetes, microsserviços, event-driven scaling. **Default recomendado** para Spring Boot em Azure.

### AKS (Azure Kubernetes Service)
Kubernetes gerenciado. Control plane gratuito, paga pelos nodes.
**Use quando:** time tem maturidade k8s, workload complexo, multi-cloud objetivo.

### Azure App Service
PaaS clássico, suporta Java (Tomcat, JBoss EAP, Java SE). Deploy fácil de JAR/WAR.
**Use quando:** time vindo do mundo PaaS tradicional, app web simples, quer evitar container.

### Azure Functions
FaaS, equivalente ao Lambda. Suporta Java (com cold start típico).
**Use quando:** event-driven leve, integração com outros serviços Azure (Event Grid, Service Bus, Cosmos triggers).
**Recuse:** serviço com latência crítica constante.

### Azure Spring Apps
Plataforma gerenciada **específica para Spring Boot/Spring Cloud** (parceria Microsoft + VMware/Broadcom). Tiers: Basic, Standard, Enterprise (com Tanzu).

**Use quando:** stack 100% Spring, quer aproveitar integração com Spring Cloud Config, Service Registry, Gateway gerenciados.
**Cuidado:** mais caro que Container Apps; lock-in maior. Avalie se a abstração compensa.

### Virtual Machines
VMs IaaS. Default: prefira camadas gerenciadas, exceto quando há requisito de controle.

## Mensageria

> **Comparação com mensageria self-managed:** para padrões e trade-offs gerais (Outbox, Saga, idempotência, schema evolution), ver `event-driven.md`. Para Kafka cru, ver `kafka.md`; para RabbitMQ, ver `rabbitmq.md`. Os arquivos abaixo listam os equivalentes gerenciados no Azure.

### Azure Service Bus
Mensageria enterprise (AMQP 1.0). Queues, topics + subscriptions, sessions, scheduled delivery, dead-lettering nativo, transações.

**Use quando:** fluxo de mensagem enterprise, ordenação por sessão, scheduled messages, integração com BizTalk/legado MS. Equivalente do RabbitMQ em casos de uso, com semântica mais rica.

```java
// azure-spring-cloud-starter-servicebus
@ServiceBusListener(destination = "pedidos-confirmados",
                    destinationType = MessageType.QUEUE)
public void on(PedidoConfirmadoEvent evento) { ... }
```

### Azure Event Hubs
Event streaming, equivalente conceitual do Kafka. **Tem endpoint Kafka-compatível** — apps Kafka existentes conectam sem mudar código.

**Use quando:** alto throughput, event streaming, telemetria, integração com Kafka sem operar cluster.

### Azure Event Grid
Event routing por padrão (pattern matching), pub/sub serverless. Equivalente do EventBridge.
**Use quando:** integração event-driven entre serviços Azure, reagir a eventos de recurso (blob criado, recurso provisionado).

**Resumo:**
- **Service Bus** = enterprise messaging (RabbitMQ-like).
- **Event Hubs** = event streaming (Kafka-like).
- **Event Grid** = routing/serverless events (EventBridge-like).

## Persistência

### Azure SQL Database
SQL Server gerenciado. Tiers: General Purpose, Business Critical, Hyperscale.
**Use quando:** stack Microsoft, dependência de SQL Server (T-SQL, features específicas).

### Azure Database for PostgreSQL / MySQL
Postgres e MySQL gerenciados. Flexible Server é a opção atual recomendada.
**Default para banco relacional open-source em Azure.**

### Cosmos DB
NoSQL multi-modelo (document, graph, key-value, column, table) com SLA de latência, multi-region writes, consistência ajustável.
**Use quando:** distribuição global, latência crítica, escala massiva, padrão de acesso bem definido.
**Caro.** Modelar errado custa caro também. Não use como "Postgres sem schema".

### Azure Cache for Redis
Redis gerenciado, com tiers para HA e enterprise (módulos Redis Enterprise).

### Blob Storage
Object storage. Tiers (Hot, Cool, Archive) para custo.

### Azure Data Lake Storage Gen2
Hierarchical storage para data lake. Blob Storage com namespace hierárquico.

## Identidade e Secrets

### Microsoft Entra ID (antes Azure Active Directory)
Identity provider. Standard de OIDC/OAuth2 para Azure e tenants Microsoft. SSO, conditional access, MFA.

**Diferencial:** integração nativa com tenant corporativo Microsoft. Para B2B/SaaS dentro do ecossistema MS, é argumento decisivo.

### Azure Key Vault
Secrets, keys (HSM), certificados. Rotação automática para alguns recursos.

```java
// spring-cloud-azure-starter-keyvault-secrets
@Value("${db-password}")
private String dbPassword;  // resolvido do Key Vault automaticamente
```

### Managed Identity
Identidade gerenciada para recurso Azure (VM, Container App, Function). Sem chave estática — recurso autentica via metadata.

## RBAC

- **Azure RBAC** com role assignment em scope (subscription, resource group, recurso).
- **Built-in roles** primeiro (Reader, Contributor, específicas como "Storage Blob Data Reader").
- **Custom roles** quando necessário.
- **Managed Identity** para acesso de serviço a serviço, sem secret.
- **PIM (Privileged Identity Management)** para acesso elevado just-in-time.

## Observabilidade

### Azure Monitor
Pacote unificado: Logs (Log Analytics), Metrics, Alerts, Dashboards.

### Application Insights
APM para aplicação. SDK Java agent: zero-code instrumentation para Spring Boot.

```bash
java -javaagent:applicationinsights-agent.jar -jar app.jar
```

Traces, dependências, exceções, métricas custom — fora da caixa.

### OpenTelemetry
Application Insights aceita OTel. Recomendado: use OTel para vendor-neutral, exporte para App Insights.

## Networking

- **Virtual Network (VNet)** regional, com subnets.
- **Network Security Groups (NSG)** = security groups com regras.
- **Azure Firewall** para inspeção L7.
- **Private Endpoint** para acessar serviço PaaS sem internet pública.
- **ExpressRoute** para conexão dedicada com on-prem (forte em hybrid).
- **Front Door** + **Application Gateway** + **Load Balancer** — três camadas de LB com escopos diferentes (global L7, regional L7, regional L4).

## Deploy

- **Azure DevOps:** Pipelines, Repos, Boards. Maduro, integração nativa Azure.
- **GitHub Actions:** Microsoft é dona do GitHub; integração com Azure via OIDC é primeira classe.
- **Bicep:** IaC nativo (DSL declarativa). Mais simples que ARM template.
- **Terraform:** suporte completo via azurerm provider.
- **Azure CLI / PowerShell** para scripting.

## Custos — armadilhas

- **App Service Plan Premium** quando Standard ou Container Apps resolviam.
- **Azure Spring Apps Enterprise** sem usar features Tanzu — pagando por valor não consumido.
- **Cosmos DB com RU mal dimensionado** — autoscale pode explodir custo.
- **Log Analytics workspace sem retention configurada.**
- **VM ligada com IP público dedicado** quando não precisava.
- **Reserved Instances** podem reduzir 40-70% em workload estável.
- **Azure Hybrid Benefit** (descontos com licença Windows/SQL Server existente) — específico, mas relevante para migração de on-prem.

## Quando NÃO usar Azure

- Stack sem nenhuma afinidade Microsoft, time prefere AWS/GCP.
- Workload muito específico que Azure não atende bem (alguns ML/data services AWS/GCP têm vantagem).
- Custo operacional Azure não compensa para projeto pequeno (Hetzner/DigitalOcean são opções).

## Anti-padrões

- Login com user/password em código (use Managed Identity).
- Connection string com secret em `application.yml` (use Key Vault).
- App Service sempre em Standard "por segurança" sem necessidade real (Container Apps geralmente mais barato).
- Cosmos DB para CRUD simples (caro, mal modelado).
- Azure Functions Java com cold start de 10s em endpoint crítico.
- NSG com `0.0.0.0/0` em porta de banco.
- Tudo em uma única subscription/resource group — separe por ambiente, blast radius.
- Sem tagging — sem rastreabilidade de custo.
