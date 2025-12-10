# Claude Assistant Guide - Enterprise CI/CD Platform

This document provides context and guidance for AI assistants working with this Enterprise CI/CD pipeline project.

## Project Overview

**Name**: Enterprise CI/CD Platform for Containerized Web Applications
**Type**: Production-grade infrastructure automation and deployment pipeline
**Tech Stack**: Docker, AWS ECS Fargate, Terraform, GitHub Actions, NGINX
**Status**: Production-ready

This is a complete CI/CD solution that automates building, testing, and deploying containerized applications to AWS serverless infrastructure with significant cost savings and deployment time reduction.

## Repository Structure

```
2048-cicd-enterprise/
├── 2048/                          # Application code
│   ├── Dockerfile                 # Container definition for the web app
│   └── www/                       # Static web application files
├── infra/                         # Infrastructure-as-Code (Terraform)
│   ├── main.tf                    # Main Terraform configuration
│   ├── variables.tf               # Input variables and defaults
│   ├── outputs.tf                 # Output values (ALB URL, etc.)
│   ├── vpc.tf                     # VPC, subnets, NAT gateway
│   ├── ecr.tf                     # Container registry
│   ├── ecs.tf                     # ECS cluster, task definitions, services
│   ├── alb.tf                     # Application Load Balancer
│   ├── iam.tf                     # IAM roles and policies
│   ├── cloudwatch.tf              # Monitoring, logging, alarms
│   └── security-groups.tf         # Network security rules
├── .github/workflows/
│   └── deploy.yaml                # CI/CD pipeline (build, scan, deploy)
├── scripts/
│   ├── deploy.sh                  # Deployment automation helper
│   └── cleanup.sh                 # Resource cleanup script
├── docs/                          # Documentation
│   ├── ENTERPRISE-VALUE.md        # ROI analysis and case studies
│   ├── DEPLOYMENT-GUIDE.md        # Step-by-step deployment
│   └── TROUBLESHOOTING.md         # Problem resolution
└── README.md                      # Project documentation
```

## Key Components

