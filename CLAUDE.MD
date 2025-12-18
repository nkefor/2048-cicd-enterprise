# CLAUDE.MD - Project Guide

## Project Overview

**2048 CI/CD Enterprise** is a production-grade CI/CD platform demonstrating automated build, test, and deployment of containerized applications on AWS serverless infrastructure. The project showcases enterprise DevOps practices with Infrastructure-as-Code (Terraform), containerization (Docker), and automated deployment pipelines (GitHub Actions).

### Key Technologies
- **Application**: 2048 game (static web app)
- **Container Runtime**: Docker + AWS ECS Fargate (serverless containers)
- **Infrastructure**: Terraform (Infrastructure-as-Code)
- **CI/CD**: GitHub Actions
- **Cloud Provider**: AWS (ECR, ECS, ALB, CloudWatch)
- **Authentication**: AWS OIDC (no long-lived credentials)

## Project Structure

```
2048-cicd-enterprise/
├── 2048/                          # Application code
│   ├── Dockerfile                 # Multi-stage container build
│   └── www/                       # Static web application files
├── infra/                         # Terraform infrastructure (NOT YET COMMITTED)
│   ├── main.tf                    # Main configuration
│   ├── vpc.tf                     # VPC and networking
│   ├── ecr.tf                     # Container registry
│   ├── ecs.tf                     # ECS cluster and service
│   ├── alb.tf                     # Application Load Balancer
│   ├── iam.tf                     # IAM roles and policies
│   ├── cloudwatch.tf              # Monitoring and logging
│   └── security-groups.tf         # Network security
├── .github/
│   └── workflows/
│       └── deploy.yaml            # CI/CD pipeline definition
├── docs/                          # Documentation (NOT YET COMMITTED)
├── scripts/                       # Automation scripts (NOT YET COMMITTED)
├── README.md                      # Comprehensive project documentation
├── ENTERPRISE-VALUE.md            # ROI analysis and business value
├── LICENSE                        # MIT License
└── CLAUDE.MD                      # This file
```

## Architecture

### Deployment Flow
1. **Developer pushes code** → GitHub repository
2. **GitHub Actions triggered** → Automated CI/CD pipeline starts
3. **Build stage** → Docker image built from `2048/Dockerfile`
4. **Security scan** → Trivy scans for vulnerabilities (if configured)
5. **Push to ECR** → Image tagged with git SHA and pushed to Amazon ECR
6. **Deploy to ECS** → ECS service updated with new image
7. **Health checks** → AWS verifies deployment success
8. **Traffic migration** → Zero-downtime deployment complete

### AWS Resources (Managed by Terraform)
- **VPC**: Custom VPC with public/private subnets across multiple AZs
- **ECR**: Private Docker registry for container images
- **ECS Fargate**: Serverless container orchestration
- **ALB**: Application Load Balancer with HTTPS support
- **CloudWatch**: Centralized logging and monitoring
- **IAM**: Least-privilege roles for ECS tasks and GitHub Actions

## Key Files

### Application Files
- **`2048/Dockerfile`**: Multi-stage Docker build using NGINX Alpine
  - Stage 1: Build stage (if needed)
  - Stage 2: Production image with NGINX
  - Optimized for size and security

### Infrastructure Files (infra/)
- **`main.tf`**: Main Terraform configuration with provider settings
- **`vpc.tf`**: Network infrastructure (VPC, subnets, IGW, NAT)
- **`ecs.tf`**: ECS cluster, task definitions, service configuration
- **`alb.tf`**: Load balancer, target groups, listeners
- **`iam.tf`**: IAM roles for ECS tasks and GitHub OIDC
- **`security-groups.tf`**: Network security rules

### CI/CD Files
- **`.github/workflows/deploy.yaml`**: GitHub Actions pipeline
  - Triggers on push to `main` branch
  - Builds Docker image
  - Pushes to ECR
  - Deploys to ECS Fargate
  - Waits for deployment stability

## Development Workflow

### Making Changes to the Application

1. **Create feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes** to files in `2048/www/` or `2048/Dockerfile`

