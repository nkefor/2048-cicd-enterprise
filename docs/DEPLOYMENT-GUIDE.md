# Deployment Guide - 2048 CI/CD Enterprise

## Quick Start

### Prerequisites

- AWS Account with administrator access
- GitHub repository with Actions enabled
- Terraform >= 1.0 installed locally
- AWS CLI configured

### 1. Initial Infrastructure Setup (One-Time)

```bash
# 1. Create S3 bucket for Terraform state
aws s3 mb s3://terraform-state-2048-cicd-prod --region us-east-1

# 2. Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state-2048-cicd-prod \
  --versioning-configuration Status=Enabled

# 3. Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# 4. Deploy infrastructure
cd infra
terraform init -backend-config=environments/prod/backend.hcl
terraform plan -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars

# 5. Save outputs
terraform output -json > outputs.json
```

### 2. Configure GitHub Secrets

Navigate to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_ROLE_ARN` | IAM role for deployments | `arn:aws:iam::123456789012:role/GitHubActionsRole` |
| `AWS_TERRAFORM_ROLE_ARN` | IAM role for Terraform | `arn:aws:iam::123456789012:role/TerraformRole` |
| `ECR_REPO` | ECR repository URL | Get from Terraform output |
| `STAGING_URL` | Staging environment URL | Get from Terraform output |
| `PROD_URL` | Production environment URL | Get from Terraform output |

### 3. Deploy Application

```bash
# Option 1: Push to main branch (automatic)
git add .
git commit -m "feat: Initial deployment"
git push origin main

# Option 2: Manual trigger via GitHub Actions
# Go to Actions → Blue-Green Deployment → Run workflow
```

### 4. Verify Deployment

```bash
# Get application URL from Terraform
cd infra
terraform output application_url

# Test the endpoint
curl $(terraform output -raw application_url)

# Check ECS service
aws ecs describe-services \
  --cluster game-2048-prod \
  --services game-2048-prod
```

## Deployment Workflows

### Standard Deployment (Blue-Green)

1. **Developer commits code**:
   ```bash
   git add 2048/www/index.html
   git commit -m "feat: Update game colors"
   git push origin main
   ```

2. **GitHub Actions automatically**:
   - Builds Docker image
   - Runs security scans
   - Runs parallel tests
   - Deploys to staging (blue-green)
   - Runs E2E tests on staging
   - Awaits approval for production
   - Deploys to production (blue-green)

3. **Zero downtime**: Traffic shifts from blue to green automatically

**Total Time**: ~6 minutes to production

### Rollback Deployment

#### Automatic Rollback

Triggers automatically on:
- Health check failures
- CloudWatch alarm triggers
- High error rates (>10%)

#### Manual Rollback

```bash
# Option 1: Redeploy previous image
aws ecs update-service \
  --cluster game-2048-prod \
  --service game-2048-prod \
  --task-definition game-2048-prod:PREVIOUS_REVISION \
  --force-new-deployment

# Option 2: Stop current deployment
DEPLOYMENT_ID=$(aws deploy list-deployments \
  --application-name game-2048-prod \
  --query 'deployments[0]' --output text)

aws deploy stop-deployment \
  --deployment-id $DEPLOYMENT_ID \
  --auto-rollback-enabled

# Option 3: Revert git commit and push
git revert HEAD
git push origin main
```

### Infrastructure Updates

```bash
# 1. Update Terraform files
vim infra/environments/prod/terraform.tfvars

# 2. Plan changes locally
cd infra
terraform init -backend-config=environments/prod/backend.hcl
terraform plan -var-file=environments/prod/terraform.tfvars

# 3. Apply via GitHub Actions
git add infra/
git commit -m "infra: Update ECS task size"
git push origin main

# GitHub Actions will:
# - Run terraform plan
# - Wait for approval
# - Apply changes
```

## Environment-Specific Deployments

### Development

**Purpose**: Rapid iteration and testing

**Configuration**:
- Rolling deployments (faster)
- 1 task minimum
- Minimal resources (0.25 vCPU, 512 MB)
- Auto-scaling: 1-2 tasks

**Deploy**:
```bash
cd infra
terraform workspace select dev  # or use -var-file
terraform apply -var-file=environments/dev/terraform.tfvars -auto-approve
```

### Staging

**Purpose**: Pre-production validation

**Configuration**:
- Blue-green deployments
- 1-2 tasks minimum
- Production-like setup
- Auto-scaling: 1-4 tasks

**Deploy**:
```bash
# Automatic on main branch push
git push origin main

