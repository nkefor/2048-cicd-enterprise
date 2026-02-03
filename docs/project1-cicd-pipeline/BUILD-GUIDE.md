# Project 1: End-to-End CI/CD Pipeline - Step-by-Step Build Guide

## What You Will Build

A production-grade CI/CD pipeline with:

- **4-stage CI pipeline** with lint, security scan, SonarQube quality gate, and container testing
- **Blue/Green deployment** to AWS ECS Fargate with instant rollback
- **Automated security scanning** using Trivy, TruffleHog, and Hadolint
- **Post-deployment verification** with automated rollback on failure

---

## Prerequisites

- AWS account with ECS, ECR, ALB, and IAM configured
- GitHub repository with Actions enabled
- Docker installed locally
- AWS CLI configured

---

## Step 1: Security-Hardened Docker Container

**File**: `2048/Dockerfile`

The container uses `nginx:1.27-alpine` with these security measures:

```
┌──────────────────────────────────────────────┐
│           Docker Container                    │
│                                               │
│  NGINX 1.27 Alpine                           │
│  ├── Security Headers (7 headers)            │
│  │   ├── X-Content-Type-Options: nosniff     │
│  │   ├── X-Frame-Options: DENY              │
│  │   ├── X-XSS-Protection: 1; mode=block    │
│  │   ├── Referrer-Policy                     │
│  │   ├── Content-Security-Policy             │
│  │   ├── Strict-Transport-Security           │
│  │   └── Permissions-Policy                  │
│  ├── Server tokens disabled                  │
│  ├── Gzip compression enabled                │
│  ├── /health endpoint (JSON)                 │
│  ├── /info endpoint (deployment metadata)    │
│  ├── Static asset caching (7 day)            │
│  ├── Hidden file access blocked              │
│  └── Health check every 15s                  │
└──────────────────────────────────────────────┘
```

**Build and test locally:**

```bash
docker build -t 2048-game ./2048
docker run -d -p 8080:80 --name test 2048-game

# Verify
curl http://localhost:8080/          # Main page
curl http://localhost:8080/health    # Health endpoint
curl -I http://localhost:8080/       # Check security headers

docker rm -f test
```

---

## Step 2: CI Pipeline (Pull Request Validation)

**File**: `.github/workflows/ci.yaml`

This workflow runs on every PR to `main` and enforces the quality gate before merge.

```
    PR Opened
       │
       v
┌──────────────┐
│ Stage 1:     │
│ Lint &       │  Hadolint, YAML validation,
│ Validate     │  shell script lint, NGINX syntax
└──────┬───────┘
       │ PASS
       v
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Stage 2a:    │  │ Stage 2b:    │  │ Stage 2c:    │
│ Security     │  │ SonarQube    │  │ Container    │
│ Scan         │  │ Analysis     │  │ Tests        │
│              │  │              │  │              │
│ - Trivy FS   │  │ - Bugs       │  │ - Build test │
│ - Trivy Image│  │ - Code smells│  │ - Health     │
│ - TruffleHog │  │ - Vulns      │  │ - Headers    │
│ - Secrets    │  │ - Coverage   │  │ - Response   │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │
       └────────────┬────┴─────────────────┘
                    v
           ┌───────────────┐
           │ QUALITY GATE  │
           │               │
           │ All pass? ────│──> MERGE ALLOWED
           │ Any fail? ────│──> MERGE BLOCKED
           └───────────────┘
```

**Key behaviors:**
- Stage 1 must pass before Stage 2 begins
- Stage 2 jobs run in parallel for speed
- Security scan and container tests are mandatory
- SonarQube degrades gracefully if not configured

**Required GitHub secrets for SonarQube** (optional):
| Secret | Description |
|--------|-------------|
| `SONAR_TOKEN` | SonarQube authentication token |
| `SONAR_HOST_URL` | SonarQube server URL |

---

## Step 3: Blue/Green Deployment Pipeline

**File**: `.github/workflows/deploy.yaml`

Triggered on push to `main`, this workflow deploys using blue/green strategy.

