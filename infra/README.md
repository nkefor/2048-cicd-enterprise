# Infrastructure as Code - Terraform

This directory contains Terraform infrastructure code for deploying the 2048 game application to AWS ECS Fargate with Blue-Green deployment capabilities.

## Architecture Overview

The infrastructure consists of:

- **VPC**: Multi-AZ Virtual Private Cloud with public and private subnets
- **ALB**: Application Load Balancer with Blue-Green target groups
- **ECS Fargate**: Serverless container orchestration
- **ECR**: Container image registry with vulnerability scanning
- **CodeDeploy**: Blue-Green deployment automation
- **CloudWatch**: Logging and monitoring
- **Auto Scaling**: Dynamic scaling based on CPU and memory utilization

## Directory Structure

```
infra/
├── main.tf                    # Root module configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── README.md                  # This file
│
├── modules/                   # Reusable Terraform modules
│   ├── vpc/                   # VPC with public/private subnets
│   ├── ecr/                   # Container registry
│   ├── alb/                   # Application Load Balancer
│   └── ecs/                   # ECS Fargate with CodeDeploy
│
└── environments/              # Environment-specific configurations
    ├── dev/                   # Development environment
    ├── staging/               # Staging environment
    └── prod/                  # Production environment
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed
3. **AWS CLI** configured with credentials
4. **S3 Buckets** for Terraform state (one per environment)
5. **DynamoDB Tables** for state locking (one per environment)

## State Backend Setup

Before deploying infrastructure, create the S3 buckets and DynamoDB tables for Terraform state:

```bash
# Production
aws s3 mb s3://terraform-state-2048-cicd-prod --region us-east-1
aws dynamodb create-table \
  --table-name terraform-state-lock-prod \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Staging
aws s3 mb s3://terraform-state-2048-cicd-staging --region us-east-1
aws dynamodb create-table \
  --table-name terraform-state-lock-staging \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1

# Development
aws s3 mb s3://terraform-state-2048-cicd-dev --region us-east-1
aws dynamodb create-table \
  --table-name terraform-state-lock-dev \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1
```

## Deployment

### Initialize Terraform

```bash
cd infra

# For production
terraform init -backend-config=environments/prod/backend.hcl

# For staging
terraform init -backend-config=environments/staging/backend.hcl

# For development
terraform init -backend-config=environments/dev/backend.hcl
```

### Plan Infrastructure

```bash
# Production
terraform plan -var-file=environments/prod/terraform.tfvars

# Staging
terraform plan -var-file=environments/staging/terraform.tfvars

# Development
terraform plan -var-file=environments/dev/terraform.tfvars
```

### Apply Infrastructure

```bash
# Production (with approval)
terraform apply -var-file=environments/prod/terraform.tfvars

# Staging
terraform apply -var-file=environments/staging/terraform.tfvars -auto-approve

# Development
terraform apply -var-file=environments/dev/terraform.tfvars -auto-approve
```

### Destroy Infrastructure

```bash
# WARNING: This will destroy all resources!
terraform destroy -var-file=environments/[ENV]/terraform.tfvars
```

## Blue-Green Deployment

The infrastructure supports blue-green deployments via AWS CodeDeploy:

### How It Works

1. **Blue Environment**: Currently serving production traffic
2. **Green Environment**: New version deployed to green target group
3. **Testing**: Validate green environment (optional manual approval)
4. **Traffic Shift**: CodeDeploy shifts traffic from blue to green
5. **Termination**: Old (blue) tasks terminated after successful deployment

### Deployment Process

```bash
# Create new task definition with updated image
aws ecs register-task-definition \
  --family game-2048-prod \
  --cli-input-json file://task-definition.json

# Create CodeDeploy deployment
aws deploy create-deployment \
  --application-name game-2048-prod \
  --deployment-group-name game-2048-prod-deployment-group \
  --revision revisionType=AppSpecContent,appSpecContent={content='{...}'}
```

The GitHub Actions workflow automates this process.

## Outputs

After applying Terraform, you'll get important outputs:

```hcl
application_url              # URL to access the application
ecr_repository_url          # ECR repository for Docker images
ecs_cluster_name            # ECS cluster name
ecs_service_name            # ECS service name
codedeploy_app_name         # CodeDeploy application name
alb_dns_name                # Load balancer DNS name
```

## Environment Differences

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| Task Size | 0.25 vCPU, 512 MB | 0.25 vCPU, 512 MB | 0.5 vCPU, 1 GB |
| Desired Tasks | 1 | 2 | 3 |
| Auto Scaling | 1-2 | 1-4 | 2-10 |
| NAT Gateways | 1 | 1 | 3 (HA) |
| Deployment | Rolling | Blue-Green | Blue-Green |
| ALB Protection | No | No | Yes |
| Log Retention | 7 days | 14 days | 30 days |
| ECR Scanning | No | Yes | Yes |

## Cost Optimization

### Development Environment
- Single NAT Gateway (~$32/month)
- Minimal task size (0.25 vCPU, 512 MB)
- 1 task most of the time
- 7-day log retention

**Estimated Monthly Cost**: ~$45-60

### Staging Environment
- Single NAT Gateway (~$32/month)
- Small task size (0.25 vCPU, 512 MB)
- 1-2 tasks
- Blue-Green deployment enabled

**Estimated Monthly Cost**: ~$60-80

### Production Environment
- 3 NAT Gateways for HA (~$96/month)
- Medium task size (0.5 vCPU, 1 GB)
- 2-10 tasks with auto-scaling
- Blue-Green deployment enabled
- ALB deletion protection
- 30-day log retention

**Estimated Monthly Cost**: ~$150-300 (depending on traffic)

## Security Features

- **VPC Isolation**: Private subnets for ECS tasks
- **Security Groups**: Least-privilege network access
- **IAM Roles**: Task-specific permissions
- **ECR Scanning**: Automated vulnerability detection
- **Encryption**: At-rest encryption for ECR images
- **VPC Flow Logs**: Network traffic monitoring
- **CloudWatch Logs**: Centralized logging

## Monitoring and Alarms

The infrastructure includes CloudWatch alarms for:

- High CPU utilization (>85%)
- High memory utilization (>85%)
- Unhealthy target hosts
- High ALB response time (>1s)

## Troubleshooting

### State Lock Issues

If state is locked:
```bash
terraform force-unlock <LOCK_ID>
```

### Plan Failures

Check AWS credentials and permissions:
```bash
aws sts get-caller-identity
```

### Deployment Failures

View ECS service events:
```bash
aws ecs describe-services \
  --cluster game-2048-prod \
  --services game-2048-prod
```

### Network Issues

Verify security groups and route tables in AWS Console.

## CI/CD Integration

The infrastructure is deployed via GitHub Actions workflow (`.github/workflows/infrastructure.yaml`).

## Cleanup

To avoid ongoing charges, destroy resources when not needed:

```bash
terraform destroy -var-file=environments/dev/terraform.tfvars
```

## Support

For issues or questions:
- Check Terraform logs: `TF_LOG=DEBUG terraform apply ...`
- Review AWS CloudWatch logs
- Consult AWS documentation

## License

MIT
