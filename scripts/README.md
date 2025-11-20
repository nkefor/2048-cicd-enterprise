# CI/CD Automation Scripts

This directory contains production-ready automation scripts for managing the Enterprise CI/CD platform. These scripts provide comprehensive job automation for deployment, monitoring, rollback, and maintenance operations.

## 📋 Table of Contents

- [Overview](#overview)
- [Scripts](#scripts)
- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Pipelines](#pipelines)
- [Troubleshooting](#troubleshooting)

## 🎯 Overview

The automation suite consists of the following components:

| Script | Purpose | Use Case |
|--------|---------|----------|
| `job-manager.sh` | Orchestration hub | Manage and coordinate all automation jobs |
| `deploy.sh` | Deployment automation | Build, push, and deploy to ECS |
| `rollback.sh` | Version rollback | Safely revert to previous versions |
| `health-check.sh` | Health monitoring | Monitor application and infrastructure health |
| `cleanup.sh` | Resource cleanup | Clean Docker images and AWS resources |

## 📦 Scripts

### 1. Job Manager (`job-manager.sh`)

Central orchestration script for managing all CI/CD jobs.

**Features:**
- Unified interface for all automation tasks
- Pipeline orchestration (deploy → health check → cleanup)
- Job logging and status tracking
- Parallel execution support
- Built-in help and documentation

**Usage:**
```bash
# View all available commands
./scripts/job-manager.sh list

# Run full deployment pipeline
./scripts/job-manager.sh full-deploy

# Check system status
./scripts/job-manager.sh status

# View logs
./scripts/job-manager.sh logs deploy
```

### 2. Deploy Script (`deploy.sh`)

Automated deployment pipeline for Docker containers to AWS ECS Fargate.

**Features:**
- Automated Docker build and tagging
- ECR push with authentication
- ECS service updates
- Deployment stability checks
- Automatic rollback on failure
- Comprehensive validation and error handling

**Usage:**
```bash
# Standard deployment
./scripts/deploy.sh production

# Dry run (preview without executing)
DRY_RUN=true ./scripts/deploy.sh

# Skip health checks
SKIP_HEALTH_CHECK=true ./scripts/deploy.sh

# Custom timeout
DEPLOYMENT_TIMEOUT=900 ./scripts/deploy.sh
```

**Required Environment Variables:**
- `AWS_REGION` - AWS region (e.g., us-east-1)
- `ECR_REPO` - ECR repository URI
- `ECS_CLUSTER` - ECS cluster name
- `ECS_SERVICE` - ECS service name

**Optional Variables:**
- `ALB_DNS_NAME` - Load balancer URL for health checks
- `DRY_RUN` - Set to 'true' for dry run
- `SKIP_HEALTH_CHECK` - Skip post-deployment health check
- `DEPLOYMENT_TIMEOUT` - Max wait time in seconds (default: 600)

### 3. Rollback Script (`rollback.sh`)

Safely rollback ECS service to previous stable versions.

**Features:**
- Interactive version selection
- Automatic previous version detection
- Rollback N versions back
- Dry run support
- Verification checks
- Backup of current state

**Usage:**
```bash
# Rollback to previous version (interactive)
./scripts/rollback.sh

# Rollback 2 versions back
./scripts/rollback.sh --steps 2

# Rollback to specific version
./scripts/rollback.sh --to arn:aws:ecs:region:account:task-definition/family:42

# Auto-confirm (for automation)
./scripts/rollback.sh --yes

# Dry run
DRY_RUN=true ./scripts/rollback.sh
```

**Options:**
- `-h, --help` - Show help
- `-d, --dry-run` - Dry run mode
- `-y, --yes` - Auto-confirm (skip prompt)
- `-s, --steps N` - Rollback N versions
- `-t, --to ARN` - Rollback to specific task definition
- `--no-wait` - Don't wait for stability

### 4. Health Check Script (`health-check.sh`)

Comprehensive health monitoring for application and infrastructure.

**Features:**
- HTTP endpoint health checks
- Response time measurement
- ECS service health monitoring
- ECS task health verification
- ALB target group health
- CloudWatch metrics checking
- Continuous monitoring mode
- Configurable thresholds and retries

**Usage:**
```bash
# Single health check
./scripts/health-check.sh

# Continuous monitoring (every 30 seconds)
CONTINUOUS=true CHECK_INTERVAL=30 ./scripts/health-check.sh

# Custom timeout and retries
MAX_RETRIES=5 TIMEOUT=15 ./scripts/health-check.sh

# Check specific endpoint
ALB_DNS_NAME=http://my-alb.amazonaws.com ./scripts/health-check.sh
```

**Checks Performed:**
1. HTTP endpoint availability and status
2. HTTP response time performance
3. ECS service running/desired task counts
4. ECS task health status
5. ECS deployment status
6. ALB target health
7. CloudWatch CPU/memory metrics

### 5. Cleanup Script (`cleanup.sh`)

Clean up Docker images, ECR repositories, and ECS resources.

**Features:**
- Local Docker image cleanup
- ECR image lifecycle management
- ECS task definition cleanup
- Configurable retention policies
- Dry run mode (default)
- Safe deletion with confirmation

**Usage:**
```bash
# Dry run (default - shows what would be deleted)
./scripts/cleanup.sh

# Clean local Docker only
DRY_RUN=false ./scripts/cleanup.sh

# Clean everything, keep last 10 images
DRY_RUN=false CLEAN_ECR=true CLEAN_ECS=true KEEP_IMAGES=10 ./scripts/cleanup.sh

# List ECR images
./scripts/cleanup.sh --list-ecr
```

**Options:**
- `-h, --help` - Show help
- `-d, --dry-run` - Dry run mode
- `-f, --force` - Force actual cleanup
- `--clean-local` - Clean local Docker
- `--clean-ecr` - Clean ECR repository
- `--clean-ecs` - Clean ECS task definitions
- `--keep N` - Keep last N images

**Safety Features:**
- Defaults to dry run mode
- Keeps last 5 images by default
- Separate flags for local/ECR/ECS cleanup

## 🚀 Quick Start

### 1. Set Environment Variables

Create a `.env` file or export variables:

```bash
# AWS Configuration
export AWS_REGION="us-east-1"
export ECR_REPO="123456789012.dkr.ecr.us-east-1.amazonaws.com/2048-app"
export ECS_CLUSTER="2048-cluster"
export ECS_SERVICE="2048-service"
export ALB_DNS_NAME="http://2048-alb-123456789.us-east-1.elb.amazonaws.com"
export TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/2048-tg/abc123"

# Optional Configuration
export DEPLOYMENT_TIMEOUT=900
export CHECK_INTERVAL=60
export KEEP_IMAGES=5
```

### 2. Run Your First Deployment

```bash
# Deploy using job manager
./scripts/job-manager.sh full-deploy

# Or deploy directly
./scripts/deploy.sh production
```

### 3. Monitor Health

```bash
# Single check
./scripts/health-check.sh

# Continuous monitoring
CONTINUOUS=true ./scripts/health-check.sh
```

## 🔧 Prerequisites

### Required Tools

- **Docker** - Container runtime
- **AWS CLI** - AWS operations
- **jq** - JSON processing
- **git** - Version control
- **curl** - HTTP requests
- **bc** - Calculations (for response time)

### Installation

```bash
# Ubuntu/Debian
apt-get update
apt-get install -y docker.io awscli jq git curl bc

# macOS
brew install docker awscli jq git curl bc

# Verify installations
docker --version
aws --version
jq --version
```

### AWS Permissions

IAM permissions required:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages",
        "ecr:BatchDeleteImage",
        "ecs:DescribeServices",
        "ecs:DescribeTasks",
        "ecs:DescribeTaskDefinition",
        "ecs:ListTasks",
        "ecs:ListTaskDefinitions",
        "ecs:UpdateService",
        "ecs:DeregisterTaskDefinition",
        "elasticloadbalancing:DescribeTargetHealth",
        "cloudwatch:GetMetricStatistics",
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## ⚙️ Configuration

### Environment Variables

#### Required for Deployment

```bash
AWS_REGION              # AWS region (e.g., us-east-1)
ECR_REPO               # ECR repository URI
ECS_CLUSTER            # ECS cluster name
ECS_SERVICE            # ECS service name
```

#### Optional for Enhanced Features

```bash
ALB_DNS_NAME           # Load balancer DNS for health checks
TARGET_GROUP_ARN       # ALB target group ARN
ECS_TASK_FAMILY        # Task definition family name
DRY_RUN                # Enable dry run mode (true/false)
DEPLOYMENT_TIMEOUT     # Deployment timeout in seconds
CHECK_INTERVAL         # Health check interval in seconds
KEEP_IMAGES            # Number of images to keep during cleanup
AUTO_CLEANUP           # Auto cleanup after deployment (true/false)
CONTINUOUS             # Enable continuous monitoring (true/false)
```

### Configuration File

Create `scripts/config.sh`:

```bash
#!/bin/bash
# Common configuration for all scripts

export AWS_REGION="us-east-1"
export ECR_REPO="123456789012.dkr.ecr.us-east-1.amazonaws.com/2048-app"
export ECS_CLUSTER="2048-cluster"
export ECS_SERVICE="2048-service"
export ALB_DNS_NAME="http://my-alb.amazonaws.com"
export TARGET_GROUP_ARN="arn:aws:elasticloadbalancing:..."
export DEPLOYMENT_TIMEOUT=900
export KEEP_IMAGES=10
```

Then source it:

```bash
source scripts/config.sh
./scripts/deploy.sh
```

## 💡 Usage Examples

### Common Workflows

#### 1. Standard Deployment

```bash
# Full deployment with health check
./scripts/job-manager.sh full-deploy

# Or step-by-step
./scripts/deploy.sh production
./scripts/health-check.sh
```

#### 2. Rollback on Issue Detection

```bash
# Manual rollback to previous version
./scripts/rollback.sh

# Automated rollback
AUTO_CONFIRM=true ./scripts/rollback.sh --steps 1
```

#### 3. Continuous Monitoring

```bash
# Start monitoring in background
CONTINUOUS=true CHECK_INTERVAL=60 ./scripts/health-check.sh &

# Check status
./scripts/job-manager.sh status
```

#### 4. Maintenance

```bash
# Dry run cleanup (see what would be deleted)
./scripts/cleanup.sh

# Actual cleanup (local only)
DRY_RUN=false ./scripts/cleanup.sh

# Full cleanup including ECR
DRY_RUN=false CLEAN_ECR=true CLEAN_ECS=true ./scripts/cleanup.sh
```

### CI/CD Integration

#### GitHub Actions

```yaml
- name: Deploy to Production
  run: |
    source scripts/config.sh
    ./scripts/deploy.sh production

- name: Health Check
  run: ./scripts/health-check.sh
```

#### Jenkins

```groovy
stage('Deploy') {
    steps {
        sh './scripts/job-manager.sh deploy'
    }
}

stage('Health Check') {
    steps {
        sh './scripts/health-check.sh'
    }
}

post {
    failure {
        sh './scripts/rollback.sh --yes'
    }
}
```

## 🔄 Pipelines

### Full Deployment Pipeline

Automated pipeline: Deploy → Health Check → (Rollback on failure)

```bash
./scripts/job-manager.sh full-deploy
```

**Steps:**
1. Validate prerequisites and environment
2. Build Docker image
3. Push to ECR
4. Update ECS service
5. Wait for deployment stability
6. Run health checks
7. Auto-rollback on failure
8. Optional cleanup

### Deploy and Monitor Pipeline

Deploy and start continuous monitoring:

```bash
./scripts/job-manager.sh deploy-monitor
```

**Steps:**
1. Deploy application
2. Wait for deployment completion
3. Start continuous health monitoring (background)

### Custom Pipeline

Create your own pipeline:

```bash
#!/bin/bash
# Custom deployment pipeline

source scripts/config.sh

# Pre-deployment
echo "Starting deployment..."
./scripts/cleanup.sh  # Optional pre-cleanup

# Deploy
if ./scripts/deploy.sh production; then
    echo "Deployment successful"
else
    echo "Deployment failed"
    exit 1
fi

# Verify
if ./scripts/health-check.sh; then
    echo "Health check passed"
    AUTO_CLEANUP=true ./scripts/cleanup.sh  # Post-deployment cleanup
else
    echo "Health check failed, rolling back"
    ./scripts/rollback.sh --yes
    exit 1
fi

echo "Pipeline completed successfully"
```

## 🐛 Troubleshooting

### Common Issues

#### 1. AWS Credentials

**Problem:** "AWS credentials are invalid or expired"

**Solution:**
```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Or use IAM role (recommended for EC2/ECS)
```

#### 2. Docker Build Failure

**Problem:** "Docker build failed"

**Solution:**
```bash
# Check Docker is running
docker ps

# Check Dockerfile exists
ls -la 2048/Dockerfile

# Try manual build
cd 2048
docker build -t test .
```

#### 3. ECS Deployment Timeout

**Problem:** "Deployment timeout reached"

**Solution:**
```bash
# Increase timeout
DEPLOYMENT_TIMEOUT=1200 ./scripts/deploy.sh

# Check ECS console for errors
aws ecs describe-services --cluster $ECS_CLUSTER --services $ECS_SERVICE
```

#### 4. Health Check Failure

**Problem:** "Health check failed after N attempts"

**Solution:**
```bash
# Check ALB is reachable
curl -I $ALB_DNS_NAME

# Check ECS tasks are running
aws ecs list-tasks --cluster $ECS_CLUSTER --service-name $ECS_SERVICE

# Check task logs in CloudWatch
```

### Debug Mode

Enable verbose logging:

```bash
# Bash debug mode
bash -x ./scripts/deploy.sh

# Verbose mode (if supported)
VERBOSE=true ./scripts/job-manager.sh deploy
```

### Log Files

All scripts create log files:

```bash
# View recent logs
ls -lht *.log

# View specific log
tail -f deployment.log

# View job manager logs
tail -f logs/job-manager.log

# View specific job logs
ls -lht logs/deploy-*.log
```

## 📊 Monitoring and Alerts

### CloudWatch Integration

Scripts check CloudWatch metrics:

```bash
# CPU and memory utilization
# Target health
# Custom application metrics
```

### Setting Up Alerts

Create CloudWatch alarms for:

- High CPU/Memory utilization
- Failed health checks
- Deployment failures
- Rollback events

## 🔒 Security

### Best Practices

1. **Never commit credentials** - Use IAM roles or environment variables
2. **Use OIDC for GitHub Actions** - Avoid long-lived AWS keys
3. **Limit IAM permissions** - Use least privilege principle
4. **Review dry run output** - Before executing destructive operations
5. **Enable CloudTrail** - Audit all AWS API calls

## 📝 Contributing

When adding new scripts:

1. Follow existing naming conventions (`*-check.sh`, `*.sh`)
2. Include comprehensive help text (`--help` flag)
3. Support dry run mode where applicable
4. Add logging functions (use color codes)
5. Handle errors gracefully
6. Update this README

## 📄 License

MIT License - See [LICENSE](../LICENSE) file

## 🤝 Support

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Review log files in `logs/` directory
3. Run scripts with `--help` flag
4. Check main project [README](../README.md)

---

**Version:** 1.0.0
**Last Updated:** November 2025
**Maintainer:** Enterprise CI/CD Platform Team
