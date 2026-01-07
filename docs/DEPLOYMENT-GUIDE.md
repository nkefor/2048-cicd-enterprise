# High Availability Web Application - Deployment Guide

This guide walks you through deploying the 2048 web application on AWS with high availability, fault tolerance, and auto-scaling capabilities.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Steps](#deployment-steps)
4. [Verification](#verification)
5. [Scaling Operations](#scaling-operations)
6. [Monitoring](#monitoring)
7. [Troubleshooting](#troubleshooting)
8. [Cleanup](#cleanup)

## Prerequisites

### Required Tools

Install the following tools before proceeding:

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | >= 1.0 | [Download](https://www.terraform.io/downloads) |
| AWS CLI | >= 2.0 | [Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Git | Latest | [Download](https://git-scm.com/downloads) |

### AWS Account Setup

1. **Create AWS Account** (if you don't have one)
   - Visit [aws.amazon.com](https://aws.amazon.com)
   - Sign up for a free tier account

2. **Configure AWS CLI**

```bash
# Configure credentials
aws configure

# You'll be prompted for:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

3. **Verify Access**

```bash
# Test AWS credentials
aws sts get-caller-identity

# Should return your account ID, user ID, and ARN
```

### Required IAM Permissions

Your AWS user/role needs permissions for:
- EC2 (instances, security groups, launch templates)
- VPC (subnets, route tables, internet gateways, NAT gateways)
- Elastic Load Balancing (ALB, target groups, listeners)
- Auto Scaling (groups, policies)
- IAM (roles, policies, instance profiles)
- CloudWatch (metrics, alarms, logs)

**Recommended**: Use `AdministratorAccess` for testing, or create a custom policy with specific permissions for production.

## Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             v
┌─────────────────────────────────────────────────────────────────┐
│                  Application Load Balancer                        │
│                     (Public Subnets)                              │
│                   Health Check Enabled                            │
└─────────────┬───────────────────────────┬───────────────────────┘
              │                           │
    ┌─────────v──────────┐      ┌────────v──────────┐
    │   AZ-1a            │      │   AZ-1b            │
    │                    │      │                    │
    │ ┌────────────────┐ │      │ ┌────────────────┐ │
    │ │ EC2 Instance   │ │      │ │ EC2 Instance   │ │
    │ │ (Docker/NGINX) │ │      │ │ (Docker/NGINX) │ │
    │ └────────────────┘ │      │ └────────────────┘ │
    │        │           │      │        │           │
    │        v           │      │        v           │
    │ ┌────────────────┐ │      │ ┌────────────────┐ │
    │ │  NAT Gateway   │ │      │ │  NAT Gateway   │ │
    │ └────────────────┘ │      │ └────────────────┘ │
    └────────────────────┘      └────────────────────┘
         Private Subnet              Private Subnet
```

### Key Features

- **Multi-AZ Deployment**: Resources distributed across 2 availability zones
- **Auto Scaling**: Automatically adjusts instance count based on demand
- **Load Balancing**: Distributes traffic across healthy instances
- **Fault Tolerance**: Continues operating if one AZ fails
- **Self-Healing**: Replaces unhealthy instances automatically

## Deployment Steps

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/nkefor/2048-cicd-enterprise.git
cd 2048-cicd-enterprise
```

### Step 2: Review Configuration

Navigate to the infrastructure directory:

```bash
cd infra
```

Create a `terraform.tfvars` file to customize your deployment:

```bash
cat > terraform.tfvars <<EOF
# AWS Configuration
aws_region = "us-east-1"
environment = "dev"
project_name = "2048-ha-webapp"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones_count = 2

# EC2 Configuration
instance_type = "t3.micro"

# Auto Scaling Configuration
min_size = 2
max_size = 6
desired_capacity = 2

# Security Configuration
allowed_cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere (change for production)
EOF
```

### Step 3: Initialize Terraform

```bash
# Initialize Terraform (downloads AWS provider)
terraform init

# Output should show:
# Terraform has been successfully initialized!
```

### Step 4: Plan Deployment

Review the infrastructure that will be created:

```bash
terraform plan

# Review the output carefully
# Should show resources to create:
# - VPC and networking components
# - Security groups
# - Application Load Balancer
# - Launch template
# - Auto Scaling Group
# - IAM roles and policies
```

Expected resource count: **~40-50 resources**

### Step 5: Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply

# Type 'yes' when prompted
```

**Deployment Time**: Approximately 5-10 minutes

You'll see progress as Terraform creates resources. The longest steps are:
- NAT Gateways (2-3 minutes)
- Auto Scaling Group initialization (2-3 minutes)
- Instance health checks (1-2 minutes)

### Step 6: Retrieve Application URL

After deployment completes:

```bash
# Get the application URL
terraform output application_url

# Output example:
# http://2048-ha-webapp-alb-123456789.us-east-1.elb.amazonaws.com
```

## Verification

### 1. Check Application Accessibility

```bash
# Get the URL
URL=$(terraform output -raw application_url)

# Test HTTP access
curl -I $URL

# Should return HTTP 200 OK
```

Open the URL in your browser. You should see the 2048 game.

### 2. Verify Auto Scaling Group

```bash
# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize,Instances[*].HealthStatus]' \
  --output table
```

Expected output:
- Instances in "Healthy" state
- Desired capacity matches min_size (default: 2)

### 3. Verify Target Health

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

Expected output: All targets in "healthy" state

### 4. Test High Availability

Simulate an instance failure:

```bash
# Get instance IDs
INSTANCE_IDS=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

# Terminate one instance
INSTANCE_ID=$(echo $INSTANCE_IDS | awk '{print $1}')
aws ec2 terminate-instances --instance-ids $INSTANCE_ID

# Watch auto-scaling replace it
watch -n 5 "aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
  --query 'AutoScalingGroups[0].Instances[*].[InstanceId,HealthStatus,LifecycleState]' \
  --output table"
```

Within 5 minutes, Auto Scaling should launch a replacement instance.

## Scaling Operations

### Manual Scaling

Adjust the number of instances:

```bash
# Scale up to 4 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --desired-capacity 4

# Scale down to 2 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --desired-capacity 2
```

### Update Auto Scaling Limits

Edit `terraform.tfvars`:

```hcl
min_size = 2
max_size = 10
desired_capacity = 3
```

Apply changes:

```bash
terraform apply
```

### Automatic Scaling Triggers

The infrastructure includes two auto-scaling policies:

**1. CPU-Based Scaling**
- Scales out when average CPU > 70%
- Scales in when average CPU < 70%

**2. Request-Based Scaling**
- Scales out when requests per target > 1000
- Scales in when requests per target < 1000

### Load Testing

Test auto-scaling with Apache Bench:

```bash
# Install Apache Bench (if needed)
sudo apt-get install apache2-utils  # Ubuntu/Debian
# or
sudo yum install httpd-tools  # Amazon Linux/RHEL

# Generate load
URL=$(terraform output -raw application_url)
ab -n 10000 -c 100 $URL/

# Watch auto-scaling activity
watch -n 10 "aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --max-records 5"
```

## Monitoring

### CloudWatch Metrics

Key metrics to monitor:

**Auto Scaling Group**:
- `GroupDesiredCapacity`
- `GroupInServiceInstances`
- `GroupTotalInstances`

**Application Load Balancer**:
- `TargetResponseTime`
- `RequestCount`
- `HealthyHostCount`
- `UnHealthyHostCount`
- `HTTPCode_Target_2XX_Count`
- `HTTPCode_Target_4XX_Count`
- `HTTPCode_Target_5XX_Count`

**EC2 Instances**:
- `CPUUtilization`
- `NetworkIn`
- `NetworkOut`

### View Metrics in Console

1. Go to [CloudWatch Console](https://console.aws.amazon.com/cloudwatch/)
2. Click "Metrics" → "All metrics"
3. Select namespace: `AWS/ApplicationELB` or `AWS/AutoScaling`
4. Choose metrics to visualize

### Create CloudWatch Dashboard

```bash
# Create dashboard configuration
cat > dashboard.json <<'EOF'
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", {"stat": "Average"}],
          [".", "RequestCount", {"stat": "Sum"}]
        ],
        "period": 300,
        "stat": "Average",
        "region": "us-east-1",
        "title": "ALB Performance"
      }
    }
  ]
}
EOF

# Create dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "2048-HA-WebApp" \
  --dashboard-body file://dashboard.json
```

### Set Up Alarms

Example: Alert when unhealthy hosts detected

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "2048-UnhealthyHosts" \
  --alarm-description "Alert when unhealthy targets detected" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Troubleshooting

### Issue: Application Not Accessible

**Symptoms**: Cannot access the application URL

**Diagnosis**:

```bash
# 1. Check ALB exists and is active
aws elbv2 describe-load-balancers \
  --load-balancer-arns $(terraform output -raw alb_arn) \
  --query 'LoadBalancers[0].State'

# 2. Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# 3. Check security groups
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw alb_security_group_id)
```

**Solutions**:
- Verify ALB is in "active" state
- Ensure at least one target is "healthy"
- Check security group allows inbound traffic on port 80

### Issue: Instances Failing Health Checks

**Symptoms**: Instances showing as "unhealthy" in target group

**Diagnosis**:

```bash
# Connect to instance via Systems Manager
INSTANCE_ID=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
  --query 'AutoScalingGroups[0].Instances[0].InstanceId' \
  --output text)

aws ssm start-session --target $INSTANCE_ID

# Once connected, check:
docker ps  # Is container running?
docker logs 2048-app  # Any errors?
curl http://localhost  # Does it respond locally?
```

**Solutions**:
- Restart Docker container: `docker restart 2048-app`
- Check user data logs: `cat /var/log/cloud-init-output.log`
- Increase health check grace period in `ec2.tf`

### Issue: Auto Scaling Not Working

**Symptoms**: Instance count doesn't change under load

**Diagnosis**:

```bash
# Check scaling policies
aws autoscaling describe-policies \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name)

# Check scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --max-records 10
```

**Solutions**:
- Verify policies are attached to ASG
- Check CloudWatch metrics are being published
- Ensure IAM role has CloudWatch permissions

### Issue: High Costs

**Symptoms**: AWS bill higher than expected

**Diagnosis**:

```bash
# Check NAT Gateway usage (most expensive component)
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=$(terraform output -raw vpc_id)"

# Check instance count
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw autoscaling_group_name) \
  --query 'AutoScalingGroups[0].[MinSize,DesiredCapacity,MaxSize]'
```

**Solutions**:
- Reduce to 1 NAT Gateway (set `availability_zones_count = 1`)
- Use smaller instance types (`t3.nano` or `t4g.micro`)
- Reduce min_size during off-hours
- Enable auto-scaling schedule for business hours only

## Cleanup

### Option 1: Terraform Destroy

```bash
# Destroy all infrastructure
cd infra
terraform destroy

# Type 'yes' when prompted
```

**Warning**: This permanently deletes all resources. Data cannot be recovered.

### Option 2: Manual Cleanup

If Terraform destroy fails:

```bash
# 1. Delete Auto Scaling Group (forces instance termination)
aws autoscaling delete-auto-scaling-group \
  --auto-scaling-group-name $(terraform output -raw autoscaling_group_name) \
  --force-delete

# 2. Wait for instances to terminate
sleep 60

# 3. Try Terraform destroy again
terraform destroy
```

### Verify Cleanup

```bash
# Check for remaining resources
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=2048-ha-webapp"
aws elbv2 describe-load-balancers --names "2048-ha-webapp-alb"
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "2048-ha-webapp-asg"

# All commands should return empty results
```

## Next Steps

After successful deployment:

1. **Enable HTTPS**: Add ACM certificate and enable HTTPS listener
2. **Add Custom Domain**: Configure Route 53 DNS
3. **Set Up CloudWatch Alarms**: Monitor health and performance
4. **Implement CI/CD**: Integrate with GitHub Actions
5. **Add WAF**: Protect against web attacks
6. **Configure Backups**: Set up automated snapshots

## Additional Resources

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Auto Scaling Best Practices](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-best-practices.html)
- [ALB Best Practices](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues or questions, please refer to:
- [AWS Support](https://aws.amazon.com/support/)
- [Terraform Community](https://discuss.hashicorp.com/c/terraform-core/27)
- Repository Issues: [GitHub Issues](https://github.com/nkefor/2048-cicd-enterprise/issues)
