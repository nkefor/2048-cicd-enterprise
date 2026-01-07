# High Availability Web Application Infrastructure

This directory contains Terraform infrastructure code to deploy a highly available web application on AWS using Application Load Balancer (ALB), EC2 instances, and Auto Scaling.

## Architecture Overview

The infrastructure implements a multi-tier, highly available architecture:

```
Internet
    |
    v
Application Load Balancer (Public Subnets)
    |
    v
Auto Scaling Group (Private Subnets)
    |
    +-- EC2 Instance (AZ1)
    +-- EC2 Instance (AZ2)
    +-- ... (scales based on demand)
```

### High Availability Features

- **Multi-AZ Deployment**: Resources deployed across 2+ availability zones
- **Auto Scaling**: Automatically scales EC2 instances based on CPU and request metrics
- **Health Checks**: ALB performs health checks and routes traffic only to healthy instances
- **NAT Gateways**: One NAT Gateway per AZ for redundancy
- **Self-Healing**: Auto Scaling replaces unhealthy instances automatically

## Infrastructure Components

### Networking (vpc.tf)
- VPC with DNS support enabled
- Public subnets for ALB (one per AZ)
- Private subnets for EC2 instances (one per AZ)
- Internet Gateway for public internet access
- NAT Gateways (one per AZ) for outbound traffic from private subnets
- Route tables for public and private subnets

### Security (security-groups.tf)
- **ALB Security Group**: Allows HTTP (80) and HTTPS (443) from internet
- **EC2 Security Group**: Allows HTTP (80) only from ALB

### Load Balancing (alb.tf)
- Application Load Balancer in public subnets
- Target Group with health check configuration
- HTTP listener (HTTPS listener commented out, ready for SSL)

### Compute (ec2.tf)
- IAM role and instance profile for EC2 instances
- Launch template with Amazon Linux 2023
- User data script to install Docker and deploy the application
- Auto Scaling Group with dynamic scaling policies
- Target tracking policies for CPU and ALB request count

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0 installed ([Download](https://www.terraform.io/downloads))
3. **AWS CLI** configured with credentials ([Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html))
4. **Required IAM Permissions**:
   - VPC, Subnet, Internet Gateway, NAT Gateway
   - EC2, Auto Scaling, Launch Template
   - Elastic Load Balancing
   - IAM (for creating roles)
   - CloudWatch (for metrics and logs)

## Quick Start

### 1. Initialize Terraform

```bash
cd infra
terraform init
```

### 2. Review Variables

Edit `terraform.tfvars` or create one:

```hcl
aws_region              = "us-east-1"
environment             = "dev"
project_name            = "2048-ha-webapp"
availability_zones_count = 2
instance_type           = "t3.micro"
min_size                = 2
max_size                = 6
desired_capacity        = 2
```

### 3. Plan Deployment

```bash
terraform plan
```

### 4. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Get Application URL

After deployment completes (5-10 minutes):

```bash
terraform output application_url
```

Visit the URL in your browser to access the 2048 game!

## Configuration

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for deployment | `us-east-1` | No |
| `environment` | Environment name | `dev` | No |
| `project_name` | Project name for resources | `2048-ha-webapp` | No |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | No |
| `availability_zones_count` | Number of AZs (min 2) | `2` | No |
| `instance_type` | EC2 instance type | `t3.micro` | No |
| `min_size` | Min instances in ASG | `2` | No |
| `max_size` | Max instances in ASG | `6` | No |
| `desired_capacity` | Desired instances in ASG | `2` | No |
| `health_check_path` | ALB health check path | `/` | No |
| `allowed_cidr_blocks` | CIDRs allowed to access app | `["0.0.0.0/0"]` | No |

### Outputs

After deployment, Terraform outputs:

- `application_url` - URL to access the application
- `alb_dns_name` - ALB DNS name
- `vpc_id` - VPC ID
- `autoscaling_group_name` - ASG name
- And more...

View all outputs:

```bash
terraform output
```

## Auto Scaling Configuration

The infrastructure includes two auto-scaling policies:

### 1. CPU-Based Scaling
- **Target**: 70% average CPU utilization
- **Behavior**: Scales out when CPU > 70%, scales in when CPU < 70%

### 2. Request Count-Based Scaling
- **Target**: 1000 requests per target
- **Behavior**: Scales based on incoming request volume

### Manual Scaling

Adjust capacity manually:

```bash
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --desired-capacity 4
```

## Monitoring

### View Auto Scaling Activity

```bash
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --max-records 10
```

### Check Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)
```

### View CloudWatch Metrics

Navigate to CloudWatch console and search for:
- Auto Scaling Group metrics
- ALB metrics
- EC2 instance metrics

## Cost Estimation

Estimated monthly costs (us-east-1, on-demand pricing):

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| EC2 Instances | 2x t3.micro | ~$15 |
| NAT Gateways | 2x NAT GW | ~$64 |
| Application Load Balancer | 1x ALB | ~$16 |
| Data Transfer | ~50 GB/month | ~$5 |
| **Total** | | **~$100** |

**Cost Optimization Tips**:
- Use t3.micro or t4g.micro for small workloads
- Consider single NAT Gateway (reduces HA but saves ~$32/month)
- Use Reserved Instances for predictable workloads (up to 72% savings)
- Enable auto-scaling to scale down during off-hours

## Security Best Practices

### Implemented
- ✅ EC2 instances in private subnets
- ✅ Security groups with least privilege
- ✅ IMDSv2 enforced on EC2 instances
- ✅ IAM roles instead of access keys
- ✅ Security headers in NGINX configuration
- ✅ Health checks enabled

### Recommended Enhancements
- [ ] Enable HTTPS with ACM certificate
- [ ] Add WAF rules to ALB
- [ ] Enable VPC Flow Logs
- [ ] Configure CloudWatch alarms
- [ ] Enable GuardDuty
- [ ] Implement secrets management (AWS Secrets Manager)

## Troubleshooting

### Deployment Fails

**Issue**: Terraform errors during apply

**Solutions**:
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify Terraform version
terraform version

# Re-initialize
terraform init -upgrade
```

### Application Not Accessible

**Issue**: Can't access application URL

**Check**:
1. Target health status (should be "healthy")
2. Security group rules
3. Auto Scaling Group has running instances

```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check ASG instances
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name)
```

### Instances Failing Health Checks

**Issue**: Instances registered but failing health checks

**Solutions**:
1. Check instance logs via Systems Manager Session Manager
2. Verify Docker container is running on port 80
3. Increase health check grace period

```bash
# Connect to instance via SSM
aws ssm start-session --target <instance-id>

# Check Docker container status
docker ps
docker logs 2048-app
```

## Cleanup

To destroy all infrastructure:

```bash
terraform destroy
```

Type `yes` when prompted.

**Note**: This will delete all resources including the VPC, ALB, and EC2 instances. Data cannot be recovered.

## Advanced Configuration

### Enable HTTPS

1. Request ACM certificate for your domain
2. Uncomment HTTPS listener in `alb.tf`
3. Add certificate ARN to listener configuration
4. Apply changes: `terraform apply`

### Add Custom Domain

1. Create Route 53 hosted zone (or use existing)
2. Add A record with alias to ALB:

```hcl
resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = "2048.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
```

### Multi-Environment Deployment

Use Terraform workspaces:

```bash
# Create workspace
terraform workspace new staging

# Deploy to staging
terraform apply

# Switch to production
terraform workspace select production
terraform apply
```

## Support

For issues or questions:
- Review [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- Check [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Review [Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)

## License

MIT License - See LICENSE file in repository root
