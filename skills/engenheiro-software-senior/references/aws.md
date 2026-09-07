# AWS — serviços relevantes para aplicação Java/Spring

Foco em serviços usados em produção para sistema transacional. **Não é catálogo completo.** Para serviço fora desta lista, consulte docs oficiais e declare a incerteza.

## Quando escolher AWS

- Time já tem proficiência ou contratos existentes.
- Ecossistema maduro (mais serviços, mais ferramenta de mercado, mais talento disponível).
- Workload precisa de serviço específico (SageMaker, Redshift, Glue).
- Compliance/região exige presença da AWS.

**Não escolha AWS por reflexo.** GCP e Azure têm vantagens em cenários específicos (ver respectivas referências).

## Compute — onde a app Spring roda

### EKS (Elastic Kubernetes Service)
**Use quando:** time tem maturidade k8s, multi-cloud é objetivo real, workload heterogêneo.
**Custo:** $0.10/hora por cluster + nodes EC2 + control plane.
**Cuidado:** complexidade operacional alta. Sem time SRE dedicado, considere ECS.

### ECS (Elastic Container Service) + Fargate
**Use quando:** quer container sem operar k8s. Fargate elimina gestão de nodes (serverless containers).
**Custo:** Fargate é caro por hora-vCPU/hora-GB comparado a EC2 cru, mas elimina ops.
**Recomendação default** para time pequeno/médio que quer container sem dor.

### App Runner
**Use quando:** serviço HTTP único, deploy direto de repo Git ou imagem, escala automática. Hello world ao mundo de container gerenciado.
**Cuidado:** limitado em customização de rede e integração.

### Lambda
**Use quando:** event-driven (S3, SNS, EventBridge), API com tráfego intermitente, glue code, automação.
**Java em Lambda:** cold start é dor real. Use **SnapStart** (Java 11/17/21) — corta cold start em ~10x. Ou **GraalVM Native Image** com Quarkus/Spring Native.
**Recuse:** serviço com latência crítica e tráfego constante (EC2/ECS é mais barato e previsível).

### EC2
**Use quando:** controle fino, software de terceiro que exige máquina, batch grande, workload customizado.
**Default:** prefira ECS/EKS por cima de EC2 cru.

## Mensageria

## Mensageria

> **Comparação com mensageria self-managed:** para padrões e trade-offs gerais (Outbox, Saga, idempotência, schema evolution), ver `event-driven.md`. Para Kafka cru, ver `kafka.md`; para RabbitMQ, ver `rabbitmq.md`. Os arquivos abaixo listam os equivalentes gerenciados na AWS.

### SQS (Simple Queue Service)
Fila gerenciada. **At-least-once**, sem ordenação (Standard) ou com ordenação por grupo (FIFO).

**Use quando:** fila simples, AWS-first, volume médio. Equivalente do RabbitMQ em casos básicos, sem roteamento complexo.

```yaml
spring:
  cloud:
    aws:
      sqs:
        region: us-east-1
```

```java
@SqsListener("pedidos-confirmados")
public void on(PedidoConfirmadoEvent evento) { ... }
```

**Cuidado:** sem topic routing, sem priority queue. Para fan-out, combine com SNS.

### SNS (Simple Notification Service)
Pub/sub. Tópico SNS → múltiplas subscriptions (SQS, Lambda, HTTP, email).

**Padrão clássico AWS:** **SNS → SQS fanout**. Producer publica no SNS, cada consumer tem sua SQS própria. Equivalente do exchange-fanout do RabbitMQ.

### EventBridge
Event bus com roteamento por regra (pattern matching no payload). Mais flexível que SNS, integra com 100+ serviços AWS e SaaS.

**Use quando:** event-driven com múltiplos produtores e consumidores, roteamento por conteúdo, integração SaaS.

### MSK (Managed Streaming for Kafka)
Kafka gerenciado. Use quando precisa de Kafka real (replay, schema registry, alto throughput) e não quer operar o cluster.
**Alternativa:** **MSK Serverless** para evitar capacity planning. Confluent Cloud também é opção.

### Amazon MQ
RabbitMQ ou ActiveMQ gerenciados. Use para migração de sistema legado que já usa AMQP/JMS.

## Persistência

### RDS
Postgres, MySQL, MariaDB, Oracle, SQL Server gerenciados. Multi-AZ para HA, read replicas para escala de leitura.
**Default para banco relacional.** Use **Aurora** quando precisar de mais throughput/escala (Postgres ou MySQL compatible, com storage decoupling). Aurora Serverless v2 para workload variável.

### DynamoDB
NoSQL key-value/document. Single-digit ms latency, escala massiva.
**Use quando:** padrão de acesso bem definido por chave, escala muito alta, modelagem por access pattern.
**Não use quando:** queries ad-hoc, joins, relatórios. DynamoDB exige modelagem específica — não é "Postgres sem schema".

