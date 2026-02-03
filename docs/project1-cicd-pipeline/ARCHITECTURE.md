# Project 1: End-to-End CI/CD Pipeline - Architecture

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Pipeline Stages](#pipeline-stages)
- [Blue/Green Deployment Architecture](#bluegreen-deployment-architecture)
- [SonarQube Quality Gate Flow](#sonarqube-quality-gate-flow)
- [Security Scanning Architecture](#security-scanning-architecture)
- [Rollback Architecture](#rollback-architecture)
- [Network & Infrastructure Layout](#network--infrastructure-layout)
- [Component Reference](#component-reference)

---

## High-Level Architecture

```
                          DEVELOPER WORKFLOW
                          =================

    ┌──────────┐     ┌──────────┐     ┌──────────────────┐
    │Developer │────>│  Git     │────>│  GitHub           │
    │Workstation│    │  Commit  │     │  Repository       │
    └──────────┘     └──────────┘     └────────┬─────────┘
                                               │
                          ┌────────────────────┘
                          │ Webhook Trigger
                          │ (push to main / PR)
                          v
    ╔═══════════════════════════════════════════════════════════════╗
    ║               GITHUB ACTIONS CI/CD ENGINE                     ║
    ║                                                               ║
    ║  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐  ║
    ║  │ STAGE 1 │─>│ STAGE 2  │─>│ STAGE 3 │─>│   STAGE 4    │  ║
    ║  │  Lint   │  │  Test &  │  │  Build  │  │   Deploy      │  ║
    ║  │& Validate│  │  Scan   │  │ & Push  │  │  Blue/Green   │  ║
    ║  └─────────┘  └──────────┘  └─────────┘  └──────────────┘  ║
    ║       │            │             │               │           ║
    ║       v            v             v               v           ║
    ║  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐  ║
    ║  │Hadolint │  │SonarQube │  │ Docker  │  │ ECS Fargate  │  ║
    ║  │Yamllint │  │ Trivy    │  │ Buildx  │  │ Target Group │  ║
    ║  │Shellchk │  │TruffleHog│  │  ECR    │  │   Switch     │  ║
    ║  └─────────┘  └──────────┘  └─────────┘  └──────────────┘  ║
    ╚═══════════════════════════════════════════════════════════════╝
                                                       │
                          ┌────────────────────────────┘
                          v
    ╔═══════════════════════════════════════════════════════════════╗
    ║                    AWS CLOUD (Production)                     ║
    ║                                                               ║
    ║  ┌──────────────────────────────────────────────────────┐    ║
    ║  │              Application Load Balancer                │    ║
    ║  │         ┌──────────────┬──────────────┐              │    ║
    ║  │         │ Listener:443 │ Listener:80  │              │    ║
    ║  │         └──────┬───────┴──────┬───────┘              │    ║
    ║  │                │              │                       │    ║
    ║  │    ┌───────────▼──┐   ┌──────▼───────────┐          │    ║
    ║  │    │  TG: Blue    │   │  TG: Green       │          │    ║
    ║  │    │  (Active)    │   │  (Standby)       │          │    ║
    ║  │    └──────┬───────┘   └──────┬───────────┘          │    ║
    ║  └───────────┼──────────────────┼───────────────────────┘    ║
    ║              │                  │                             ║
    ║  ┌───────────▼──────────────────▼───────────────────────┐    ║
    ║  │              ECS Fargate Cluster                       │    ║
    ║  │  ┌──────────────┐        ┌──────────────┐            │    ║
    ║  │  │ Blue Service │        │Green Service │            │    ║
    ║  │  │ ┌────┐┌────┐│        │ ┌────┐┌────┐ │            │    ║
    ║  │  │ │Task││Task││        │ │Task││Task│ │            │    ║
    ║  │  │ │ 1  ││ 2  ││        │ │ 1  ││ 2  │ │            │    ║
    ║  │  │ └────┘└────┘│        │ └────┘└────┘ │            │    ║
    ║  │  └──────────────┘        └──────────────┘            │    ║
    ║  └──────────────────────────────────────────────────────┘    ║
    ║                                                               ║
    ║  ┌─────────────┐  ┌─────────────┐  ┌──────────────────┐    ║
    ║  │  Amazon ECR  │  │ CloudWatch  │  │  SNS (Alerts)    │    ║
    ║  │  (Registry)  │  │ (Logs/Metrics│  │  (Notifications) │    ║
    ║  └─────────────┘  └─────────────┘  └──────────────────┘    ║
    ╚═══════════════════════════════════════════════════════════════╝
```

---

## Pipeline Stages

### Detailed Stage Breakdown

```
    PR Created / Push to main
              │
              v
    ╔═════════════════════════════════════════════════════════╗
    ║ STAGE 1: LINT & VALIDATE            (~1 min)            ║
    ║                                                         ║
    ║  ┌─────────────────┐  ┌──────────────────────────────┐ ║
    ║  │ Dockerfile Lint  │  │ Workflow YAML Validation     │ ║
    ║  │ (Hadolint)       │  │ (actionlint / yamllint)      │ ║
    ║  └────────┬────────┘  └──────────────┬───────────────┘ ║
    ║           │                          │                  ║
    ║  ┌────────▼────────┐  ┌──────────────▼───────────────┐ ║
    ║  │ Shell Script    │  │ NGINX Config Syntax Check    │ ║
    ║  │ Lint (shellchk) │  │ (nginx -t in container)      │ ║
    ║  └────────┬────────┘  └──────────────┬───────────────┘ ║
    ╚═══════════╪══════════════════════════╪══════════════════╝
                │          PASS            │
                └────────────┬─────────────┘
                             v
    ╔═════════════════════════════════════════════════════════╗
    ║ STAGE 2: TEST & SECURITY SCAN       (~3 min)            ║
    ║                                                         ║
    ║  ┌─────────────────────────────────────────────────┐   ║
    ║  │              Parallel Execution                  │   ║
    ║  │                                                  │   ║
    ║  │  ┌──────────────┐  ┌───────────────────────┐   │   ║
    ║  │  │ SonarQube    │  │ Trivy Vulnerability   │   │   ║
    ║  │  │ Analysis     │  │ Scan (CRITICAL/HIGH)  │   │   ║
    ║  │  │ - Bugs       │  └───────────────────────┘   │   ║
    ║  │  │ - Code Smells│                               │   ║
    ║  │  │ - Vulns      │  ┌───────────────────────┐   │   ║
    ║  │  │ - Coverage   │  │ TruffleHog Secrets    │   │   ║
    ║  │  └──────────────┘  │ Scan (leaked creds)   │   │   ║
    ║  │                     └───────────────────────┘   │   ║
    ║  │  ┌──────────────┐  ┌───────────────────────┐   │   ║
    ║  │  │ Docker Build │  │ Container Smoke Test  │   │   ║
    ║  │  │ Test (local) │  │ (curl health check)   │   │   ║
    ║  │  └──────────────┘  └───────────────────────┘   │   ║
    ║  └─────────────────────────────────────────────────┘   ║
    ║                                                         ║
    ║  ┌─────────────────────────────────────────────────┐   ║
    ║  │         QUALITY GATE DECISION                    │   ║
    ║  │                                                  │   ║
    ║  │  SonarQube gate passed?  ──── NO ──> FAIL BUILD │   ║
    ║  │  Trivy critical vulns?   ──── YES ─> FAIL BUILD │   ║
    ║  │  Secrets detected?       ──── YES ─> FAIL BUILD │   ║
    ║  │  Docker build works?     ──── NO ──> FAIL BUILD │   ║
    ║  │                                                  │   ║
    ║  │  All clear? ──────────── YES ─> PROCEED         │   ║
    ║  └─────────────────────────────────────────────────┘   ║
    ╚═══════════════════════╪═════════════════════════════════╝
                            │ PASS
                            v
    ╔═════════════════════════════════════════════════════════╗
    ║ STAGE 3: BUILD & PUSH               (~2 min)            ║
    ║                                                         ║
    ║  ┌──────────────────────────────────────────────┐      ║
    ║  │ Docker Buildx (multi-platform)                │      ║
    ║  │                                               │      ║
    ║  │  Image Tags:                                  │      ║
    ║  │   - {ECR_REPO}:{git-sha}                     │      ║
    ║  │   - {ECR_REPO}:latest                         │      ║
    ║  │   - {ECR_REPO}:{blue|green}-{timestamp}      │      ║
    ║  │                                               │      ║
    ║  │  Cache: registry-based layer caching          │      ║
    ║  └──────────────┬───────────────────────────────┘      ║
    ║                 │                                        ║
    ║                 v                                        ║
    ║  ┌──────────────────────────────────────────────┐      ║
    ║  │ Push to Amazon ECR                            │      ║
    ║  │ (OIDC auth - no static credentials)           │      ║
    ║  └──────────────┬───────────────────────────────┘      ║
    ╚═════════════════╪═══════════════════════════════════════╝
                      │
                      v
    ╔═════════════════════════════════════════════════════════╗
    ║ STAGE 4: BLUE/GREEN DEPLOY          (~5 min)            ║
    ║                                                         ║
    ║  ┌──────────────────────────────────────────────┐      ║
    ║  │ 1. Identify active environment (blue/green)   │      ║
    ║  │ 2. Deploy new image to STANDBY environment    │      ║
    ║  │ 3. Run health checks against standby          │      ║
    ║  │ 4. Switch ALB target group (traffic cutover)  │      ║
    ║  │ 5. Validate production traffic                │      ║
    ║  │ 6. Keep old environment for instant rollback  │      ║
    ║  └──────────────────────────────────────────────┘      ║
    ║                                                         ║
    ║  ┌──────────────────────────────────────────────┐      ║
    ║  │         POST-DEPLOY VERIFICATION              │      ║
    ║  │                                               │      ║
    ║  │  - HTTP 200 health check (5 retries)         │      ║
    ║  │  - Security header verification               │      ║
    ║  │  - Response time < 2s threshold               │      ║
    ║  │  - Error rate monitoring (5 min window)       │      ║
    ║  │                                               │      ║
    ║  │  FAIL? ──> Automatic Rollback                │      ║
    ║  │  PASS? ──> Notify Success (Slack/SNS)        │      ║
    ║  └──────────────────────────────────────────────┘      ║
    ╚═════════════════════════════════════════════════════════╝
```

---

## Blue/Green Deployment Architecture

### Traffic Flow During Deployment

```
    BEFORE DEPLOYMENT                    DURING DEPLOYMENT
    (Blue = Active)                      (Green = Deploying)

    Internet Traffic                     Internet Traffic
         │                                    │
         v                                    v
    ┌─────────┐                          ┌─────────┐
    │   ALB   │                          │   ALB   │
    └────┬────┘                          └────┬────┘
         │                                    │
         │ 100% traffic                       │ 100% still to Blue
         │                                    │
    ┌────▼────┐  ┌─────────┐            ┌────▼────┐  ┌─────────┐
    │TG: Blue │  │TG: Green│            │TG: Blue │  │TG: Green│
    │ (Active)│  │ (Idle)  │            │ (Active)│  │(Deploy) │
    │ v1.0.0  │  │  empty  │            │ v1.0.0  │  │ v1.1.0  │
    └────┬────┘  └─────────┘            └────┬────┘  └────┬────┘
         │                                    │            │
         v                                    v            v
    ┌─────────┐                          ┌─────────┐ ┌─────────┐
    │  Tasks  │                          │  Tasks  │ │  Tasks  │
    │  v1.0.0 │                          │  v1.0.0 │ │  v1.1.0 │
    └─────────┘                          └─────────┘ └─────────┘


    CUTOVER                              AFTER DEPLOYMENT
    (Switch traffic)                     (Green = Active)

    Internet Traffic                     Internet Traffic
         │                                    │
         v                                    v
    ┌─────────┐                          ┌─────────┐
    │   ALB   │                          │   ALB   │
    └────┬────┘                          └────┬────┘
         │                                    │
         │ Switching...                       │ 100% traffic
         │                                    │
    ┌─────────┐  ┌─────────┐            ┌─────────┐  ┌────▼────┐
    │TG: Blue │  │TG: Green│            │TG: Blue │  │TG: Green│
    │(Drain)  │  │(Receive)│            │(Standby)│  │ (Active)│
    │ v1.0.0  │  │ v1.1.0  │            │ v1.0.0  │  │ v1.1.0  │
    └────┬────┘  └────┬────┘            └────┬────┘  └────┬────┘
         │            │                       │            │
         v            v                       v            v
    ┌─────────┐ ┌─────────┐            ┌─────────┐ ┌─────────┐
    │Draining │ │Receiving│            │ Standby │ │  Active │
    │ v1.0.0  │ │ v1.1.0  │            │ v1.0.0  │ │  v1.1.0 │
    └─────────┘ └─────────┘            └─────────┘ └─────────┘
                                        (ready for
                                         instant rollback)
```

### Rollback Flow

```
    ISSUE DETECTED!
         │
         v
    ┌────────────────────────┐
    │ Health check fails     │
    │ OR error rate > 5%     │
    │ OR manual trigger      │
    └───────────┬────────────┘
                │
                v
    ┌────────────────────────┐     ┌──────────────────────┐
    │ Switch ALB listener    │────>│ Old environment      │
    │ back to previous TG    │     │ still running         │
    │ (< 30 seconds)         │     │ (instant recovery)   │
    └───────────┬────────────┘     └──────────────────────┘
                │
                v
    ┌────────────────────────┐
    │ Notify team via SNS    │
    │ Log rollback event     │
    │ Preserve failed env    │
    │ for debugging          │
    └────────────────────────┘

    Total rollback time: < 60 seconds
    (No redeployment needed - just a target group switch)
```

---

## SonarQube Quality Gate Flow

```
    ┌──────────────┐
    │  Git Push /  │
    │  PR Created  │
    └──────┬───────┘
           │
           v
    ┌──────────────────────────────────────────────┐
    │           SonarQube Scanner                    │
    │                                                │
    │  Analyzes:                                     │
    │  ┌────────────┐  ┌────────────┐               │
    │  │   Bugs     │  │   Vulns    │               │
    │  │  (0 new)   │  │  (0 new)   │               │
    │  └────────────┘  └────────────┘               │
    │  ┌────────────┐  ┌────────────┐               │
    │  │Code Smells │  │ Duplicates │               │
    │  │ (< 5 new)  │  │  (< 3%)    │               │
    │  └────────────┘  └────────────┘               │
    │  ┌────────────┐                                │
    │  │ Coverage   │                                │
    │  │ (> 80%)    │                                │
    │  └────────────┘                                │
    └──────────┬───────────────────────────────────────┘
               │
               v
    ┌──────────────────────┐
    │   QUALITY GATE       │
    │                      │
    │  Conditions:         │         ┌─────────────────┐
    │  - 0 new bugs       ├── FAIL─>│ Block merge/     │
    │  - 0 new vulns      │         │ deploy. Notify   │
    │  - < 5 code smells  │         │ developer.       │
    │  - < 3% duplication │         └─────────────────┘
    │  - > 80% coverage   │
    │                      │         ┌─────────────────┐
    │                      ├── PASS─>│ Proceed to      │
    │                      │         │ build & deploy   │
    └──────────────────────┘         └─────────────────┘
```

---

## Security Scanning Architecture

```
    ┌──────────────────────────────────────────────────────────────┐
    │                SECURITY SCANNING LAYER                        │
    │                                                              │
    │  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
    │  │   PRE-BUILD    │  │   BUILD-TIME    │  │  POST-BUILD  │ │
    │  │                │  │                 │  │              │ │
    │  │ TruffleHog     │  │ Trivy FS Scan   │  │ Trivy Image  │ │
    │  │ (secrets in    │  │ (Dockerfile &   │  │ Scan         │ │
    │  │  git history)  │  │  dependencies)  │  │ (CVEs in     │ │
    │  │                │  │                 │  │  final image)│ │
    │  │ Hadolint       │  │ NGINX Config    │  │              │ │
    │  │ (Dockerfile    │  │ Validation      │  │ Security     │ │
    │  │  best practice)│  │ (nginx -t)      │  │ Header Check │ │
    │  └───────┬────────┘  └────────┬────────┘  └──────┬───────┘ │
    │          │                    │                   │          │
    │          v                    v                   v          │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │              SECURITY DECISION MATRIX                 │   │
    │  │                                                       │   │
    │  │  CRITICAL vuln found?     ──> BLOCK deployment       │   │
    │  │  HIGH vuln found?         ──> BLOCK deployment       │   │
    │  │  Secret leaked in code?   ──> BLOCK + alert SecOps   │   │
    │  │  Dockerfile best practice ──> WARN (non-blocking)    │   │
    │  │  MEDIUM/LOW vulns?        ──> WARN + create ticket   │   │
    │  └──────────────────────────────────────────────────────┘   │
    └──────────────────────────────────────────────────────────────┘
```

---

## Network & Infrastructure Layout

```
    ┌──────────────────────────────────────────────────────────────────┐
    │                         VPC (10.0.0.0/16)                        │
    │                                                                  │
    │  ┌────────────────────────────────────────────────────────────┐  │
    │  │              PUBLIC SUBNETS (10.0.1.0/24, 10.0.2.0/24)     │  │
    │  │                                                             │  │
    │  │  ┌──────────────────────────────────────────────────────┐  │  │
    │  │  │         Application Load Balancer (ALB)               │  │  │
    │  │  │                                                       │  │  │
    │  │  │  Listeners:                                           │  │  │
    │  │  │  - HTTPS:443 (SSL termination, ACM certificate)      │  │  │
    │  │  │  - HTTP:80 (redirect to HTTPS)                       │  │  │
    │  │  │                                                       │  │  │
    │  │  │  Target Groups:                                       │  │  │
    │  │  │  - tg-blue  (port 80, health: /  interval: 15s)     │  │  │
    │  │  │  - tg-green (port 80, health: /  interval: 15s)     │  │  │
    │  │  └──────────────────────────────────────────────────────┘  │  │
    │  │                                                             │  │
    │  │  ┌──────────┐                                              │  │
    │  │  │ NAT GW   │  (outbound internet for private subnets)    │  │
    │  │  └──────────┘                                              │  │
    │  └────────────────────────────────────────────────────────────┘  │
    │                                                                  │
    │  ┌────────────────────────────────────────────────────────────┐  │
    │  │           PRIVATE SUBNETS (10.0.3.0/24, 10.0.4.0/24)      │  │
    │  │                                                             │  │
    │  │  ┌────────────────────────────────────────────────────┐    │  │
    │  │  │           ECS Fargate Cluster: game-2048            │    │  │
    │  │  │                                                     │    │  │
    │  │  │  ┌─────────────────┐    ┌─────────────────┐        │    │  │
    │  │  │  │  Service: Blue  │    │ Service: Green  │        │    │  │
    │  │  │  │                 │    │                 │        │    │  │
    │  │  │  │  Task Def: v1   │    │ Task Def: v2   │        │    │  │
    │  │  │  │  Desired: 2     │    │ Desired: 2     │        │    │  │
    │  │  │  │  CPU: 0.25 vCPU │    │ CPU: 0.25 vCPU │        │    │  │
    │  │  │  │  Mem: 512 MB    │    │ Mem: 512 MB    │        │    │  │
    │  │  │  └─────────────────┘    └─────────────────┘        │    │  │
    │  │  └────────────────────────────────────────────────────┘    │  │
    │  │                                                             │  │
    │  │  Security Group: sg-ecs-tasks                               │  │
    │  │  - Inbound: TCP 80 from ALB security group only            │  │
    │  │  - Outbound: HTTPS to ECR, CloudWatch, S3 (VPC endpoints) │  │
    │  └────────────────────────────────────────────────────────────┘  │
    │                                                                  │
    │  ┌────────────────────────────────────────────────────────────┐  │
    │  │                   VPC ENDPOINTS                              │  │
    │  │  - ecr.api          (pull images without internet)         │  │
    │  │  - ecr.dkr          (docker registry access)              │  │
    │  │  - logs             (CloudWatch log delivery)             │  │
    │  │  - s3 (gateway)     (ECR layer storage)                   │  │
    │  └────────────────────────────────────────────────────────────┘  │
    └──────────────────────────────────────────────────────────────────┘
```

---

## Component Reference

### GitHub Actions Workflows

| Workflow | Trigger | Purpose | File |
|----------|---------|---------|------|
| `ci.yaml` | PR to main | Lint, test, scan, quality gate | `.github/workflows/ci.yaml` |
| `deploy.yaml` | Push to main | Build, push, blue/green deploy | `.github/workflows/deploy.yaml` |

### Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `scripts/deploy.sh` | Orchestrate blue/green deployment | Called by deploy workflow |
| `scripts/rollback.sh` | Instant rollback to previous version | Manual or automated trigger |
| `scripts/health-check.sh` | Validate deployment health | Called post-deploy |

### Configuration Files

| File | Purpose |
|------|---------|
| `sonar-project.properties` | SonarQube scanner configuration |
| `2048/Dockerfile` | Container definition with security hardening |
| `playwright.config.js` | E2E test configuration |

### AWS Resources

| Resource | Name | Purpose |
|----------|------|---------|
| ECS Cluster | `game-2048` | Container orchestration |
| ECS Service (Blue) | `game-2048-blue` | Active or standby workload |
| ECS Service (Green) | `game-2048-green` | Active or standby workload |
| ALB | `game-2048-alb` | Traffic distribution |
| Target Group (Blue) | `game-2048-tg-blue` | Blue service targets |
| Target Group (Green) | `game-2048-tg-green` | Green service targets |
| ECR Repository | `game-2048` | Container image storage |
| CloudWatch Log Group | `/ecs/game-2048` | Centralized logging |
| SNS Topic | `game-2048-deploy-notifications` | Deployment alerts |

---

## Data Flow Summary

```
    Code Commit
         │
         v
    [Lint & Validate] ── fail ──> Developer notified, PR blocked
         │ pass
         v
    [SonarQube + Trivy + TruffleHog] ── fail ──> Developer notified, PR blocked
         │ pass
         v
    [Docker Build + Push to ECR]
         │
         v
    [Identify standby environment]
         │
         v
    [Deploy to standby ECS service]
         │
         v
    [Health checks on standby] ── fail ──> Abort, notify team
         │ pass
         v
    [Switch ALB to standby target group]
         │
         v
    [Post-deploy verification] ── fail ──> Auto-rollback (switch ALB back)
         │ pass
         v
    [Notify success via SNS/Slack]
         │
         v
    [Old environment kept as rollback target]
```

---

*Last Updated: 2026-02-03*