3. **Test locally** (optional):
   ```bash
   cd 2048
   docker build -t 2048-game:local .
   docker run -p 8080:80 2048-game:local
   # Visit http://localhost:8080
   ```

4. **Commit and push**:
   ```bash
   git add .
   git commit -m "feat: descriptive message"
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request** → Merge to main → Auto-deployment triggers

### Making Infrastructure Changes

1. **Edit Terraform files** in `infra/` directory
2. **Validate changes**:
   ```bash
   cd infra
   terraform fmt      # Format code
   terraform validate # Validate syntax
   terraform plan     # Preview changes
   ```

3. **Apply changes**:
   ```bash
   terraform apply
   ```

4. **Commit infrastructure changes**:
   ```bash
   git add infra/
   git commit -m "infra: description of changes"
   git push
   ```

## Common Tasks

### Deploy Application Changes
- Simply push to `main` branch - GitHub Actions handles everything
- Deployment takes ~5-10 minutes
- Monitor in GitHub Actions tab

### Check Deployment Status
```bash
# Via AWS CLI
aws ecs describe-services \
  --cluster game-2048 \
  --services game-2048 \
  --region us-east-1

# Via CloudWatch Logs
aws logs tail /ecs/game-2048 --follow
```

### Rollback Deployment
```bash
# Find previous task definition
aws ecs list-task-definitions \
  --family-prefix game-2048 \
  --region us-east-1

# Update service to previous version
aws ecs update-service \
  --cluster game-2048 \
  --service game-2048 \
  --task-definition game-2048:X \
  --region us-east-1
```

### View Application Logs
```bash
# Real-time logs
aws logs tail /ecs/game-2048 --follow --region us-east-1

# Specific time range
aws logs tail /ecs/game-2048 \
  --since 1h \
  --format short \
  --region us-east-1
```

### Scale Service
```bash
# Update desired count
aws ecs update-service \
  --cluster game-2048 \
  --service game-2048 \
  --desired-count 5 \
  --region us-east-1
```

## Important Conventions

### Git Workflow
- **Main branch**: Production-ready code only
- **Feature branches**: Use `feature/description` naming
- **Commit messages**: Follow conventional commits (feat:, fix:, docs:, infra:)
- **Always create PR**: Don't push directly to main

### Terraform Conventions
- **State**: Stored remotely in S3 (configured in `main.tf`)
- **Variables**: Define in `variables.tf`, pass via tfvars or environment
- **Outputs**: Important values in `outputs.tf` (ALB URL, ECR repo, etc.)
- **Modules**: Keep resources logically separated by file

### Docker Conventions
- **Base images**: Use official Alpine images for smaller size
- **Tags**: Auto-tagged with git SHA and `latest`
- **Security**: Run as non-root user, minimal packages
- **Layers**: Optimize for caching and size

### AWS Naming Conventions
- **Resources**: Use consistent prefix (e.g., `game-2048-*`)
- **Tags**: Always include Environment, Project, ManagedBy tags
- **Regions**: Default to `us-east-1` unless specified

## Environment Variables & Secrets

### GitHub Secrets (Required for CI/CD)
Configure these in GitHub repository settings:
- `AWS_REGION`: AWS region (e.g., us-east-1)
- `AWS_ROLE_ARN`: IAM role ARN for OIDC authentication
- `ECR_REPO`: Full ECR repository URL

### Local Development
No secrets needed for local Docker testing.

## Troubleshooting

### Common Issues

#### 1. GitHub Actions fails at "Login to Amazon ECR"
- Check `AWS_ROLE_ARN` secret is correct
- Verify OIDC identity provider is configured in AWS IAM
- Ensure IAM role has ECR permissions

#### 2. ECS service won't start
- Check task definition health check configuration
- Verify security groups allow ALB → ECS communication
- Review CloudWatch logs for application errors
- Check container resource limits (CPU/memory)

#### 3. Can't access application via ALB
- Verify security group allows inbound traffic on port 80/443
- Check target group health checks are passing
- Ensure ECS tasks are in correct subnets
- Verify ALB listener rules are configured

#### 4. Terraform apply fails
- Check AWS credentials are valid
- Ensure S3 backend bucket exists
- Verify no manual changes conflict with Terraform state
- Run `terraform refresh` to sync state

#### 5. Docker build fails
- Check Dockerfile syntax
- Verify base image is accessible
- Ensure COPY paths are correct
- Check for sufficient disk space

### Debugging Commands

```bash
# Check ECS task status
aws ecs describe-tasks \
  --cluster game-2048 \
  --tasks $(aws ecs list-tasks --cluster game-2048 --query 'taskArns[0]' --output text) \
  --region us-east-1

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn> \
  --region us-east-1