### 1. Application Layer (`2048/`)
- **Dockerfile**: Multi-stage build using NGINX Alpine base
- **www/**: Static web application (currently 2048 game as demo)
- **Purpose**: Demonstrates containerized application deployment

### 2. Infrastructure Layer (`infra/`)
- **Terraform modules**: Declarative AWS infrastructure
- **Resources managed**: VPC, ECS Fargate, ALB, ECR, IAM, CloudWatch
- **State management**: Remote state in S3 with DynamoDB locking (optional)

### 3. CI/CD Pipeline (`.github/workflows/`)
- **Trigger**: Push to main branch or manual workflow dispatch
- **Stages**: Build → Security Scan → Push to ECR → Deploy to ECS
- **Authentication**: OIDC (no AWS credentials in GitHub)

## Development Workflows

### Making Infrastructure Changes

1. **Modify Terraform files** in `infra/` directory
2. **Test locally**:
   ```bash
   cd infra
   terraform fmt         # Format files
   terraform validate    # Validate syntax
   terraform plan        # Preview changes
   ```
3. **Apply changes**:
   ```bash
   terraform apply
   ```

### Making Application Changes

1. **Modify files** in `2048/www/` or `2048/Dockerfile`
2. **Test locally**:
   ```bash
   docker build -t 2048-app:test 2048/
   docker run -p 8080:80 2048-app:test
   # Visit http://localhost:8080
   ```
3. **Commit and push** - CI/CD pipeline handles deployment automatically

### Updating CI/CD Pipeline

1. **Modify** `.github/workflows/deploy.yaml`
2. **Test workflow** using manual dispatch with test parameters
3. **Monitor** GitHub Actions tab for results

## Important Files to Review Before Changes

### Infrastructure Changes
- `infra/variables.tf` - Check variable defaults and constraints
- `infra/ecs.tf` - Task definitions, container specs, scaling config
- `infra/security-groups.tf` - Network security rules

### Application Changes
- `2048/Dockerfile` - Build process, exposed ports, health checks
- `.github/workflows/deploy.yaml` - Build and deployment process

### Documentation Changes
- `README.md` - Main project documentation
- `docs/DEPLOYMENT-GUIDE.md` - Setup instructions
- `ENTERPRISE-VALUE.md` - ROI and business value

## Common Tasks

### Deploy Infrastructure from Scratch
```bash
cd infra
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Update ECS Service (Force New Deployment)
```bash
aws ecs update-service \
  --cluster 2048-cluster \
  --service 2048-service \
  --force-new-deployment
```

### View Container Logs
```bash
aws logs tail /ecs/2048-app --follow
```

### Check Service Status
```bash
aws ecs describe-services \
  --cluster 2048-cluster \
  --services 2048-service
```

### Destroy All Resources
```bash
cd infra
terraform destroy -auto-approve
```

## Git Branch Strategy

- **Branch**: `claude/update-claude-md-01U3pMyd9U7tJraAVPeZi4kD`
- **All development** should happen on this branch
- **Commits** should be descriptive and follow conventional commit format
- **Push** using: `git push -u origin claude/update-claude-md-01U3pMyd9U7tJraAVPeZi4kD`

## Environment Variables and Secrets

### Required GitHub Secrets
- `AWS_REGION` - AWS region (e.g., us-east-1)
- `AWS_ROLE_ARN` - IAM role ARN for OIDC authentication
- `ECR_REPOSITORY` - ECR repository name
- `ECS_CLUSTER` - ECS cluster name
- `ECS_SERVICE` - ECS service name
- `CONTAINER_NAME` - Container name in task definition

### Terraform Variables
- `aws_region` - AWS region for deployment
- `app_name` - Application name (default: 2048-app)
- `environment` - Environment (default: production)
- `container_cpu` - Fargate CPU units (default: 512)
- `container_memory` - Fargate memory MB (default: 1024)

## Security Considerations

1. **Never commit AWS credentials** to the repository
2. **Use OIDC authentication** for GitHub Actions
3. **Scan container images** for vulnerabilities before deployment
4. **Follow least-privilege principle** for IAM roles
5. **Enable VPC Flow Logs** for network monitoring
6. **Use private subnets** for containers
7. **Implement WAF rules** for production deployments

## Testing

### Local Testing
```bash
# Build container
docker build -t 2048-app:test 2048/

# Run container
docker run -p 8080:80 2048-app:test

# Test in browser
open http://localhost:8080
```

### Infrastructure Testing
```bash
# Validate Terraform syntax
terraform validate

# Check formatting
terraform fmt -check

# Security scanning (optional)
tfsec infra/
```

### Pipeline Testing
- Use **manual workflow dispatch** in GitHub Actions
- Monitor CloudWatch logs for deployment issues
- Check ECS service events for errors

## Troubleshooting Guide

### Deployment Failures
1. Check GitHub Actions logs for build errors
2. Review CloudWatch logs: `/ecs/2048-app`
3. Verify task definition in ECS console
4. Check security group rules allow ALB → Container traffic

### Container Health Check Failures
1. Verify health check path in `infra/ecs.tf`
2. Check container logs for application errors
3. Ensure NGINX is serving content on port 80

### Terraform State Issues
1. Check S3 bucket for state file (if using remote state)
2. Verify DynamoDB lock table (if configured)
3. Use `terraform state list` to view resources

### High Costs
1. Review Fargate task count and sizing
2. Check ALB data processing charges
3. Review CloudWatch logs retention period
4. Implement auto-scaling policies

## Best Practices for AI Assistants

### When Making Changes

1. **Always read files before modifying** - Never assume file structure
2. **Test infrastructure changes** with `terraform plan` first
3. **Update documentation** when changing functionality
4. **Follow existing code patterns** and naming conventions
5. **Use descriptive commit messages** following conventional commits

### When Answering Questions

1. **Reference specific files and line numbers** when explaining code
2. **Provide cost implications** for infrastructure changes
3. **Consider security impact** of proposed changes
4. **Check AWS service limits** when scaling resources
5. **Link to official documentation** for complex topics

### When Debugging

1. **Start with CloudWatch logs** for application issues
2. **Check GitHub Actions logs** for CI/CD problems
3. **Review Terraform state** for infrastructure drift
4. **Examine security groups** for connectivity issues
5. **Verify IAM permissions** for access problems

## Useful AWS CLI Commands

```bash
# List ECS tasks
aws ecs list-tasks --cluster 2048-cluster

# Describe running tasks
aws ecs describe-tasks --cluster 2048-cluster --tasks <task-arn>

# View recent logs
aws logs tail /ecs/2048-app --since 1h

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# List ECR images
aws ecr list-images --repository-name 2048-app

# Get service status
aws ecs describe-services --cluster 2048-cluster --services 2048-service
```

## Important Notes

1. **This is a production-ready platform** - Changes should be tested thoroughly
2. **Costs can scale quickly** - Monitor AWS billing dashboard regularly
3. **Terraform state is critical** - Never manually modify resources managed by Terraform
4. **OIDC is preferred** - Avoid using IAM user credentials for CI/CD
5. **Multi-region deployment** requires modifications to VPC and ALB setup

## Resources and Documentation

- **Internal Docs**: `docs/` directory
- **AWS ECS**: https://docs.aws.amazon.com/ecs/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/
- **GitHub Actions**: https://docs.github.com/en/actions
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices/

## Project Metrics

- **Deployment Time**: ~6-9 minutes (commit to production)
- **Infrastructure Setup**: ~15 minutes (cold start)
- **Monthly AWS Costs**: ~$63 (baseline production config)
- **Cost Savings vs EC2**: ~20% + zero operational overhead
- **Target Uptime**: 99.95%+

## Contact and Support

For questions about this project:
1. Review documentation in `docs/` directory
2. Check `TROUBLESHOOTING.md` for common issues
3. Review GitHub Issues for similar problems
4. Consult AWS documentation for service-specific questions

---

**Last Updated**: 2025-12-10
**Maintained By**: Development Team
**Status**: Active Development