# Or manual via GitHub Actions workflow_dispatch
```

### Production

**Purpose**: Live user traffic

**Configuration**:
- Blue-green deployments
- 2-3 tasks minimum
- High availability (multi-AZ)
- Auto-scaling: 2-10 tasks
- Requires approval

**Deploy**:
```bash
# Push to main triggers staging deployment
git push origin main

# Approve production deployment in GitHub Actions UI
# Navigate to Actions → Blue-Green Deployment → Approve
```

## Blue-Green Deployment Details

### Traffic Shift Strategy

**Production**: Canary deployment
```
Blue (100%) ─┐
             ├─> All-at-Once cutover
Green (0%)  ─┘
```

**Traffic Flow**:
1. **T+0**: Green deployed, 0% traffic
2. **T+1**: Health checks pass
3. **T+2**: Traffic shifts to green (100%)
4. **T+7**: Blue tasks terminated

### Target Groups

- **Blue**: Currently serving production traffic
- **Green**: New version for testing/deployment

**ALB Configuration**:
```
Listener (Port 80/443)
├─> Blue Target Group (Weight: 100)
└─> Green Target Group (Weight: 0)

After deployment:
├─> Blue Target Group (Weight: 0)
└─> Green Target Group (Weight: 100)
```

### Testing Green Before Cutover

```bash
# Send test traffic to green environment
curl -H "X-Test-Traffic: true" https://your-alb-endpoint.com

# Or use AWS CLI to get green task IPs
aws ecs list-tasks \
  --cluster game-2048-prod \
  --service-name game-2048-prod \
  --query 'taskArns' \
  --output text
```

## Monitoring Deployments

### Real-Time Monitoring

```bash
# Watch ECS service events
aws ecs describe-services \
  --cluster game-2048-prod \
  --services game-2048-prod \
  --query 'services[0].events[0:10]'

# Watch CodeDeploy deployment
aws deploy get-deployment \
  --deployment-id d-XXXXXXXXX

# Stream CloudWatch logs
aws logs tail /ecs/game-2048-prod --follow
```

### CloudWatch Dashboards

Access via AWS Console:
1. CloudWatch → Dashboards
2. Select `game-2048-prod-dashboard`
3. View metrics:
   - Request count
   - Response time
   - Task health
   - CPU/Memory utilization

### GitHub Actions Logs

1. Navigate to **Actions** tab
2. Select workflow run
3. Expand job steps to see detailed logs

## Troubleshooting

### Deployment Stuck at "Waiting for deployment"

**Cause**: Health checks failing

**Solution**:
```bash
# Check task health
aws ecs describe-tasks \
  --cluster game-2048-prod \
  --tasks $(aws ecs list-tasks --cluster game-2048-prod --query 'taskArns[0]' --output text)

# Check logs
aws logs tail /ecs/game-2048-prod --follow

# Common issues:
# - Container not starting: Check Dockerfile
# - Health check failing: Check NGINX config
# - Port not exposed: Verify security groups
```

### Image Pull Errors

**Cause**: ECR authentication or image not found

**Solution**:
```bash
# Verify image exists
aws ecr describe-images \
  --repository-name game-2048-prod \
  --image-ids imageTag=latest

# Check IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query 'Arn' --output text) \
  --action-names ecr:GetAuthorizationToken ecr:BatchGetImage
```

### High Memory Usage

**Cause**: Task memory insufficient

**Solution**:
```bash
# Update task size in Terraform
vim infra/environments/prod/terraform.tfvars
# Change: ecs_task_memory = 1024 → 2048

# Apply changes
cd infra
terraform apply -var-file=environments/prod/terraform.tfvars
```

### Failed Health Checks

**Cause**: Application not responding on health check endpoint

**Solution**:
```bash
# Test locally
docker build -t test ./2048
docker run -p 8080:80 test
curl http://localhost:8080/