```
    Push to main
         │
         v
    ┌─────────────┐
    │ BUILD       │  Lint, test locally, scan,
    │ & PUSH      │  build image, push to ECR
    └──────┬──────┘
           │
           v
    ┌─────────────┐
    │ IDENTIFY    │  Which env is active?
    │ ACTIVE ENV  │  (Query ALB listener rules)
    └──────┬──────┘
           │
           v
    ┌─────────────┐
    │ DEPLOY TO   │  Update standby ECS service
    │ STANDBY     │  Wait for service stability
    └──────┬──────┘
           │
           v
    ┌─────────────┐
    │ HEALTH      │  Check standby before cutover
    │ CHECK       │  (scripts/health-check.sh)
    └──────┬──────┘
           │ PASS
           v
    ┌─────────────┐
    │ SWITCH      │  Modify ALB listener rule
    │ TRAFFIC     │  (< 30 second cutover)
    └──────┬──────┘
           │
           v
    ┌─────────────┐
    │ VERIFY      │  Post-deploy health check
    │             │  E2E smoke tests (Playwright)
    └──────┬──────┘
           │
      ┌────┴────┐
      │         │
    PASS      FAIL
      │         │
      v         v
    ┌─────┐  ┌──────────┐
    │DONE │  │ ROLLBACK  │  Switch ALB back
    │     │  │ (auto)    │  to previous env
    └─────┘  └──────────┘
```

**Required GitHub secrets:**

| Secret | Description | Required |
|--------|-------------|----------|
| `AWS_REGION` | AWS region | Yes |
| `ECR_REPO` | Full ECR URI | Yes |
| `AWS_ROLE_ARN` | OIDC IAM role ARN | Yes |
| `TG_BLUE_ARN` | Blue target group ARN | For blue/green |
| `TG_GREEN_ARN` | Green target group ARN | For blue/green |
| `ALB_LISTENER_ARN` | ALB listener ARN | For blue/green |

**Manual controls** (workflow_dispatch):
- `force_rollback`: Switch traffic back to previous environment
- `target_env`: Force deploy to a specific environment (blue/green)

---

## Step 4: Deployment Scripts

Three scripts handle deployment operations:

### `scripts/deploy.sh` - Full Deployment Orchestration

```bash
# Full deployment with blue/green
./scripts/deploy.sh \
  --cluster game-2048 \
  --ecr-repo 123456789.dkr.ecr.us-east-1.amazonaws.com/game-2048 \
  --image-tag abc123-20260203-120000 \
  --region us-east-1 \
  --listener-arn arn:aws:elasticloadbalancing:... \
  --tg-blue-arn arn:aws:elasticloadbalancing:... \
  --tg-green-arn arn:aws:elasticloadbalancing:...

# Dry run (show what would happen)
./scripts/deploy.sh \
  --cluster game-2048 \
  --ecr-repo 123456789.dkr.ecr.us-east-1.amazonaws.com/game-2048 \
  --image-tag abc123 \
  --dry-run
```

### `scripts/rollback.sh` - Instant Rollback

```bash
# Auto-detect which environment to roll back to
./scripts/rollback.sh \
  --cluster game-2048 \
  --listener-arn arn:aws:elasticloadbalancing:... \
  --tg-blue-arn arn:aws:elasticloadbalancing:... \
  --tg-green-arn arn:aws:elasticloadbalancing:...

# Explicit target
./scripts/rollback.sh \
  --cluster game-2048 \
  --listener-arn arn:aws:elasticloadbalancing:... \
  --target-tg-arn arn:aws:elasticloadbalancing:.../tg-blue/...
```

### `scripts/health-check.sh` - Service Health Validation

```bash
# Check ECS service health
./scripts/health-check.sh \
  --cluster game-2048 \
  --service game-2048-blue \
  --region us-east-1 \
  --max-attempts 5 \
  --interval 10
```

### `scripts/smoke-test.sh` - Post-Deployment Smoke Tests

