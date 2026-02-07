# Enterprise DevOps Platform - 5 Production-Ready Projects

A complete **enterprise DevOps platform** built around a containerized 2048 game, demonstrating five foundational projects that cover the entire software delivery lifecycle: CI/CD, Infrastructure as Code, Kubernetes orchestration, serverless APIs, and centralized logging.

```
                    +-----------------------------------------+
                    |        Enterprise DevOps Platform        |
                    +-----------------------------------------+
                                      |
         +------------+----------+----+-----+-----------+
         |            |          |          |           |
    +---------+ +---------+ +--------+ +--------+ +--------+
    |  CI/CD  | |Terraform| |  K8s & | |Server- | |  EFK   |
    |Pipeline | |  IaC    | |Monitor | | less   | |Logging |
    +---------+ +---------+ +--------+ +--------+ +--------+
    |Blue/Grn | |VPC, ECS | |Prometh.| |Lambda  | |Elastic |
    |Security | |ALB, IAM | |Grafana | |DynamoDB| |Fluentd |
    |SonarQube| |Auto-scl | |Alerts  | |SNS/API | |Kibana  |
    +---------+ +---------+ +--------+ +--------+ +--------+
```

---

## Table of Contents

- [Overview](#overview)
- [Project 1: CI/CD Pipeline with Blue/Green Deployment](#project-1-cicd-pipeline-with-bluegreen-deployment)
- [Project 2: Infrastructure as Code with Terraform](#project-2-infrastructure-as-code-with-terraform)
- [Project 3: Kubernetes Cluster & Monitoring](#project-3-kubernetes-cluster--monitoring)
- [Project 4: Serverless Application & API Gateway](#project-4-serverless-application--api-gateway)
- [Project 5: Centralized Logging Stack (EFK)](#project-5-centralized-logging-stack-efk)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Technology Stack](#technology-stack)
- [Best Practices Applied](#best-practices-applied)
- [Cost Analysis](#cost-analysis)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Each project solves real-world production problems and can be deployed independently or as a cohesive platform. The application (a 2048 game) is intentionally simple to keep the focus on the infrastructure and automation patterns.

| Project | Focus Area | Key Technologies |
|---------|-----------|-----------------|
| **1. CI/CD Pipeline** | Automated delivery with zero-downtime deploys | GitHub Actions, Docker, SonarQube |
| **2. Terraform IaC** | Reproducible AWS infrastructure | Terraform, VPC, ECS Fargate, ALB |
| **3. K8s & Monitoring** | Container orchestration + observability | Kubernetes, Prometheus, Grafana |
| **4. Serverless API** | Event-driven backend with API management | AWS SAM, Lambda, DynamoDB, SNS |
| **5. EFK Logging** | Centralized log aggregation and search | Elasticsearch, Fluentd, Kibana |

---

## Project 1: CI/CD Pipeline with Blue/Green Deployment

### What It Does

Automates the entire path from pull request to production with a blue/green deployment strategy that enables instant rollback and zero-downtime releases.

### Architecture

```
  Developer Push
       |
       v
  +------------------+     +-------------------+     +------------------+
  | ci.yaml          |     | deploy.yaml       |     | Production       |
  | (PR Gate)        |     | (Main Branch)     |     |                  |
  |                  |     |                   |     |  BLUE (active)   |
  | Lint + Validate  |     | Build + Push ECR  |---->|  GREEN (standby) |
  | Security Scan    |     | Deploy to Standby |     |                  |
  | SonarQube        |     | Switch ALB        |     |  ALB routes      |
  | Container Tests  |     | Verify + Rollback |     |  traffic to one  |
  +------------------+     +-------------------+     +------------------+
```

### Key Features

- **Two-pipeline design**: `ci.yaml` gates PRs, `deploy.yaml` handles production releases
- **Blue/green deployment**: Traffic switches instantly between two identical environments
- **Automatic rollback**: Failed deployments revert within seconds by switching the ALB listener
- **Security scanning**: Trivy vulnerability scans, SonarQube static analysis, NGINX config validation
- **9-point smoke tests**: HTTP status, health endpoint, 7 security headers, response time, content validation

### Files

```
.github/workflows/ci.yaml          # PR quality gate (lint, scan, test)
.github/workflows/deploy.yaml      # Blue/green production deployment
2048/Dockerfile                     # Security-hardened NGINX container
scripts/deploy.sh                   # Deployment orchestration
scripts/rollback.sh                 # Instant ALB-based rollback
scripts/health-check.sh             # ECS task + HTTP health checks
scripts/smoke-test.sh               # Post-deployment validation
sonar-project.properties            # SonarQube configuration
```

### Build Guide

See [docs/project1-cicd-pipeline/BUILD-GUIDE.md](docs/project1-cicd-pipeline/BUILD-GUIDE.md) for step-by-step setup instructions.

---

## Project 2: Infrastructure as Code with Terraform

### What It Does

Provisions the complete AWS infrastructure for the blue/green ECS Fargate deployment using Terraform. Every resource is version-controlled, parameterized, and reproducible across environments.

### Architecture

```
  terraform apply
       |
       v
  +------------------------------------------------------------------+
  |                          AWS Account                              |
  |                                                                    |
  |  +------------------+    +-------------------------------------+  |
  |  |  VPC 10.0.0.0/16 |    |  IAM                                |  |
  |  |                  |    |  - ECS Execution Role               |  |
  |  |  Public Subnets  |    |  - ECS Task Role                   |  |
  |  |  - ALB           |    |  - GitHub OIDC Provider + Role     |  |
  |  |  Private Subnets |    +-------------------------------------+  |
  |  |  - ECS Tasks     |                                             |
  |  |  - NAT Gateway   |    +-------------------------------------+  |
  |  +------------------+    |  ECS Fargate                        |  |
  |                          |  - Blue Service (2 tasks)           |  |
  |  +------------------+    |  - Green Service (2 tasks)          |  |
  |  |  ALB             |    |  - Auto-scaling (2-10)              |  |
  |  |  - Blue TG       |--->|  - CPU + Memory policies            |  |
  |  |  - Green TG      |    +-------------------------------------+  |
  |  +------------------+                                             |
  |                          +-------------------------------------+  |
  |  +------------------+    |  CloudWatch                         |  |
  |  |  ECR             |    |  - 6 Alarms (CPU, Mem, 5xx, P95)   |  |
  |  |  - Scan on push  |    |  - Dashboard                       |  |
  |  |  - 20 img policy |    |  - SNS Notifications               |  |
  |  +------------------+    +-------------------------------------+  |
  +------------------------------------------------------------------+
```

### Key Features

- **11 Terraform files** covering VPC, subnets, ALB, ECS, ECR, IAM, CloudWatch
- **Blue/green ready**: Two ECS services and two ALB target groups with `lifecycle { ignore_changes }` to prevent Terraform from conflicting with CI/CD traffic switching
- **GitHub OIDC authentication**: No static AWS credentials stored anywhere
- **Auto-scaling**: Target tracking on CPU (70%) and memory (80%), scales 2-10 tasks
- **VPC endpoints**: ECR, S3, CloudWatch, and Secrets Manager accessed privately
- **6 CloudWatch alarms**: CPU, memory, 5xx errors, P95 latency, task count, healthy hosts

### Files

```
infra/
├── main.tf                # Provider config, backend, data sources, locals
├── variables.tf           # 25+ parameterized inputs with validation
├── terraform.tfvars       # Production defaults
├── vpc.tf                 # VPC, 2 public + 2 private subnets, NAT, 4 endpoints
├── security-groups.tf     # ALB, ECS, VPC endpoint security groups
├── ecr.tf                 # ECR repo, scan-on-push, lifecycle policy
├── iam.tf                 # Execution role, task role, GitHub OIDC
├── alb.tf                 # ALB, blue/green target groups, listener rules
├── ecs.tf                 # Cluster, task def, blue/green services, auto-scaling
├── cloudwatch.tf          # Log groups, 6 alarms, SNS topic, dashboard
└── outputs.tf             # 15+ outputs including github_secrets_summary
```

### Build Guide

See [docs/project2-terraform-iac/BUILD-GUIDE.md](docs/project2-terraform-iac/BUILD-GUIDE.md) for the full 10-step deployment process.

---

## Project 3: Kubernetes Cluster & Monitoring

### What It Does

Deploys the 2048 game on Kubernetes with production-grade monitoring using Prometheus, Grafana, and Alertmanager. Includes HPA auto-scaling, pod disruption budgets, and a 7-panel Grafana dashboard.

### Architecture

```
  +-------------------------------------------------------------------+
  |                     Kubernetes Cluster                              |
  |                                                                     |
  |  Namespace: game-2048          Namespace: monitoring                |
  |  +---------------------+      +------------------------------+     |
  |  |  Deployment (3 rep) |      |  Prometheus                  |     |
  |  |  - liveness probe   |<-----|  - 8 alert rules             |     |
  |  |  - readiness probe  |      |  - 15d retention             |     |
  |  |  - startup probe    |      |  - 2Gi storage               |     |
  |  +---------------------+      +------------------------------+     |
  |  |  Service (ClusterIP)|      |  Grafana                     |     |
  |  +---------------------+      |  - 7-panel dashboard         |     |
  |  |  HPA (2-10 pods)    |      |  - Prometheus datasource     |     |
  |  |  PodDisruptionBudget|      +------------------------------+     |
  |  +---------------------+      |  Alertmanager                |     |
  |  |  Ingress (NGINX)    |      |  - Slack/email routing       |     |
  |  |  - Rate limiting    |      |  - Inhibit rules             |     |
  |  +---------------------+      +------------------------------+     |
  |                               |  Node Exporter (DaemonSet)   |     |
  |                               +------------------------------+     |
  +-------------------------------------------------------------------+
```

### Key Features

- **Production deployment**: 3 replicas with liveness, readiness, and startup probes
- **Auto-scaling**: HPA scales 2-10 pods based on CPU (70%) and memory (80%)
- **Prometheus monitoring**: Scrapes Kubernetes pods, nodes, and cAdvisor with 8 alert rules
- **Grafana dashboard**: Request rate, error rate, P95 latency, active pods, CPU/memory gauges, pod restarts
- **Alertmanager**: Routes critical alerts to PagerDuty, warnings to Slack, with inhibit rules
- **Node Exporter**: DaemonSet collecting hardware and OS metrics from every node

### Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighErrorRate | Error rate > 5% for 5m | critical |
| HighLatency | P95 > 2s for 5m | critical |
| PodCrashLooping | Restarts > 5 in 15m | critical |
| PodNotReady | Pod not ready for 5m | warning |
| HighCPUUsage | CPU > 80% for 10m | warning |
| HighMemoryUsage | Memory > 85% for 10m | warning |
| DiskSpaceRunningLow | Disk > 80% for 5m | warning |
| HPAMaxedOut | At max replicas for 15m | warning |

### Files

```
k8s/
├── base/
│   ├── namespace.yaml         # game-2048 and monitoring namespaces
│   ├── deployment.yaml        # 3-replica deployment with probes
│   ├── service.yaml           # ClusterIP service
│   ├── hpa.yaml               # HPA + PodDisruptionBudget
│   └── ingress.yaml           # NGINX ingress with rate limiting
└── monitoring/
    ├── prometheus/
    │   ├── config.yaml        # Scrape configs + 8 alert rules
    │   ├── deployment.yaml    # Prometheus + RBAC + 2Gi storage
    │   └── node-exporter.yaml # DaemonSet for node metrics
    ├── grafana/
    │   ├── deployment.yaml    # Grafana with persistent storage
    │   └── config.yaml        # Datasource + 7-panel dashboard JSON
    └── alertmanager/
        └── deployment.yaml    # Alertmanager with routing config
```

### Build Guide

See [docs/project3-k8s-monitoring/BUILD-GUIDE.md](docs/project3-k8s-monitoring/BUILD-GUIDE.md) for deployment order and verification steps.

---

## Project 4: Serverless Application & API Gateway

### What It Does

A serverless leaderboard API for the 2048 game using AWS SAM, Lambda, DynamoDB, and SNS. Features event-driven processing where DynamoDB Streams trigger score aggregation and high-score notifications.

### Architecture

```
  Client Request
       |
       v
  +------------------+
  | API Gateway      |     Lambda Functions:
  | - API Key auth   |     +--------------------+
  | - Throttling     |---->| GET  /health       |  (no auth)
  |   100/s burst    |     | GET  /scores       |  (query by player)
  |   50/s steady    |     | POST /scores       |  (submit score)
  | - CORS           |     | GET  /scores/top   |  (leaderboard)
  | - Request valid. |     +--------+-----------+
  +------------------+              |
                                    v
                           +------------------+     DynamoDB Stream
                           | DynamoDB         |----------+
                           | PK: playerId     |          |
                           | SK: timestamp    |          v
                           | GSI: score-index |   +--------------+
                           +------------------+   | Processor    |
                                                  | Lambda       |
                                                  | - Writes     |
                                                  |   GLOBAL     |
                                                  |   leaderboard|
                                                  | - Publishes  |
                                                  |   SNS if     |
                                                  |   score>=2048|
                                                  +------+-------+
                                                         |
                                                         v
                                                  +--------------+
                                                  | SNS Topic    |
                                                  +------+-------+
                                                         |
                                                         v
                                                  +--------------+
                                                  | Notifier     |
                                                  | Lambda       |
                                                  | - Webhook    |
                                                  | - Email      |
                                                  +--------------+
```

### Key Features

- **AWS SAM template**: Single-file infrastructure definition for all resources
- **API Gateway**: API key authentication, 100/50 req/s throttling, 10,000 req/day quota, request validation
- **Event-driven processing**: DynamoDB Streams trigger a processor Lambda that updates the global leaderboard
- **High-score notifications**: Scores >= 2048 trigger SNS notifications to a notifier Lambda
- **X-Ray tracing**: Active tracing enabled on all Lambda functions
- **Point-in-time recovery**: Enabled on the DynamoDB table

### API Endpoints

| Method | Path | Description | Auth |
|--------|------|-------------|------|
| GET | `/health` | Service health check | None |
| GET | `/scores?playerId=abc` | Get player scores | API Key |
| POST | `/scores` | Submit a game score | API Key |
| GET | `/scores/top?limit=10` | Get leaderboard | API Key |

### Files

```
serverless/
├── template.yaml              # SAM template (API GW, Lambda, DynamoDB, SNS)
└── functions/
    ├── api/
    │   ├── health.js          # Health check endpoint
    │   └── scores.js          # getScores, submitScore, getLeaderboard
    ├── processor/
    │   └── index.js           # DynamoDB Stream consumer
    └── notifier/
        └── index.js           # SNS-triggered notification sender
```

### Build Guide

See [docs/project4-serverless/BUILD-GUIDE.md](docs/project4-serverless/BUILD-GUIDE.md) for SAM deployment, local testing, and API usage examples.

---

## Project 5: Centralized Logging Stack (EFK)

### What It Does

Deploys an Elasticsearch-Fluentd-Kibana (EFK) stack on Kubernetes for centralized log aggregation. Fluentd collects logs from every node, enriches them with Kubernetes metadata, and ships them to Elasticsearch with index lifecycle management.

### Architecture

```
  Every K8s Node
       |
       v
  +-----------------+     +-----------------------+     +------------------+
  | Fluentd         |     | Elasticsearch         |     | Kibana           |
  | (DaemonSet)     |---->| (StatefulSet)         |---->| (Deployment)     |
  |                 |     |                       |     |                  |
  | - Tail logs     |     | - 10Gi PVC            |     | - Index patterns |
  | - Parse JSON    |     | - ILM policy          |     | - Saved searches |
  | - K8s metadata  |     |   Hot: 7d             |     |   - All Errors   |
  | - Drop noise    |     |   Warm: 7-30d         |     |   - Slow Reqs    |
  | - Add severity  |     |   Delete: 30d+        |     |   - Pod Restarts |
  | - Disk buffer   |     | - Daily indices       |     |                  |
  +-----------------+     +-----------------------+     +------------------+
```

### Key Features

- **Fluentd DaemonSet**: Runs on every node, including control-plane nodes via tolerations
- **Full parsing pipeline**: JSON parse, Kubernetes metadata enrichment, application log parsing, health check noise filtering, severity extraction
- **Disk-based buffering**: 8MB chunks with 5-second flush intervals prevent log loss
- **Index Lifecycle Management**: Hot (7 days, rollover at 10GB) -> Warm (shrink, force merge) -> Delete (30+ days)
- **Pre-built Kibana searches**: All Errors, Slow Requests (>2s), Pod Restarts (OOMKilled/Back-off)

### Fluentd Pipeline

```
Tail /var/log/containers/*.log
  -> Parse JSON
  -> Add Kubernetes metadata (pod, namespace, labels)
  -> Parse application JSON logs
  -> Drop health check noise (/health, /ready, /live)
  -> Add severity level
  -> Buffer to disk (8MB chunks, 5s flush)
  -> Output to Elasticsearch (daily indices: app-logs-YYYY.MM.DD)
```

### Files

```
logging/
├── elasticsearch/
│   ├── deployment.yaml        # StatefulSet + Service + 10Gi PVC
│   └── ilm-policy.json        # Hot -> Warm -> Delete lifecycle
├── fluentd/
│   ├── deployment.yaml        # DaemonSet + RBAC + ServiceAccount
│   └── config.yaml            # Full pipeline: input, filter, output
└── kibana/
    ├── deployment.yaml        # Deployment + Service
    └── saved-objects.ndjson   # Index pattern + 3 saved searches
```

### Build Guide

See [docs/project5-logging/BUILD-GUIDE.md](docs/project5-logging/BUILD-GUIDE.md) for deployment order, ILM configuration, and verification steps.

---

## Repository Structure

```
2048-cicd-enterprise/
├── 2048/                                  # Application
│   ├── Dockerfile                         # Security-hardened NGINX container
│   └── www/index.html                     # 2048 game (single-file app)
│
├── .github/workflows/                     # Project 1: CI/CD
│   ├── ci.yaml                            # PR quality gate pipeline
│   └── deploy.yaml                        # Blue/green production deploy
│
├── infra/                                 # Project 2: Terraform IaC
│   ├── main.tf                            # Provider, backend, locals
│   ├── variables.tf                       # Parameterized inputs
│   ├── terraform.tfvars                   # Production defaults
│   ├── vpc.tf                             # VPC, subnets, NAT, endpoints
│   ├── security-groups.tf                 # ALB, ECS, endpoint SGs
│   ├── ecr.tf                             # Container registry
│   ├── iam.tf                             # Roles, OIDC provider
│   ├── alb.tf                             # Load balancer, target groups
│   ├── ecs.tf                             # Cluster, services, auto-scaling
│   ├── cloudwatch.tf                      # Alarms, dashboard, SNS
│   └── outputs.tf                         # Resource references
│
├── k8s/                                   # Project 3: Kubernetes + Monitoring
│   ├── base/                              # Application manifests
│   │   ├── namespace.yaml                 # game-2048 + monitoring namespaces
│   │   ├── deployment.yaml                # 3-replica deployment with probes
│   │   ├── service.yaml                   # ClusterIP service
│   │   ├── hpa.yaml                       # HPA + PodDisruptionBudget
│   │   └── ingress.yaml                   # NGINX ingress
│   └── monitoring/                        # Observability stack
│       ├── prometheus/                    # Metrics collection
│       │   ├── config.yaml                # Scrape configs + 8 alert rules
│       │   ├── deployment.yaml            # Prometheus server + RBAC
│       │   └── node-exporter.yaml         # Node metrics DaemonSet
│       ├── grafana/                       # Visualization
│       │   ├── deployment.yaml            # Grafana server
│       │   └── config.yaml                # Datasource + dashboard JSON
│       └── alertmanager/                  # Alert routing
│           └── deployment.yaml            # Alertmanager + routing config
│
├── serverless/                            # Project 4: Serverless API
│   ├── template.yaml                      # SAM template (all resources)
│   └── functions/                         # Lambda function code
│       ├── api/health.js                  # Health check
│       ├── api/scores.js                  # CRUD score operations
│       ├── processor/index.js             # DynamoDB Stream consumer
│       └── notifier/index.js              # SNS notification handler
│
├── logging/                               # Project 5: EFK Stack
│   ├── elasticsearch/                     # Search + storage
│   │   ├── deployment.yaml                # StatefulSet + PVC
│   │   └── ilm-policy.json                # Index lifecycle policy
│   ├── fluentd/                           # Log collection
│   │   ├── deployment.yaml                # DaemonSet + RBAC
│   │   └── config.yaml                    # Pipeline configuration
│   └── kibana/                            # Visualization
│       ├── deployment.yaml                # Kibana server
│       └── saved-objects.ndjson           # Saved searches + index pattern
│
├── scripts/                               # Deployment automation
│   ├── deploy.sh                          # Blue/green deploy orchestration
│   ├── rollback.sh                        # Instant ALB rollback
│   ├── health-check.sh                    # ECS + HTTP health verification
│   └── smoke-test.sh                      # 9-point post-deploy validation
│
├── docs/                                  # Per-project documentation
│   ├── project1-cicd-pipeline/
│   │   ├── ARCHITECTURE.md                # 7 architecture diagrams
│   │   └── BUILD-GUIDE.md                 # Step-by-step build instructions
│   ├── project2-terraform-iac/
│   │   ├── ARCHITECTURE.md                # Resource dependency + VPC diagrams
│   │   └── BUILD-GUIDE.md                 # 10-step Terraform deployment
│   ├── project3-k8s-monitoring/
│   │   ├── ARCHITECTURE.md                # Namespace layout + monitoring flow
│   │   └── BUILD-GUIDE.md                 # K8s + monitoring deploy guide
│   ├── project4-serverless/
│   │   ├── ARCHITECTURE.md                # API + event-driven flow diagrams
│   │   └── BUILD-GUIDE.md                 # SAM deploy + local testing
│   └── project5-logging/
│       ├── ARCHITECTURE.md                # EFK data flow diagram
│       └── BUILD-GUIDE.md                 # Deploy order + verification
│
├── PROJECT-USE-CASES.md                   # 15 real-world use cases
├── ENTERPRISE-VALUE.md                    # ROI analysis + business cases
├── CLAUDE.md                              # AI assistant instructions
├── sonar-project.properties               # SonarQube configuration
├── .gitignore                             # Standard ignores
├── LICENSE                                # MIT License
└── README.md                              # This file
```

---

## Quick Start

### Prerequisites

| Tool | Version | Used By |
|------|---------|---------|
| Docker | 20+ | All projects |
| AWS CLI | 2.x | Projects 1, 2, 4 |
| Terraform | 1.0+ | Project 2 |
| kubectl | 1.27+ | Projects 3, 5 |
| AWS SAM CLI | 1.x | Project 4 |
| Node.js | 20.x | Project 4 |

### Per-Project Quick Start

**Project 1 - CI/CD Pipeline**:
```bash
# Test the container locally
docker build -t 2048-game ./2048
docker run -p 8080:80 2048-game
curl -I http://localhost:8080/health

# Activate: configure GitHub secrets and push to main
```

**Project 2 - Terraform IaC**:
```bash
cd infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Project 3 - Kubernetes + Monitoring**:
```bash
kubectl apply -f k8s/base/namespace.yaml
kubectl apply -f k8s/base/
kubectl apply -f k8s/monitoring/prometheus/
kubectl apply -f k8s/monitoring/grafana/
kubectl apply -f k8s/monitoring/alertmanager/
```

**Project 4 - Serverless API**:
```bash
cd serverless
sam build
sam deploy --guided
```

**Project 5 - EFK Logging**:
```bash
kubectl apply -f logging/elasticsearch/deployment.yaml
kubectl apply -f logging/fluentd/config.yaml
kubectl apply -f logging/fluentd/deployment.yaml
kubectl apply -f logging/kibana/deployment.yaml
```

See each project's BUILD-GUIDE.md for detailed instructions.

---

## Architecture Overview

### How the Projects Fit Together

```
                         +-------------------+
                         |   Developer Push  |
                         +--------+----------+
                                  |
                                  v
                    +----------------------------+
                    |  Project 1: CI/CD Pipeline |
                    |  (Build, Test, Deploy)     |
                    +-------------+--------------+
                                  |
                 +----------------+----------------+
                 |                                 |
                 v                                 v
  +----------------------------+    +----------------------------+
  |  Project 2: Terraform      |    |  Project 4: Serverless     |
  |  (AWS Infrastructure)      |    |  (API Backend)             |
  |                            |    |                            |
  |  VPC -> ALB -> ECS Fargate |    |  API GW -> Lambda -> DDB  |
  +-------------+--------------+    +----------------------------+
                |
                v
  +----------------------------+    +----------------------------+
  |  Project 3: Kubernetes     |    |  Project 5: EFK Logging    |
  |  (Orchestration + Monitor) |    |  (Centralized Logs)        |
  |                            |    |                            |
  |  Pods -> Prometheus ->     |    |  Fluentd -> Elasticsearch  |
  |  Grafana + Alertmanager    |    |  -> Kibana                 |
  +----------------------------+    +----------------------------+
```

- **Project 1** builds and deploys the application through the CI/CD pipeline
- **Project 2** provisions the AWS infrastructure that Project 1 deploys to
- **Project 3** runs the application on Kubernetes with full observability
- **Project 4** provides a serverless API backend (leaderboard, scores)
- **Project 5** collects and centralizes logs from all Kubernetes workloads

---

## Technology Stack

| Category | Technology | Project | Purpose |
|----------|-----------|---------|---------|
| **CI/CD** | GitHub Actions | 1 | Pipeline orchestration |
| **Quality** | SonarQube | 1 | Static code analysis |
| **Security** | Trivy | 1 | Container vulnerability scanning |
| **Container** | Docker + NGINX | 1, 3 | Application packaging and serving |
| **IaC** | Terraform | 2 | AWS resource provisioning |
| **Compute** | ECS Fargate | 2 | Serverless container hosting |
| **Networking** | VPC + ALB | 2 | Network isolation and load balancing |
| **Auth** | IAM + OIDC | 2 | Zero-credential GitHub authentication |
| **Orchestration** | Kubernetes | 3, 5 | Container scheduling and management |
| **Monitoring** | Prometheus | 3 | Metrics collection and alerting |
| **Dashboards** | Grafana | 3 | Metrics visualization |
| **Alerting** | Alertmanager | 3 | Alert routing and deduplication |
| **Serverless** | AWS Lambda | 4 | Event-driven compute |
| **API** | API Gateway | 4 | API management and throttling |
| **Database** | DynamoDB | 4 | NoSQL data storage |
| **Messaging** | SNS | 4 | Pub/sub notifications |
| **Search** | Elasticsearch | 5 | Log indexing and search |
| **Collection** | Fluentd | 5 | Log aggregation from nodes |
| **Visualization** | Kibana | 5 | Log exploration and saved searches |

---

## Best Practices Applied

### Security

- **No static credentials**: GitHub OIDC for AWS authentication (Project 2)
- **Least-privilege IAM**: Each service has minimal permissions (Projects 2, 4)
- **Container hardening**: Non-root user, security headers, Alpine base (Project 1)
- **API authentication**: API key + throttling + request validation (Project 4)
- **RBAC**: Kubernetes service accounts with minimal cluster permissions (Projects 3, 5)
- **Network isolation**: Private subnets for compute, VPC endpoints for AWS services (Project 2)

### Reliability

- **Zero-downtime deploys**: Blue/green with instant rollback (Project 1)
- **Health checks**: Liveness, readiness, and startup probes (Project 3)
- **Auto-scaling**: HPA for Kubernetes, target tracking for ECS (Projects 2, 3)
- **Pod disruption budgets**: Guarantee minimum availability during upgrades (Project 3)
- **DynamoDB point-in-time recovery**: Protect against accidental data loss (Project 4)
- **Disk-buffered logging**: Fluentd buffers to disk to prevent log loss (Project 5)

### Observability

- **Metrics**: Prometheus scrapes pods, nodes, and cAdvisor (Project 3)
- **Dashboards**: 7-panel Grafana dashboard with request rate, latency, CPU, memory (Project 3)
- **Alerting**: 8 Prometheus alert rules with severity-based routing (Project 3)
- **Logging**: Centralized EFK with Kubernetes metadata enrichment (Project 5)
- **CloudWatch**: 6 alarms + dashboard for AWS infrastructure (Project 2)
- **X-Ray tracing**: Active on all Lambda functions (Project 4)

### Cost Optimization

- **Serverless compute**: ECS Fargate and Lambda - pay only for what you use (Projects 2, 4)
- **Auto-scaling to zero**: Scale down during off-hours (Projects 2, 3)
- **Log lifecycle management**: ILM auto-deletes logs after 30 days (Project 5)
- **ECR lifecycle policies**: Keep only the 20 most recent images (Project 2)
- **PAY_PER_REQUEST DynamoDB**: No provisioned capacity costs when idle (Project 4)

### Infrastructure as Code

- **Version-controlled infrastructure**: All resources defined in code (Projects 2, 3, 4, 5)
- **Parameterized configurations**: Variables for all environment-specific values (Project 2)
- **Reproducible deployments**: Same code produces identical environments (All)
- **Self-documenting**: Resource tags, descriptions, and output values (Projects 2, 4)

---

## Cost Analysis

### Estimated Monthly Costs

| Project | Resources | Estimated Cost |
|---------|-----------|---------------|
| **1. CI/CD** | GitHub Actions (free tier) | $0 |
| **2. Terraform/AWS** | ECS Fargate + ALB + NAT + CloudWatch | ~$75/month |
| **3. K8s + Monitoring** | Cluster-dependent (EKS: ~$73 + nodes) | ~$150/month |
| **4. Serverless** | Lambda + DynamoDB + API GW (on-demand) | ~$2-5/month |
| **5. EFK Logging** | Elasticsearch + Fluentd + Kibana (on K8s) | ~$0 (uses K8s) |

Total platform cost depends on cluster sizing and traffic. The serverless project (4) is the most cost-efficient for low-to-medium traffic.

---

## Documentation

Each project has dedicated architecture and build documentation:

| Project | Architecture | Build Guide |
|---------|-------------|-------------|
| 1. CI/CD Pipeline | [ARCHITECTURE.md](docs/project1-cicd-pipeline/ARCHITECTURE.md) | [BUILD-GUIDE.md](docs/project1-cicd-pipeline/BUILD-GUIDE.md) |
| 2. Terraform IaC | [ARCHITECTURE.md](docs/project2-terraform-iac/ARCHITECTURE.md) | [BUILD-GUIDE.md](docs/project2-terraform-iac/BUILD-GUIDE.md) |
| 3. K8s & Monitoring | [ARCHITECTURE.md](docs/project3-k8s-monitoring/ARCHITECTURE.md) | [BUILD-GUIDE.md](docs/project3-k8s-monitoring/BUILD-GUIDE.md) |
| 4. Serverless API | [ARCHITECTURE.md](docs/project4-serverless/ARCHITECTURE.md) | [BUILD-GUIDE.md](docs/project4-serverless/BUILD-GUIDE.md) |
| 5. EFK Logging | [ARCHITECTURE.md](docs/project5-logging/ARCHITECTURE.md) | [BUILD-GUIDE.md](docs/project5-logging/BUILD-GUIDE.md) |

Additional documentation:
- [PROJECT-USE-CASES.md](PROJECT-USE-CASES.md) - 15 real-world use cases across all 5 projects
- [ENTERPRISE-VALUE.md](ENTERPRISE-VALUE.md) - ROI analysis and business case studies

---

## Contributing

Contributions are welcome. Please follow these conventions:

- **Commit messages**: Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`)
- **Branch naming**: `feature/<description>` or `fix/<description>`
- **Terraform**: Run `terraform fmt` and `terraform validate` before committing
- **YAML**: 2-space indentation
- **Shell scripts**: Include `set -euo pipefail` and descriptive variable names

## License

MIT License - See [LICENSE](LICENSE) for details.

---

**Technologies**: Docker, GitHub Actions, Terraform, AWS (ECS Fargate, Lambda, DynamoDB, API Gateway, ALB, ECR, CloudWatch, SNS, IAM, VPC), Kubernetes, Prometheus, Grafana, Alertmanager, Elasticsearch, Fluentd, Kibana, SonarQube

**Last Updated**: 2026-02-03