# View CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=game-2048 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 3600 \
  --statistics Average \
  --region us-east-1
```

## Security Considerations

### Never Commit
- AWS credentials or access keys
- Terraform state files (*.tfstate)
- Private keys or certificates
- `.env` files with secrets

### Best Practices
- Use OIDC authentication (no long-lived credentials)
- Apply least-privilege IAM policies
- Enable ECR image scanning
- Use security groups to restrict network access
- Encrypt data at rest (S3, EBS, RDS)
- Enable CloudTrail for audit logging

## Cost Optimization

### Current Cost Structure (~$63/month for production)
- ECS Fargate: ~$32/month (3 tasks, 0.5 vCPU, 1GB RAM)
- Application Load Balancer: ~$16/month
- ECR Storage: ~$1/month (10GB)
- CloudWatch: ~$5/month
- Data Transfer: ~$9/month (100GB egress)

### Optimization Tips
1. **Use Fargate Spot** for 70% savings on non-critical tasks
2. **Implement auto-scaling** to scale down during off-hours
3. **Enable ECR lifecycle policies** to delete old images
4. **Right-size containers** based on actual usage metrics
5. **Use CloudFront CDN** to reduce data transfer costs

## Testing

### Local Testing
```bash
# Build and run locally
cd 2048
docker build -t 2048-game:test .
docker run -p 8080:80 2048-game:test

# Test in browser
open http://localhost:8080
```

### Integration Testing
- GitHub Actions automatically runs on PR creation
- Test deployment in staging environment (if configured)
- Verify health checks pass before promoting to production

## Documentation References

- **README.md**: Comprehensive project overview and features
- **ENTERPRISE-VALUE.md**: ROI analysis and business value
- **docs/DEPLOYMENT-GUIDE.md**: Step-by-step setup (if exists)
- **docs/TROUBLESHOOTING.md**: Detailed problem resolution (if exists)

## Working with Claude

### What Claude Can Help With
- Writing/reviewing Terraform infrastructure code
- Optimizing Dockerfile for size and security
- Debugging GitHub Actions workflow issues
- Creating/updating IAM policies
- Analyzing CloudWatch logs and metrics
- Writing automation scripts
- Documenting infrastructure changes

### What to Provide Claude
- Specific error messages (full output)
- AWS resource IDs (cluster names, ARNs)
- CloudWatch log excerpts
- Current Terraform plan output
- GitHub Actions run logs

### Example Requests
- "Help me add auto-scaling to the ECS service"
- "Review this Dockerfile for security best practices"
- "Debug why the ALB health checks are failing"
- "Create a CloudWatch dashboard for key metrics"
- "Add a staging environment to the infrastructure"

## Project Status

- **Current Stage**: Production-ready CI/CD pipeline
- **Infrastructure**: Terraform code exists but not yet in repository
- **Documentation**: Comprehensive README with enterprise value analysis
- **CI/CD**: GitHub Actions workflow configured for automated deployment
- **Application**: 2048 game (demo application)

## Next Steps / Roadmap

Potential enhancements:
1. Add automated security scanning (Trivy, Snyk)
2. Implement blue-green deployment strategy
3. Add staging environment
4. Configure custom domain with Route53
5. Implement CloudFront CDN
6. Add RDS database for persistence
7. Implement auto-scaling policies
8. Add comprehensive CloudWatch dashboards
9. Set up SNS alerts for critical events
10. Implement infrastructure testing (Terratest)

---

**Last Updated**: 2025-12-18
**Maintained By**: DevOps Team
**Project Repository**: https://github.com/nkefor/2048-cicd-enterprise
