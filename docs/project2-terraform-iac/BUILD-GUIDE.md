# Project 2: Infrastructure as Code with Terraform - Step-by-Step Build Guide

## What You Will Build

Complete AWS infrastructure for the 2048 game platform, fully managed by Terraform:

- **VPC** with public/private subnets across 2 AZs, NAT gateway, and VPC endpoints
- **ECS Fargate** cluster with blue and green services for zero-downtime deployments
- **Application Load Balancer** with dual target groups for traffic switching
- **ECR** container registry with lifecycle policies and vulnerability scanning
- **IAM** roles with least-privilege access and GitHub OIDC authentication
- **CloudWatch** logging, 6 metric alarms, and an operational dashboard
- **SNS** notifications for deployment alerts

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.5.0 installed
- An AWS account

---

## Step 1: Understand the File Structure

```
infra/
├── main.tf                 # Provider config, backend, data sources
├── variables.tf            # 25+ input variables with validation
├── outputs.tf              # 15+ outputs for CI/CD pipeline integration
├── terraform.tfvars        # Default production values
│
├── vpc.tf                  # VPC, subnets, NAT, IGW, routes, VPC endpoints
├── security-groups.tf      # ALB SG, ECS SG, VPC endpoint SG
├── ecr.tf                  # Container registry + lifecycle policy
├── iam.tf                  # 3 roles: execution, task, GitHub OIDC
├── alb.tf                  # ALB, 2 target groups, HTTP/HTTPS listeners
├── ecs.tf                  # Cluster, task def, 2 services, auto-scaling
└── cloudwatch.tf           # Log group, 6 alarms, dashboard, SNS topic
```

Each file is self-contained. All resources of one type live in one file.

---

## Step 2: Initialize and Plan

```bash
cd infra

# Initialize Terraform (downloads AWS provider)
terraform init

# Preview what will be created
terraform plan
```

Expected output: ~35 resources to create.

---

## Step 3: Understand the Resource Build Order

Terraform resolves dependencies automatically, but here's the logical order:

```
Phase 1 (no dependencies):
├── VPC + Subnets + IGW + NAT
├── ECR Repository
└── IAM Roles + OIDC Provider

Phase 2 (depends on VPC):
├── Security Groups (ALB, ECS, VPC Endpoints)
└── VPC Endpoints (ECR, Logs, S3)

Phase 3 (depends on VPC + SGs):
└── ALB + Target Groups + Listeners

Phase 4 (depends on ALB + IAM + VPC + SGs):
└── ECS Cluster + Task Definition + Blue/Green Services + Auto-scaling

Phase 5 (depends on ECS):
└── CloudWatch Log Group + Alarms + Dashboard + SNS
```

---

## Step 4: Apply the Infrastructure

```bash
# Create all resources
terraform apply

# Terraform will show the plan and ask for confirmation
# Type "yes" to proceed
```

After apply completes, Terraform outputs the values needed for the CI/CD pipeline:

```
Outputs:

alb_dns_name         = "game-2048-alb-123456789.us-east-1.elb.amazonaws.com"
alb_listener_arn     = "arn:aws:elasticloadbalancing:us-east-1:..."
alb_url              = "http://game-2048-alb-123456789.us-east-1.elb.amazonaws.com"
ecr_repository_url   = "123456789012.dkr.ecr.us-east-1.amazonaws.com/game-2048"
ecs_cluster_name     = "game-2048"
github_actions_role_arn = "arn:aws:iam::123456789012:role/game-2048-github-actions-role"
target_group_blue_arn   = "arn:aws:elasticloadbalancing:us-east-1:..."
target_group_green_arn  = "arn:aws:elasticloadbalancing:us-east-1:..."
```

---

## Step 5: Configure GitHub Secrets

Use the Terraform outputs to set GitHub repository secrets:

```bash
# Get the values
terraform output -json github_secrets_summary

# Set them in GitHub (using gh CLI)
gh secret set AWS_REGION       --body "us-east-1"
gh secret set ECR_REPO         --body "$(terraform output -raw ecr_repository_url)"
gh secret set AWS_ROLE_ARN     --body "$(terraform output -raw github_actions_role_arn)"
gh secret set TG_BLUE_ARN      --body "$(terraform output -raw target_group_blue_arn)"
gh secret set TG_GREEN_ARN     --body "$(terraform output -raw target_group_green_arn)"
gh secret set ALB_LISTENER_ARN --body "$(terraform output -raw alb_listener_arn)"
```

