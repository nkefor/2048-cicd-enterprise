# Project 2: Infrastructure as Code with Terraform - Architecture

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Terraform Resource Dependency Graph](#terraform-resource-dependency-graph)
- [VPC Network Architecture](#vpc-network-architecture)
- [ECS Fargate Architecture](#ecs-fargate-architecture)
- [Blue/Green Infrastructure Layout](#bluegreen-infrastructure-layout)
- [IAM Trust Chain](#iam-trust-chain)
- [State Management Architecture](#state-management-architecture)
- [Module Structure](#module-structure)

---

## High-Level Architecture

```
    ┌──────────────────────────────────────────────────────────────────┐
    │                    TERRAFORM CONTROL PLANE                       │
    │                                                                  │
    │  ┌──────────┐   ┌──────────────┐   ┌──────────────────────┐    │
    │  │ main.tf  │   │ variables.tf │   │ terraform.tfvars     │    │
    │  │ Provider │   │ Input Params │   │ (per environment)    │    │
    │  │ Backend  │   │ Defaults     │   │ dev / staging / prod │    │
    │  └────┬─────┘   └──────┬───────┘   └──────────┬───────────┘    │
    │       │                │                       │                 │
    │       └────────────────┴───────────────────────┘                 │
    │                        │                                         │
    │                        v                                         │
    │  ┌──────────────────────────────────────────────────────────┐   │
    │  │              terraform plan / apply                       │   │
    │  └──────────────────────┬───────────────────────────────────┘   │
    └─────────────────────────┼────────────────────────────────────────┘
                              │
                              v
    ╔══════════════════════════════════════════════════════════════════╗
    ║                       AWS CLOUD                                  ║
    ║                                                                  ║
    ║  ┌────────────────────────────────────────────────────────────┐ ║
    ║  │                    VPC (10.0.0.0/16)                       │ ║
    ║  │                        vpc.tf                              │ ║
    ║  │                                                            │ ║
    ║  │  ┌──────────────────┐  ┌──────────────────┐              │ ║
    ║  │  │  Public Subnets  │  │  Private Subnets │              │ ║
    ║  │  │  10.0.1.0/24     │  │  10.0.3.0/24     │              │ ║
    ║  │  │  10.0.2.0/24     │  │  10.0.4.0/24     │              │ ║
    ║  │  │                  │  │                   │              │ ║
    ║  │  │  ┌────────────┐  │  │  ┌─────────────┐ │              │ ║
    ║  │  │  │    ALB     │  │  │  │ ECS Fargate │ │              │ ║
    ║  │  │  │  alb.tf    │──│──│─>│   ecs.tf    │ │              │ ║
    ║  │  │  └────────────┘  │  │  └─────────────┘ │              │ ║
    ║  │  │                  │  │                   │              │ ║
    ║  │  │  ┌────────────┐  │  │  ┌─────────────┐ │              │ ║
    ║  │  │  │  NAT GW    │  │  │  │VPC Endpoints│ │              │ ║
    ║  │  │  │  (outbound) │  │  │  │ ecr/logs/s3│ │              │ ║
    ║  │  │  └────────────┘  │  │  └─────────────┘ │              │ ║
    ║  │  └──────────────────┘  └──────────────────┘              │ ║
    ║  └────────────────────────────────────────────────────────────┘ ║
    ║                                                                  ║
    ║  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   ║
    ║  │   ECR    │  │   IAM    │  │CloudWatch│  │ Security     │   ║
    ║  │  ecr.tf  │  │  iam.tf  │  │  cw.tf   │  │ Groups       │   ║
    ║  │          │  │          │  │          │  │  sg.tf       │   ║
    ║  └──────────┘  └──────────┘  └──────────┘  └──────────────┘   ║
    ╚══════════════════════════════════════════════════════════════════╝

    ┌──────────────────────────────────────────────────────────────────┐
    │                   REMOTE STATE (S3 + DynamoDB)                    │
    │                                                                  │
    │  ┌──────────────────┐  ┌──────────────────────────────────┐    │
    │  │  S3 Bucket       │  │  DynamoDB Table                  │    │
    │  │  terraform-state  │  │  terraform-lock                  │    │
    │  │  (versioned)      │  │  (state locking)                │    │
    │  └──────────────────┘  └──────────────────────────────────┘    │
    └──────────────────────────────────────────────────────────────────┘
```

---

## Terraform Resource Dependency Graph

```
    terraform init
         │
         v
    ┌─────────────┐
    │  main.tf    │  AWS Provider + S3 Backend
    │  (root)     │
    └──────┬──────┘
           │
           │  PHASE 1: Foundation (no dependencies)
           │
           ├──────────────────────────────────────────────┐
           │                                              │
    ┌──────▼──────┐  ┌──────────────┐  ┌────────────────▼───┐
    │   vpc.tf    │  │   ecr.tf     │  │    iam.tf          │
    │             │  │              │  │                     │
    │ - VPC       │  │ - ECR Repo   │  │ - ECS Task Role    │
    │ - Subnets   │  │ - Lifecycle  │  │ - ECS Exec Role    │
    │ - IGW       │  │   Policy     │  │ - GitHub OIDC Role │
    │ - NAT GW    │  │              │  │ - OIDC Provider    │
    │ - Routes    │  └──────┬───────┘  └─────────┬──────────┘
    └──────┬──────┘         │                    │
           │                │                    │
           │  PHASE 2: Depends on VPC            │
           │                                     │
    ┌──────▼──────────────┐                      │
    │  security-groups.tf │                      │
    │                     │                      │
    │ - ALB SG            │                      │
    │ - ECS Tasks SG      │                      │
    │ - VPC Endpoints SG  │                      │
    └──────┬──────────────┘                      │
           │                                     │
           │  PHASE 3: Depends on VPC + SGs      │
           │                                     │
    ┌──────▼──────┐  ┌──────────────────────┐    │
    │   alb.tf    │  │   vpc_endpoints      │    │
    │             │  │   (in vpc.tf)        │    │
    │ - ALB       │  │                      │    │
    │ - TG Blue   │  │ - ecr.api           │    │
    │ - TG Green  │  │ - ecr.dkr           │    │
    │ - Listeners │  │ - logs              │    │
    │             │  │ - s3 (gateway)      │    │
    └──────┬──────┘  └──────────────────────┘    │
           │                                     │
           │  PHASE 4: Depends on ALB + IAM + VPC│
           │                                     │
    ┌──────▼─────────────────────────────────────▼──┐
    │                    ecs.tf                       │
    │                                                │
    │  - ECS Cluster                                 │
    │  - Task Definition                             │
    │  - Service Blue (linked to TG Blue)            │
    │  - Service Green (linked to TG Green)          │
    │  - Auto-scaling policies                       │
    └──────────────────────┬─────────────────────────┘
                           │
           │  PHASE 5: Depends on ECS
           │
    ┌──────▼──────┐
    │cloudwatch.tf│
    │             │
    │ - Log Group │
    │ - Alarms    │
    │ - Dashboard │
    │ - SNS Topic │
    └──────┬──────┘
           │
           v
    ┌─────────────┐
    │ outputs.tf  │  Export values for CI/CD pipeline
    └─────────────┘
```

---

## VPC Network Architecture

```
    ┌────────────────────────────────────────────────────────────────┐
    │                    VPC: 10.0.0.0/16                            │
    │                    Name: game-2048-vpc                          │
    │                                                                │
    │    Availability Zone A           Availability Zone B           │
    │    ┌─────────────────────┐      ┌─────────────────────┐      │
    │    │ Public Subnet A     │      │ Public Subnet B     │      │
    │    │ 10.0.1.0/24         │      │ 10.0.2.0/24         │      │
    │    │                     │      │                     │      │
    │    │ ┌─────────────────┐ │      │ ┌─────────────────┐ │      │
    │    │ │    ALB (ENI)    │ │      │ │    ALB (ENI)    │ │      │
    │    │ └─────────────────┘ │      │ └─────────────────┘ │      │
    │    │ ┌─────────────────┐ │      │                     │      │
    │    │ │   NAT Gateway   │ │      │                     │      │
    │    │ └────────┬────────┘ │      │                     │      │
    │    └──────────┼──────────┘      └─────────────────────┘      │
    │               │                                                │
    │    ┌──────────▼──────────┐      ┌─────────────────────┐      │
    │    │ Private Subnet A    │      │ Private Subnet B    │      │
    │    │ 10.0.3.0/24         │      │ 10.0.4.0/24         │      │
    │    │                     │      │                     │      │
    │    │ ┌───────┐ ┌───────┐ │      │ ┌───────┐ ┌───────┐ │      │
    │    │ │ Blue  │ │ Green │ │      │ │ Blue  │ │ Green │ │      │
    │    │ │ Task  │ │ Task  │ │      │ │ Task  │ │ Task  │ │      │
    │    │ └───────┘ └───────┘ │      │ └───────┘ └───────┘ │      │
    │    └─────────────────────┘      └─────────────────────┘      │
    │                                                                │
    │    Route Tables:                                               │
    │    ┌─────────────────────────────────────────────────────┐    │
    │    │ Public RT:  0.0.0.0/0 → Internet Gateway            │    │
    │    │ Private RT: 0.0.0.0/0 → NAT Gateway                │    │
    │    └─────────────────────────────────────────────────────┘    │
    │                                                                │
    │    VPC Endpoints (Private Link):                               │
    │    ┌─────────────────────────────────────────────────────┐    │
    │    │ com.amazonaws.{region}.ecr.api     (Interface)       │    │
    │    │ com.amazonaws.{region}.ecr.dkr     (Interface)       │    │
    │    │ com.amazonaws.{region}.logs         (Interface)       │    │
    │    │ com.amazonaws.{region}.s3           (Gateway)        │    │
    │    └─────────────────────────────────────────────────────┘    │
    │                                                                │
    │    ┌──────────────────┐                                       │
    │    │ Internet Gateway │                                       │
    │    │ game-2048-igw    │                                       │
    │    └──────────────────┘                                       │
    └────────────────────────────────────────────────────────────────┘
```

---

## ECS Fargate Architecture

```
    ┌──────────────────────────────────────────────────────────────┐
    │              ECS Cluster: game-2048                           │
    │              Container Insights: Enabled                      │
    │                                                              │
    │  ┌───────────────────────────────────────────────────────┐  │
    │  │           Task Definition: game-2048                   │  │
    │  │                                                       │  │
    │  │  Container: game-2048                                 │  │
    │  │  ├── Image: {ECR_REPO}:{tag}                         │  │
    │  │  ├── CPU: 256 (0.25 vCPU)                            │  │
    │  │  ├── Memory: 512 MB                                   │  │
    │  │  ├── Port: 80 (TCP)                                   │  │
    │  │  ├── Health Check: /health                            │  │
    │  │  ├── Log Driver: awslogs                              │  │
    │  │  │   ├── Group: /ecs/game-2048                       │  │
    │  │  │   ├── Region: var.aws_region                      │  │
    │  │  │   └── Prefix: ecs                                 │  │
    │  │  └── Environment:                                     │  │
    │  │      ├── DEPLOY_ENV: blue|green                      │  │
    │  │      └── DEPLOY_VERSION: {git-sha}                   │  │
    │  └───────────────────────────────────────────────────────┘  │
    │                                                              │
    │  ┌──────────────────────┐  ┌──────────────────────┐        │
    │  │  Service: Blue       │  │  Service: Green      │        │
    │  │  game-2048-blue      │  │  game-2048-green     │        │
    │  │                      │  │                      │        │
    │  │  Desired: 2          │  │  Desired: 2          │        │
    │  │  Min: 1              │  │  Min: 1              │        │
    │  │  Max: 10             │  │  Max: 10             │        │
    │  │                      │  │                      │        │
    │  │  Subnets:            │  │  Subnets:            │        │
    │  │  - Private A         │  │  - Private A         │        │
    │  │  - Private B         │  │  - Private B         │        │
    │  │                      │  │                      │        │
    │  │  LB: TG Blue ────┐  │  │  LB: TG Green ──┐   │        │
    │  └──────────────────┼──┘  └──────────────────┼───┘        │
    │                     │                        │              │
    └─────────────────────┼────────────────────────┼──────────────┘
                          │                        │
                          v                        v
                   ┌─────────────┐          ┌─────────────┐
                   │ TG Blue     │          │ TG Green    │
                   │ Port: 80    │          │ Port: 80    │
                   │ Health: /   │          │ Health: /   │
                   └──────┬──────┘          └──────┬──────┘
                          │                        │
                          └──────────┬─────────────┘
                                     │
                              ┌──────▼──────┐
                              │     ALB     │
                              │ Listener:80 │
                              │  → Active TG│
                              └─────────────┘
```

---

## Blue/Green Infrastructure Layout

```
    TERRAFORM CREATES BOTH ENVIRONMENTS SIMULTANEOUSLY

    ┌──────────────────────────────────────────────────────────────┐
    │                          ALB                                  │
    │                   game-2048-alb                               │
    │                                                              │
    │  Listener HTTP:80                                            │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │  Default Action: Forward to active target group       │   │
    │  │  (Managed by CI/CD pipeline, not Terraform)          │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  ┌─────────────────────┐    ┌─────────────────────┐        │
    │  │  Target Group: Blue │    │ Target Group: Green │        │
    │  │  game-2048-tg-blue  │    │ game-2048-tg-green  │        │
    │  │                     │    │                     │        │
    │  │  Health Check:      │    │  Health Check:      │        │
    │  │    Path: /          │    │    Path: /          │        │
    │  │    Interval: 15s    │    │    Interval: 15s    │        │
    │  │    Healthy: 2       │    │    Healthy: 2       │        │
    │  │    Unhealthy: 3     │    │    Unhealthy: 3     │        │
    │  │    Timeout: 5s      │    │    Timeout: 5s      │        │
    │  └─────────┬───────────┘    └─────────┬───────────┘        │
    └────────────┼────────────────────────────┼────────────────────┘
                 │                            │
                 v                            v
    ┌─────────────────────┐    ┌─────────────────────┐
    │  ECS Service: Blue  │    │ ECS Service: Green  │
    │  game-2048-blue     │    │ game-2048-green     │
    │                     │    │                     │
    │  ┌───────┐┌───────┐ │    │ ┌───────┐┌───────┐ │
    │  │Task 1 ││Task 2 │ │    │ │Task 1 ││Task 2 │ │
    │  │ AZ-A  ││ AZ-B  │ │    │ │ AZ-A  ││ AZ-B  │ │
    │  └───────┘└───────┘ │    │ └───────┘└───────┘ │
    └─────────────────────┘    └─────────────────────┘

    TERRAFORM MANAGES:                CI/CD MANAGES:
    ├── VPC + Subnets                 ├── Which TG is active
    ├── ALB + Both TGs                │   (ALB listener rule)
    ├── Both ECS Services             ├── Container image version
    ├── Task Definition (template)    ├── Force new deployment
    ├── IAM Roles                     └── Rollback decisions
    ├── Security Groups
    ├── CloudWatch
    └── ECR Repository
```

---

## IAM Trust Chain

```
    ┌──────────────────────────────────────────────────────────────┐
    │                  GitHub Actions (CI/CD)                       │
    │                                                              │
    │  Uses OIDC token to assume IAM role                          │
    │  (No static AWS credentials stored)                          │
    └────────────────────┬─────────────────────────────────────────┘
                         │ AssumeRoleWithWebIdentity
                         v
    ┌──────────────────────────────────────────────────────────────┐
    │              IAM Role: github-actions-role                    │
    │                                                              │
    │  Trust Policy:                                               │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │  Principal: arn:aws:iam::*:oidc-provider/            │   │
    │  │             token.actions.githubusercontent.com       │   │
    │  │  Condition: token.actions....:sub =                   │   │
    │  │    "repo:{github_owner}/{github_repo}:ref:refs/..."  │   │
    │  └──────────────────────────────────────────────────────┘   │
    │                                                              │
    │  Permissions:                                                │
    │  ├── ECR: Push/Pull images                                  │
    │  ├── ECS: Update services, describe services                │
    │  ├── ELBv2: Describe/modify rules and target groups         │
    │  └── CloudWatch Logs: Create streams, put events            │
    └────────────────────┬─────────────────────────────────────────┘
                         │
                         v
    ┌──────────────────────────────────────────────────────────────┐
    │         ECS Task Execution Role                              │
    │         (Used by ECS agent to pull images and write logs)    │
    │                                                              │
    │  Permissions:                                                │
    │  ├── ecr:GetAuthorizationToken                              │
    │  ├── ecr:BatchGetImage                                      │
    │  ├── ecr:GetDownloadUrlForLayer                             │
    │  ├── logs:CreateLogStream                                   │
    │  └── logs:PutLogEvents                                      │
    └──────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │         ECS Task Role                                        │
    │         (Used by the application running inside the task)    │
    │                                                              │
    │  Permissions:                                                │
    │  └── (none required for static app - ready for expansion)   │
    └──────────────────────────────────────────────────────────────┘
```

---

## State Management Architecture

```
    Developer A                     Developer B
    ┌──────────┐                   ┌──────────┐
    │terraform │                   │terraform │
    │  plan    │                   │  apply   │
    └────┬─────┘                   └────┬─────┘
         │                              │
         │  1. Acquire lock             │  1. Acquire lock
         v                              v
    ┌──────────────────────────────────────────────┐
    │           DynamoDB: terraform-lock            │
    │                                              │
    │  LockID: game-2048-prod                      │
    │  Who:    Developer A                         │
    │  When:   2026-02-03T12:00:00Z                │
    │                                              │
    │  Developer B BLOCKED until A releases lock   │
    └──────────────────────────────────────────────┘
         │
         │  2. Read/Write state
         v
    ┌──────────────────────────────────────────────┐
    │           S3: terraform-state-bucket          │
    │                                              │
    │  Key: game-2048/prod/terraform.tfstate       │
    │                                              │
    │  Features:                                   │
    │  ├── Versioning: Enabled (rollback state)    │
    │  ├── Encryption: AES-256 (SSE-S3)           │
    │  ├── Access: Restricted to IAM roles         │
    │  └── Lifecycle: Keep 30 versions             │
    └──────────────────────────────────────────────┘

    Environment Isolation:

    S3 Key Structure:
    ├── game-2048/dev/terraform.tfstate
    ├── game-2048/staging/terraform.tfstate
    └── game-2048/prod/terraform.tfstate
```

---

## Module Structure

```
    infra/
    │
    │   Root Configuration
    │   ══════════════════
    ├── main.tf                 # Provider, backend, data sources
    ├── variables.tf            # All input variables with defaults
    ├── outputs.tf              # Exported values for CI/CD
    ├── terraform.tfvars        # Default variable values
    │
    │   Resource Files (alphabetical)
    │   ═════════════════════════════
    ├── alb.tf                  # ALB + target groups + listeners
    ├── cloudwatch.tf           # Logs + alarms + dashboard + SNS
    ├── ecr.tf                  # Container registry + lifecycle
    ├── ecs.tf                  # Cluster + task def + services
    ├── iam.tf                  # Roles + policies + OIDC
    ├── security-groups.tf      # SGs for ALB + ECS + endpoints
    └── vpc.tf                  # VPC + subnets + NAT + endpoints

    Each file is self-contained:
    - All resources of one type in one file
    - Comments explain why, not what
    - Tags on every resource for cost tracking
```

---

*Last Updated: 2026-02-03*
