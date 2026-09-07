# Referência: Cloud Native, Containers e Orquestração

Consulte quando o pedido envolver cloud (AWS, Azure, GCP), containers (Docker), Kubernetes, ou decisões de infraestrutura e arquitetura cloud native. Profundidade de sênior esperada.

## Índice
- AWS Well-Architected Framework (e equivalentes)
- Cloud native: os três provedores
- Docker / containers
- Kubernetes
- Serverless e managed services
- Trade-off de portabilidade vs nativo

## AWS Well-Architected Framework (e equivalentes)

Lente para avaliar arquiteturas. Seis pilares:

1. **Excelência Operacional** — automação, IaC, observabilidade, runbooks, melhoria contínua.
2. **Segurança** — menor privilégio (IAM), defesa em profundidade, criptografia em trânsito e repouso, rastreabilidade, gestão de segredos.
3. **Confiabilidade** — recuperação de falha automática, testar recuperação, escalar horizontalmente, parar de adivinhar capacidade (autoscaling), multi-AZ.
4. **Eficiência de Performance** — escolher o recurso certo, serverless onde couber, experimentar, mensurar.
5. **Otimização de Custos** — pagar pelo que usa, dimensionar pelo uso real, gastar em diferenciação, não em infra commodity.
6. **Sustentabilidade** — minimizar recursos e energia por unidade de trabalho.

Azure tem o **Well-Architected Framework** (pilares quase idênticos: Reliability, Security, Cost Optimization, Operational Excellence, Performance Efficiency) e o GCP tem o **Architecture Framework** com os mesmos eixos. Os princípios transcendem o provedor — use-os como checklist de revisão de qualquer arquitetura cloud.

## Cloud native: os três provedores

Mapa mental dos serviços equivalentes (útil para raciocinar agnóstico de provedor):

| Categoria | AWS | Azure | GCP |
|---|---|---|---|
| Compute (VM) | EC2 | Virtual Machines | Compute Engine |
| Serverless (FaaS) | Lambda | Functions | Cloud Functions |
| Containers gerenciados | ECS / Fargate | Container Apps / ACI | Cloud Run |
| Kubernetes gerenciado | EKS | AKS | GKE |
| Objeto (storage) | S3 | Blob Storage | Cloud Storage |
| Relacional gerenciado | RDS / Aurora | Azure SQL / DB for PostgreSQL | Cloud SQL / AlloyDB |
| NoSQL | DynamoDB | Cosmos DB | Firestore / Bigtable |
| Fila | SQS | Queue Storage / Service Bus | Pub/Sub |
| Streaming | Kinesis / MSK | Event Hubs | Pub/Sub / Dataflow |
| Pub/Sub eventos | SNS / EventBridge | Event Grid | Pub/Sub |
| Secrets | Secrets Manager | Key Vault | Secret Manager |
| IAM | IAM | Entra ID / RBAC | Cloud IAM |

Princípios cloud native (independente do provedor): apps stateless e horizontalmente escaláveis, estado em serviços gerenciados, infraestrutura como código (Terraform/CloudFormation/Bicep), imutabilidade, automação de deploy, observabilidade de primeira classe, design para falha.

## Docker / containers

- **Imagem**: receita imutável; container é a instância em execução.
- **Boas práticas**: multi-stage build (separar build de runtime — imagem final enxuta), imagem base mínima (distroless/alpine com cautela), rodar como usuário não-root, um processo por container, `.dockerignore`, fixar versões (não `latest` em produção), camadas ordenadas para aproveitar cache (dependências antes do código).
- **Segurança**: escanear imagens (Trivy/Snyk), não embutir segredos na imagem, superfície mínima.
- Para Java: cuidado com flags de memória — JVM moderna respeita limites do container (`-XX:+UseContainerSupport` é default em versões recentes), mas valide heap vs limite do pod.

## Kubernetes

Orquestrador de containers. Conceitos que o sênior precisa dominar:

- **Pod** (menor unidade, 1+ containers), **Deployment** (gerencia réplicas e rollout), **Service** (rede estável/load balancing interno), **Ingress** (entrada HTTP externa), **ConfigMap/Secret** (configuração), **Namespace** (isolamento lógico).
- **StatefulSet** para cargas com estado/identidade estável; **DaemonSet** para um pod por nó; **Job/CronJob** para tarefas.
- **Resource requests/limits** — defina ambos; sem requests o scheduler erra o bin-packing, sem limits um pod pode estourar o nó. Entenda CPU throttling e OOMKill.
- **Probes**: liveness (reinicia se travado), readiness (tira do load balancer se não está pronto), startup (apps lentos para subir — relevante para JVM).
- **Autoscaling**: HPA (horizontal por métrica), VPA, Cluster Autoscaler.
- **Rollout**: rolling update default; considere blue/green ou canary (Argo Rollouts) para mudanças arriscadas.
- Quando **não** usar Kubernetes: time pequeno, poucos serviços, baixa escala — a complexidade operacional não se paga. Cloud Run/Fargate/Container Apps resolvem com muito menos overhead. K8s vale com muitos serviços, necessidade de portabilidade e time com maturidade de plataforma.

## Serverless e managed services

Regra do sênior cloud native: **prefira serviço gerenciado a operar você mesmo**, salvo motivo forte (custo em escala, requisito específico, lock-in inaceitável). O diferencial competitivo raramente está em operar um broker ou banco — está no domínio. Veja serverless também em `arquitetura.md`.

## Trade-off de portabilidade vs nativo

Serviços nativos do provedor (DynamoDB, Cosmos DB, EventBridge) maximizam produtividade e integração, ao custo de lock-in. Abstrações portáveis (Kubernetes, Postgres gerenciado, Kafka) reduzem lock-in ao custo de mais operação e menos integração. Não há resposta única: decida pelo horizonte do projeto e pela probabilidade real de troca de provedor — multi-cloud "por precaução" costuma custar caro sem retorno.