# GCP — serviços relevantes para aplicação Java/Spring

Foco em serviços usados em produção para sistema transacional. **Não é catálogo completo.**

## Quando escolher GCP

- Workload pesado em **analytics/BigQuery** ou **ML/Vertex AI**.
- Preferência por simplicidade operacional vs AWS.
- Networking global premium (rede do Google é diferencial real).
- Kubernetes — GKE é referência do mercado, criada pelos mesmos engenheiros do Borg.
- Custo mais previsível em algumas categorias (egress dentro do Google Cloud é mais barato; descontos por uso sustentado automáticos).

**Não escolha GCP por reflexo.** Ecossistema menor que AWS, alguns serviços enterprise menos maduros, menor presença de talento no mercado brasileiro.

## Compute

### Cloud Run
Container serverless. Sobe imagem Docker, GCP escala de zero ao infinito. Paga por requisição + tempo de execução.

**Use quando:** serviço HTTP stateless, tráfego variável, quer simplicidade extrema. **Excelente para Spring Boot** — basta empacotar como container.

**Cold start em Java:** existe mas Cloud Run mantém instâncias quentes melhor que Lambda. Combine com:
- **GraalVM Native Image** (Spring Native, Quarkus) — sub-segundo startup.
- **`min-instances`** > 0 para evitar cold start em endpoint crítico.

**Default recomendado** para Spring Boot em GCP quando não há requisito específico de k8s.

### GKE (Google Kubernetes Engine)
Kubernetes gerenciado, referência da indústria.
- **GKE Autopilot:** modo serverless (paga por pod, sem gerenciar nodes). Recomendado para a maioria.
- **GKE Standard:** controle fino de nodes.

**Use quando:** time tem maturidade k8s ou workload complexo justifica.

### Compute Engine (GCE)
VMs. Use quando precisa de controle total, software de terceiro, batch grande. Default: prefira Cloud Run ou GKE.

### Cloud Functions
FaaS event-driven. Concorrente do Lambda, mas Cloud Run cobre os mesmos casos com mais flexibilidade. **Use Cloud Run por padrão**, exceto para função muito pequena disparada por evento GCP nativo.

### App Engine
Histórico. Standard environment ainda usado para Java/Python simples. **Cloud Run substitui na maioria dos casos novos.**

## Mensageria

> **Comparação com mensageria self-managed:** para padrões e trade-offs gerais (Outbox, Saga, idempotência, schema evolution), ver `event-driven.md`. Para Kafka cru, ver `kafka.md`; para RabbitMQ, ver `rabbitmq.md`. Os arquivos abaixo listam os equivalentes gerenciados no GCP.

### Pub/Sub
Mensageria global, multi-region, escala massiva. Modelo pub/sub com **at-least-once** e **subscriptions independentes** por consumer.

**Use quando:** event-driven em GCP, integração entre serviços, fan-out. Equivalente conceitual de SNS+SQS combinados.

```java
// spring-cloud-gcp-pubsub
@Component
class PedidoEventoPublisher {
    private final PubSubTemplate pubSub;
    
    public void publicar(PedidoConfirmadoEvent evento) {
        pubSub.publish("pedidos-confirmados", evento);
    }
}

@Component
class PedidoConfirmadoListener {
    @PubSubListener("pedidos-confirmados-sub")
    public void on(PedidoConfirmadoEvent evento, BasicAcknowledgeablePubsubMessage msg) {
        // processa
        msg.ack();
    }
}
```

**Diferença para Kafka:** Pub/Sub não tem partições (escalabilidade automática), não tem ordering por padrão (precisa habilitar `enable_message_ordering`), retention é configurável (até 7 dias).

### Pub/Sub Lite
Versão zonal mais barata, com partições explícitas (mais parecido com Kafka). Use quando custo é crítico e você aceita zonal.

### Para Kafka em GCP
- **Confluent Cloud no GCP Marketplace** — Kafka gerenciado.
- **GKE + Strimzi** — operar você mesmo no k8s.
- Pub/Sub não substitui Kafka em todos os casos (replay limitado a 7 dias, sem schema registry nativo).

## Persistência

### Cloud SQL
Postgres, MySQL, SQL Server gerenciados. HA via failover, read replicas.
**Default para banco relacional.** Limitações de escala vertical comparado a Aurora — para extremo, considere Cloud Spanner ou AlloyDB.

### AlloyDB for PostgreSQL
Postgres-compatible com performance maior, otimizado para OLTP e HTAP. Concorrente do Aurora.

### Cloud Spanner
Banco relacional **globalmente distribuído** com consistência forte. Custo alto, complexidade alta.
**Use quando:** escala global real, consistência forte multi-region, requisito que outros bancos não atendem. **Não use** para projeto comum — overkill.