### ElastiCache
Redis ou Memcached gerenciados. Cluster mode para sharding, replication para HA.

### S3
Object storage. Use para upload de arquivo, backup, log archive, data lake. Storage tiers (Standard, IA, Glacier) para custo.

### OpenSearch
Elasticsearch gerenciado. Use para busca full-text, log analytics. Cuidado com custo de storage e instâncias.

## Configuração e Secrets

### Parameter Store (SSM)
Config externa, hierarquia de paths (`/app/prod/db/url`). Versionamento, tier free generoso.
**Use para:** configuração não-sensível e secrets em volume baixo.

### Secrets Manager
Secrets com **rotação automática** (RDS, Redshift, custom Lambda). Custo por secret/mês + por API call.
**Use para:** credencial de banco, API key, certificado. Rotação automática justifica o custo.

```java
@ConfigurationProperties("app.db")
record DbConfig(String url, String user, String password) {}

// Resolve via spring-cloud-aws-secrets-manager
spring.config.import: aws-secretsmanager:db-credentials/prod
```

## IAM — princípio do menor privilégio

- **IAM Role** para serviço (EC2, ECS task, Lambda, EKS pod via IRSA).
- **Policy específica**, não `*:*`.
- **Sem access key estática** em código ou variável de ambiente — sempre role.
- **Permissions boundary** para limitar escopo máximo de role criada por outro role.
- **Service Control Policy (SCP)** em organization para guardrails globais.

```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::pedidos-uploads/*"
}
```

## Observabilidade

### CloudWatch
Logs, métricas, alarmes, dashboards.
**Cuidado com custo:** ingestion de log a $0.50/GB. Log verboso em produção custa caro. Filtre, agrupe, defina retenção.

### X-Ray
Distributed tracing. Integra com SDK Spring via spring-cloud-aws ou opentelemetry-aws-xray.
**Considere OpenTelemetry + ADOT** (AWS Distro for OpenTelemetry) — vendor-neutral, exporta para X-Ray e outros.

### Application Signals
Camada de SLO/SLI em cima de CloudWatch (lançado 2024). Cubra antes de implementar SRE caseiro.

## Networking essencial

- **VPC** com subnets pública (LB) e privada (app/db). NAT Gateway para saída de subnet privada — **caro por GB processado**.
- **Security Groups** stateful, **NACLs** stateless. SG por papel (`sg-app`, `sg-db`), não por máquina.
- **PrivateLink** para acessar serviço AWS sem sair para internet pública.
- **Transit Gateway** para conectar múltiplas VPCs/contas.

## Deploy

- **CodePipeline + CodeBuild + CodeDeploy:** stack AWS-native. Funciona, mas integração com GitHub Actions ou GitLab CI costuma ser preferida.
- **CDK (Cloud Development Kit):** IaC em código (TypeScript, Java, Python). Boa para time que prefere linguagem geral a HCL.
- **Terraform:** default multi-cloud, comunidade enorme.
- **SAM:** simplifica deploy de Lambda + API Gateway + DynamoDB.

## Custos — armadilhas comuns

- **NAT Gateway:** $0.045/hora + $0.045/GB processado. Tráfego saindo da subnet privada explode aqui.
- **Egress de rede:** sair da AWS (ou entre regiões) é caro. Entre AZs também tem custo.
- **CloudWatch Logs ingestion** + retenção indefinida.
- **EBS snapshots** retidos para sempre.
- **NAT Gateway por AZ** quando 1 já bastaria (HA tem preço).
- **Reserved Instance / Savings Plan** para baseline estável reduz 30-60%.
- **Spot** para batch e CI tolerante a interrupção.

## Quando NÃO usar AWS

- Workload casa muito bem com BigQuery (analytics) ou Vertex AI (ML) → **GCP**.
- Estack Microsoft (AD, .NET, Office) → **Azure**.
- Necessidade de previsibilidade extrema de custo + workload pequeno → considere Hetzner, DigitalOcean, OVH.
- Lock-in inaceitável → use serviço genérico (k8s + Postgres + Redis), evite os proprietários (DynamoDB, EventBridge específico).

## Anti-padrões

- Access key estática em variável de ambiente.
- IAM policy com `Action: "*"` ou `Resource: "*"` sem motivo.
- Lambda Java sem SnapStart, com cold start de 8s em endpoint crítico.
- Multi-AZ desabilitado em RDS de produção "para economizar".
- DynamoDB modelado como Postgres (uma tabela por entidade, queries complexas).
- CloudWatch Logs sem retention configurado (paga ingestion para sempre).
- "Tudo na mesma conta" — separe conta por ambiente via AWS Organizations.