```bash
# Run full smoke test suite against a deployed endpoint
./scripts/smoke-test.sh --endpoint http://your-alb-dns.com

# Verbose output
./scripts/smoke-test.sh --endpoint http://localhost:8080 --verbose
```

Smoke tests verify:
1. Main page returns HTTP 200
2. Health endpoint returns 200 with JSON body
3. All 7 security headers present
4. Server version not disclosed
5. Response time under 2 seconds
6. Page contains expected content
7. 404 handling works
8. Hidden files (.env) blocked
9. Gzip compression active

---

## Step 5: SonarQube Quality Gate

**File**: `sonar-project.properties`

SonarQube analyzes code quality on every PR. Quality gate conditions:

| Condition | Threshold | Blocks Merge |
|-----------|-----------|:------------:|
| New bugs | 0 | Yes |
| New vulnerabilities | 0 | Yes |
| New code smells | < 5 | Yes |
| Duplicated lines (new code) | < 3% | Yes |
| Coverage (new code) | > 80% | No (warning) |
| Security hotspots reviewed | 100% | Yes |

If SonarQube is not configured (no `SONAR_TOKEN` secret), the pipeline falls back to local static analysis: checking for inline event handlers, TODO/FIXME comments, and basic code patterns.

---

## Step 6: Putting It All Together

### Complete Flow: Developer to Production

```
Developer writes code
        │
        ├── git commit -m "feat: new feature"
        ├── git push origin feature/my-feature
        │
        v
    [PR Created]
        │
        ├── ci.yaml triggers automatically
        ├── Lint, scan, SonarQube, container tests
        ├── Quality gate: PASS or BLOCK
        │
        v
    [PR Merged to main]
        │
        ├── deploy.yaml triggers automatically
        ├── Build image, push to ECR
        ├── Deploy to standby environment
        ├── Health check standby
        ├── Switch ALB traffic
        ├── Post-deploy verification
        │
        ├── SUCCESS: New version live, old version on standby
        └── FAILURE: Auto-rollback, old version restored
```

### How Rollback Works

The key insight of blue/green: **the old version is never stopped**. When the new version has an issue:

1. The ALB listener rule is modified to point back to the old target group
2. Traffic shifts in < 30 seconds
3. No container startup time - the old containers are already running
4. The failed deployment stays running for debugging

This is fundamentally different from a "redeploy the old version" approach, which requires pulling the old image, starting new containers, and waiting for health checks.

---

## File Structure Summary

```
2048-cicd-enterprise/
├── 2048/
│   ├── Dockerfile                          # Security-hardened NGINX container
│   └── www/
│       └── index.html                      # Application
│
├── .github/workflows/
│   ├── ci.yaml                             # PR quality gate pipeline
│   ├── deploy.yaml                         # Blue/green deploy pipeline
│   └── test.yaml                           # Comprehensive test suite
│
├── scripts/
│   ├── deploy.sh                           # Deployment orchestration
│   ├── rollback.sh                         # Instant rollback
│   ├── health-check.sh                     # Service health validation
│   └── smoke-test.sh                       # Post-deploy smoke tests
│
├── docs/project1-cicd-pipeline/
│   ├── ARCHITECTURE.md                     # Architecture diagrams
│   └── BUILD-GUIDE.md                      # This file
│
├── sonar-project.properties                # SonarQube configuration
├── package.json                            # Test dependencies
└── playwright.config.js                    # E2E test configuration
```

---

## AWS Infrastructure Required

To run the full blue/green deployment, you need:

| Resource | Purpose |
|----------|---------|
| ECS Cluster: `game-2048` | Container orchestration |
| ECS Service: `game-2048-blue` | Blue environment |
| ECS Service: `game-2048-green` | Green environment |
| ECR Repository | Docker image storage |
| ALB with 2 target groups | Traffic routing |
| IAM Role with OIDC trust | GitHub Actions auth |

If you only have a single ECS service (`game-2048`), the pipeline falls back to single-service rolling deployment mode automatically.

---

*Last Updated: 2026-02-03*