Now the CI/CD pipeline from Project 1 can deploy to this infrastructure.

---

## Step 6: Understanding Key Design Decisions

### Why `lifecycle { ignore_changes }` on ECS?

```hcl
resource "aws_ecs_service" "blue" {
  ...
  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}
```

The CI/CD pipeline manages the container image (task definition) and auto-scaling manages the task count. Without `ignore_changes`, every `terraform apply` would revert these to the Terraform-defined values, undoing deployments and scaling decisions.

### Why `lifecycle { ignore_changes }` on the ALB listener?

```hcl
resource "aws_lb_listener" "http" {
  ...
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
  lifecycle {
    ignore_changes = [default_action]
  }
}
```

The CI/CD pipeline switches the listener between blue and green target groups during deployment. Terraform creates the listener pointing to blue initially, then the pipeline takes over. Without `ignore_changes`, `terraform apply` would switch traffic back to blue.

### Why VPC Endpoints?

ECS Fargate tasks in private subnets need to reach ECR (to pull images) and CloudWatch (to write logs). Without VPC endpoints, this traffic goes through the NAT gateway, which costs money per GB. VPC interface endpoints route this traffic through AWS PrivateLink instead.

### Why a single NAT gateway?

Production-critical workloads should use one NAT gateway per AZ for fault tolerance. For cost savings in non-production or demonstration environments, a single NAT gateway is sufficient. Controlled by the `single_nat_gateway` variable.

---

## Step 7: Multi-Environment Support

Create environment-specific variable files:

```bash
mkdir -p infra/environments
```

**`infra/environments/dev.tfvars`**:
```hcl
project_name   = "game-2048"
environment    = "dev"
desired_count  = 1
min_capacity   = 1
max_capacity   = 3
task_cpu       = 256
task_memory    = 512
single_nat_gateway   = true
enable_vpc_endpoints = false   # Save cost in dev
log_retention_days   = 7
```

**`infra/environments/prod.tfvars`**:
```hcl
project_name   = "game-2048"
environment    = "prod"
desired_count  = 2
min_capacity   = 2
max_capacity   = 10
task_cpu       = 256
task_memory    = 512
single_nat_gateway   = false  # HA: one NAT per AZ
enable_vpc_endpoints = true
log_retention_days   = 30
```

Deploy per environment:
```bash
terraform apply -var-file="environments/dev.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

---

## Step 8: Enable Remote State (Production)

Uncomment the backend block in `main.tf` and create the S3 bucket + DynamoDB table:

```bash
# Create state bucket
aws s3api create-bucket \
  --bucket game-2048-terraform-state \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket game-2048-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket game-2048-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Create lock table
aws dynamodb create-table \
  --table-name game-2048-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Re-initialize Terraform with the new backend
terraform init -migrate-state
```

---

## Step 9: Verify the Deployment

```bash
# Check all resources
terraform state list

# Access the application
ALB_URL=$(terraform output -raw alb_url)
curl $ALB_URL

# View the CloudWatch dashboard
terraform output cloudwatch_dashboard_url
```

---

## Step 10: Tear Down (when done)

```bash
# Destroy all resources
terraform destroy

# Type "yes" to confirm
```

In production, `enable_deletion_protection = true` on the ALB prevents accidental destruction.

---

## Resource Cost Estimate

| Resource | Monthly Cost |
|----------|-------------|
| ECS Fargate (4 tasks, 0.25 vCPU, 512MB) | ~$26 |
| ALB | ~$16 |
| NAT Gateway (1x) | ~$32 |
| VPC Endpoints (3 interface) | ~$22 |
| ECR Storage | ~$1 |
| CloudWatch Logs | ~$5 |
| **Total** | **~$102/month** |

Cost savings: set `enable_vpc_endpoints = false` and `single_nat_gateway = true` to reduce to ~$48/month for non-production.

---

*Last Updated: 2026-02-03*
