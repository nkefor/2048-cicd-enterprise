# Multi-Environment Management

This directory contains environment-specific configurations for deploying infrastructure across multiple environments (dev, staging, production).

## 📁 Directory Structure

```
environments/
├── dev/
│   ├── terraform.tfvars    # Development environment config
│   └── backend.tf           # Dev state backend configuration
├── staging/
│   ├── terraform.tfvars    # Staging environment config
│   └── backend.tf           # Staging state backend configuration
├── prod/
│   ├── terraform.tfvars    # Production environment config
│   └── backend.tf           # Production state backend configuration
└── README.md                # This file
```

## 🚀 Quick Start

### Deploy to Development
```bash
./scripts/deploy-env.sh dev apply
```

### Deploy to Staging
```bash
./scripts/deploy-env.sh staging apply
```

### Deploy to Production (requires confirmation)
```bash
./scripts/deploy-env.sh prod apply
```

## 🔄 Environment Promotion

Promote from dev to staging:
```bash
./scripts/promote-env.sh dev staging
```

Promote from staging to production:
```bash
./scripts/promote-env.sh staging prod
```

## 📊 Environment Comparison

Compare dev vs staging:
```bash
./scripts/compare-envs.sh dev staging
```

Compare staging vs prod:
```bash
./scripts/compare-envs.sh staging prod
```

## 🏗️ Environment Configurations

### Development Environment
- **Purpose**: Development and testing
- **Instances**: 1 (minimal cost)
- **Resources**: 0.25 vCPU, 0.5 GB RAM
- **Auto-shutdown**: Enabled (after hours)
- **Cost**: ~$10-15/month
- **Availability**: Single AZ acceptable
- **Monitoring**: Basic (7-day retention)

### Staging Environment
- **Purpose**: Pre-production testing and validation
- **Instances**: 2 (production-like)
- **Resources**: 0.5 vCPU, 1 GB RAM
- **Auto-shutdown**: Weekends only
- **Cost**: ~$35-45/month
- **Availability**: Multi-AZ for testing
- **Monitoring**: Standard (30-day retention)

### Production Environment
- **Purpose**: Live production workloads
- **Instances**: 3 (high availability)
- **Resources**: 0.5 vCPU, 1 GB RAM
- **Auto-shutdown**: Disabled (always on)
- **Cost**: ~$60-75/month
- **Availability**: Multi-AZ (3 zones)
- **Monitoring**: Enhanced (90-day retention)
- **Backups**: Automated daily backups
- **Security**: WAF enabled, enhanced monitoring

## 🔐 Security Best Practices

### Development
- ✅ Basic security groups
- ✅ Encryption at rest
- ✅ Private subnets
- ❌ WAF (not required)
- ❌ Enhanced monitoring (cost savings)

### Staging
- ✅ Production-like security
- ✅ Encryption at rest and in transit
- ✅ Private subnets
- ⚠️ WAF (optional)
- ✅ Enhanced monitoring

### Production
- ✅ All security features enabled
- ✅ WAF protection
- ✅ Enhanced monitoring and alerting
- ✅ Automated backups
- ✅ Multi-AZ deployment
- ✅ DDoS protection (Shield Standard)
- ✅ MFA for critical operations

## 💰 Cost Optimization

### Auto-Shutdown Schedules

**Development**:
- Shutdown: 10 PM UTC daily
- Startup: 8 AM UTC weekdays only
- **Savings**: ~40% (off nights and weekends)

**Staging**:
- Shutdown: Friday 10 PM UTC
- Startup: Monday 8 AM UTC
- **Savings**: ~30% (off weekends)

**Production**:
- Always on (no auto-shutdown)
- Consider Reserved Instances for 30-50% savings

### Monthly Cost Comparison

| Environment | Base Cost | Auto-Shutdown Savings | Final Cost |
|-------------|-----------|----------------------|------------|
| Dev | $25 | -$10 (40%) | **$15** |
| Staging | $50 | -$15 (30%) | **$35** |
| Production | $65 | $0 (always on) | **$65** |
| **Total** | **$140** | **-$25** | **$115/month** |

## 📋 Deployment Checklist

### Before Deploying to Dev
- [ ] Review terraform.tfvars
- [ ] Ensure AWS credentials are configured
- [ ] Run: `./scripts/deploy-env.sh dev plan`
- [ ] Review plan output
- [ ] Apply: `./scripts/deploy-env.sh dev apply`

### Before Promoting to Staging
- [ ] All tests pass in dev
- [ ] Application is stable in dev
- [ ] Run: `./scripts/compare-envs.sh dev staging`
- [ ] Review configuration differences
- [ ] Promote: `./scripts/promote-env.sh dev staging`
- [ ] Validate staging deployment
- [ ] Run smoke tests

### Before Promoting to Production
- [ ] All tests pass in staging
- [ ] Application stable in staging for 48+ hours
- [ ] Security review completed
- [ ] Performance testing completed
- [ ] Backup strategy verified
- [ ] Rollback plan documented
- [ ] Get stakeholder approval
- [ ] Schedule maintenance window
- [ ] Run: `./scripts/compare-envs.sh staging prod`
- [ ] Promote: `./scripts/promote-env.sh staging prod`
- [ ] Monitor production closely for 24 hours

## 🛠️ Troubleshooting

### Environment not deploying
```bash
# Check Terraform state
cd infra
terraform workspace select <env>
terraform state list

# Re-initialize
terraform init -reconfigure

# Check for drift
terraform plan -var-file="../environments/<env>/terraform.tfvars"
```

### Auto-shutdown not working
1. Verify EventBridge rules are created
2. Check Lambda function logs
3. Ensure IAM permissions are correct

### Cost higher than expected
```bash
# Compare environments to identify differences
./scripts/compare-envs.sh dev staging

# Check for orphaned resources
terraform state list
```

## 📚 Additional Resources

- [AWS ECS Pricing](https://aws.amazon.com/ecs/pricing/)
- [Terraform Workspaces](https://www.terraform.io/docs/language/state/workspaces.html)
- [AWS Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/fargate.html)

## 🤝 Contributing

When adding new environment-specific configuration:
1. Update all three environment tfvars files
2. Document changes in this README
3. Update deployment scripts if needed
4. Test in dev first, then promote to staging
5. Never deploy directly to production

---

**Last Updated**: 2025-11-12
**Maintained By**: Enterprise Platform Team