### Firestore
NoSQL document, real-time sync. Boa para mobile/web app com UI reativa. Para backend Java tradicional, raramente é a melhor escolha.

### Bigtable
NoSQL wide-column massivamente escalável. Use para time-series, telemetria, IoT, análise. Não é para CRUD.

### Memorystore
Redis ou Memcached gerenciados.

### Cloud Storage
Object storage. Equivalente ao S3. Storage classes (Standard, Nearline, Coldline, Archive) para custo.

## BigQuery — diferencial do GCP

Data warehouse serverless, paga por dado escaneado (ou slot reserved). Queries SQL em petabytes de dado.

**Por que importa em backend transacional:** export de dados operacionais para BigQuery (via Pub/Sub + Dataflow, ou Datastream/CDC) habilita analytics sem impactar OLTP. Padrão comum: app escreve em Cloud SQL, eventos vão para BigQuery, analytics roda lá.

**Não use BigQuery como OLTP.** Latência de query é segundos, não milissegundos.

## Configuração e Secrets

### Secret Manager
Secrets versionados, com IAM por secret. Rotação manual (sem rotação automática nativa como Secrets Manager da AWS — você implementa via Cloud Functions).

```java
@Value("${sm://db-password}")
private String dbPassword;
```

### Runtime Config / variáveis de ambiente
Para config simples, Cloud Run e GKE consomem env vars diretas. Para config estruturada, Secret Manager ou ConfigMap (GKE).

## IAM

- **Service Account** para serviço (Cloud Run, GKE pod via Workload Identity, GCE).
- **Role** específica, prefira **predefined roles** sobre `roles/owner` ou `roles/editor`.
- **Workload Identity** em GKE: pod assume identity sem chave estática.
- **Sem service account key estática** quando possível — use ADC (Application Default Credentials) com Workload Identity ou metadata server.

## Observabilidade

### Cloud Logging
Logs centralizados. Sem custo de ingestion para logs de serviços GCP padrão (até limite generoso); logs custom têm custo.
**Vantagem vs CloudWatch:** ingestion mais barato; integração com BigQuery (exporta log direto via sink).

### Cloud Monitoring
Métricas, alertas, dashboards, SLO nativo.

### Cloud Trace
Distributed tracing nativo. Integra com OpenTelemetry.

### Application Performance Management
Combinação de Logging + Monitoring + Trace + Profiler + Error Reporting. Stack coesa.

**Cloud Profiler:** profiling contínuo em produção com overhead baixo. Diferencial real.

## Networking

- **VPC global** (rede única atravessa regiões — diferencial vs AWS, onde VPC é regional).
- **Cloud Load Balancing** global anycast — single IP para o mundo todo.
- **Cloud NAT** para saída de subnet privada. Mais barato que NAT Gateway AWS.
- **Private Service Connect / Private Google Access** para acessar APIs sem sair para internet.
- **VPC Peering / Network Connectivity Center.**

## Deploy

- **Cloud Build:** CI/CD nativo, integra com GitHub/GitLab/Bitbucket.
- **Cloud Deploy:** orquestração de deploy progressivo entre ambientes.
- **Skaffold:** dev workflow para Kubernetes (rebuild + redeploy automático).
- **Terraform:** suporte nativo via Google provider, bem maduro.
- **Config Connector:** gerencia recursos GCP via k8s CRDs (alternativa ao Terraform).

## Custos — armadilhas e vantagens

**Vantagens:**
- **Sustained use discounts** automáticos (sem reservar).
- **Egress entre serviços do mesmo region/multi-region** geralmente gratuito.
- **Cloud Logging** para serviços padrão tem ingestion grátis até limite alto.

**Armadilhas:**
- **BigQuery query sem `LIMIT`** ou `WHERE` em coluna particionada — escaneia tabela inteira, paga por isso.
- **Cloud SQL sem HA** em produção parece barato até o primeiro outage.
- **Egress para internet** segue caro.
- **Static IP não usado** continua cobrando.
- **Disco SSD** muito maior que necessário.

## Quando NÃO usar GCP

- Ecossistema do cliente já está em AWS ou Azure (custo de migração não compensa).
- Necessidade de serviço específico que GCP não tem ou é menos maduro (ex.: SQS FIFO sem equivalente exato).
- Compliance ou contrato exige outro provedor.
- Time tem proficiência forte em outro provedor.

## Anti-padrões

- Cloud Run com `min-instances=0` em endpoint com SLA de latência apertado.
- Service account key estática em código.
- Spanner para banco que cabia em Cloud SQL.
- Firestore como banco relacional disfarçado.
- BigQuery sem partitioning/clustering em tabela grande — query escaneia tudo.
- Cloud SQL sem HA em produção.
- GKE Standard quando Autopilot resolveria.
- Logs em nível DEBUG em produção sem amostragem (custo).