# Check container logs
docker logs $(docker ps -q -f "ancestor=test")

# Verify NGINX is running
docker exec $(docker ps -q -f "ancestor=test") ps aux
```

## Advanced Scenarios

### Multi-Region Deployment

```bash
# Deploy to us-east-1
export AWS_REGION=us-east-1
terraform apply -var-file=environments/prod/terraform.tfvars

# Deploy to us-west-2
export AWS_REGION=us-west-2
terraform apply -var-file=environments/prod/terraform.tfvars -var="aws_region=us-west-2"
```

### Custom Deployment Strategy

Edit `infra/modules/ecs/main.tf`:

```hcl
# Change deployment configuration
deployment_configuration {
  maximum_percent         = 200
  minimum_healthy_percent = 100

  # Custom deployment circuit breaker
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
```

### Database Migrations (Future)

```yaml
# Add to deploy-bluegreen.yaml before deployment
- name: Run database migrations
  run: |
    aws ecs run-task \
      --cluster game-2048-prod \
      --task-definition migration-task \
      --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx]}"
```

## Security Best Practices

### Secrets Management

**Never commit**:
- AWS credentials
- API keys
- Database passwords
- SSL certificates

**Use instead**:
- GitHub Secrets for CI/CD
- AWS Secrets Manager for runtime
- AWS Systems Manager Parameter Store
- AWS IAM roles (no static credentials)

### Image Scanning

Automatic scans on every build:
```yaml
- name: Scan image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ secrets.ECR_REPO }}:${{ github.sha }}
    severity: 'CRITICAL,HIGH'
    exit-code: '1'  # Fail build on vulnerabilities
```

### Network Security

- ECS tasks in private subnets
- ALB in public subnets
- Security groups: least-privilege
- VPC Flow Logs enabled

## Cost Management

### Monitor Costs

```bash
# Get current month costs
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://cost-filter.json
```

### Optimize Costs

1. **Right-size tasks**: Start small, scale up
2. **Use Fargate Spot**: 70% savings (non-prod)
3. **Auto-scaling**: Scale to zero during off-hours
4. **Single NAT Gateway**: Dev/staging environments
5. **Log retention**: 7 days (dev), 30 days (prod)

### Cost Breakdown

| Service | Dev | Staging | Prod |
|---------|-----|---------|------|
| ECS Fargate | $15 | $30 | $60 |
| NAT Gateway | $32 | $32 | $96 |
| ALB | $16 | $16 | $16 |
| CloudWatch | $2 | $3 | $5 |
| ECR | $1 | $1 | $2 |
| **Total/month** | **$66** | **$82** | **$179** |

## Maintenance

### Regular Tasks

**Daily**:
- Monitor CloudWatch dashboards
- Review deployment logs
- Check error rates

**Weekly**:
- Review cost reports
- Update dependencies
- Run security scans

**Monthly**:
- Review and optimize auto-scaling
- Update Terraform providers
- Rotate credentials
- Review and clean up old images

### Updates

**Terraform Providers**:
```bash
cd infra
terraform init -upgrade
terraform plan
terraform apply
```

**GitHub Actions**:
- Dependabot automatically updates actions
- Review and merge Dependabot PRs

**Docker Base Images**:
```dockerfile
# Update in 2048/Dockerfile
FROM nginx:1.27-alpine  # → nginx:1.28-alpine
```

## Support

### Documentation

- [Infrastructure README](../infra/README.md)
- [CI/CD Modernization Guide](./CI-CD-MODERNIZATION.md)
- [Main README](../README.md)

### Useful Commands

```bash
# Get all Terraform outputs
cd infra && terraform output

# List all ECS tasks
aws ecs list-tasks --cluster game-2048-prod

# Describe ECS service
aws ecs describe-services --cluster game-2048-prod --services game-2048-prod

# View recent deployments
aws deploy list-deployments --application-name game-2048-prod

# Tail CloudWatch logs
aws logs tail /ecs/game-2048-prod --follow --since 5m

# Check ALB health
aws elbv2 describe-target-health --target-group-arn <arn>
```

---

**Last Updated**: 2025-01-13
**Version**: 1.0.0
