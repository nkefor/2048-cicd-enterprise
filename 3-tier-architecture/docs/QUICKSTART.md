# Quick Start Guide - 3-Tier Architecture

Get your production-ready 3-tier application running on AWS in 30 minutes.

## Prerequisites (5 minutes)

### 1. Install Required Tools

```bash
# Terraform
brew install terraform  # macOS
# OR
wget https://releases.hashicorp.com/terraform/1.7.0/terraform_1.7.0_linux_amd64.zip

# AWS CLI
brew install awscli  # macOS
# OR
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Ansible
pip3 install ansible

# jq (for scripts)
brew install jq  # macOS or apt-get install jq
```

### 2. Configure AWS

```bash
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region: us-east-1
# Default output format: json
```

### 3. Create SSH Key Pair

```bash
# Create key in AWS
aws ec2 create-key-pair \
  --key-name my-3tier-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/my-3tier-key.pem

chmod 400 ~/.ssh/my-3tier-key.pem
```

---

## Setup (10 minutes)

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_ORG/2048-cicd-enterprise.git
cd 2048-cicd-enterprise/3-tier-architecture
```

### 2. Create S3 Bucket for Terraform State

```bash
# Create unique bucket name
BUCKET_NAME="3tier-terraform-state-$(date +%s)"

# Create bucket
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Save bucket name for later
echo "export TERRAFORM_STATE_BUCKET=$BUCKET_NAME" >> ~/.bashrc
echo $BUCKET_NAME > .bucket-name
```

### 3. Create DynamoDB Table for State Locking

```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 4. Set Environment Variables

```bash
export TERRAFORM_STATE_BUCKET=$(cat .bucket-name)
export DB_PASSWORD='YourSecurePassword123!'
export SSH_KEY_NAME='my-3tier-key'
export AWS_REGION='us-east-1'
```

---

## Deploy (10 minutes)

### Option A: Automated Deployment (Recommended)

```bash
# Full automated deployment
./scripts/deploy.sh deploy
```

This will:
1. ✅ Validate Terraform configuration
2. ✅ Initialize Terraform backend
3. ✅ Generate execution plan
4. ✅ Apply infrastructure changes
5. ✅ Configure servers with Ansible
6. ✅ Run health checks

### Option B: Manual Step-by-Step

```bash
# 1. Check prerequisites
./scripts/deploy.sh check

# 2. Plan deployment
./scripts/deploy.sh plan

# 3. Review plan and apply
./scripts/deploy.sh apply

# 4. Configure with Ansible (optional)
./scripts/deploy.sh configure
```

---

## Access Your Application (2 minutes)

### Get Application URL

```bash
cd terraform
export ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application URL: http://$ALB_DNS"
```

### Test Application

```bash
# Open in browser
open "http://$ALB_DNS"

# Or test with curl
curl "http://$ALB_DNS"
```

### Access Bastion Host

```bash
export BASTION_IP=$(terraform output -raw bastion_public_ip)
ssh -i ~/.ssh/my-3tier-key.pem ec2-user@$BASTION_IP
```

### Access Application Servers (from Bastion)

```bash
# Get private IP of app server
PRIVATE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*app*" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# SSH to app server
ssh ec2-user@$PRIVATE_IP
```

---

## Verify Deployment (3 minutes)

### Run Health Checks

```bash
./scripts/health-check.sh
```

Expected output:
```
✓ VPC is available
✓ ALB responding (HTTP 200)
✓ Healthy targets: 2/2
✓ Database status: available
✓ Multi-AZ: enabled
```

### Check CloudWatch Dashboard

```bash
# Get dashboard URL
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=$AWS_REGION#dashboards:name=3tier-app-dev"
```

### View Terraform Outputs

```bash
cd terraform
terraform output
```

---

## Common Operations

### Scale Application

```bash
cd terraform

# Scale to 4 instances
terraform apply -var="asg_desired_capacity=4"
```

### Deploy Application Update

```bash
cd ../ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/deploy-app.yml
```

### Patch Servers

```bash
# Patch in batches of 50%
ansible-playbook -i inventory/aws_ec2.yml playbooks/patch.yml \
  --extra-vars "batch_size=50%"
```

### View Logs

```bash
# Application logs
aws logs tail /aws/ec2/dev/httpd --follow

# System logs
ssh -i ~/.ssh/my-3tier-key.pem ec2-user@$BASTION_IP
sudo tail -f /var/log/messages
```

---

## Cost Estimate

### Calculate Costs

```bash
./scripts/cost-calculator.sh dev
```

Expected monthly cost:
- **Development**: ~$80-134/month
- **Production**: ~$250-300/month

### View Actual Costs

```bash
# Current month
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics UnblendedCost
```

---

## Cleanup

### Destroy Infrastructure

```bash
./scripts/deploy.sh destroy
```

This will:
1. Ask for confirmation
2. Destroy all AWS resources
3. Leave Terraform state in S3

### Delete State Storage (optional)

```bash
# Empty and delete S3 bucket
aws s3 rb s3://$TERRAFORM_STATE_BUCKET --force

# Delete DynamoDB table
aws dynamodb delete-table --table-name terraform-locks
```

---

## Troubleshooting

### Issue: Terraform Apply Fails

```bash
# Refresh state
cd terraform
terraform refresh

# Reinitialize
terraform init -reconfigure
```

### Issue: No Healthy Targets

```bash
# Check target health
cd terraform
TG_ARN=$(terraform output -raw target_group_arn)
aws elbv2 describe-target-health --target-group-arn $TG_ARN

# Check instance logs
ssh -i ~/.ssh/my-3tier-key.pem ec2-user@$BASTION_IP
# From bastion, SSH to app server and check logs
sudo tail -f /var/log/httpd/error_log
```

### Issue: Database Connection Failed

```bash
# Test from app server
DB_ENDPOINT=$(cd terraform && terraform output -raw db_endpoint)
mysql -h $DB_ENDPOINT -u admin -p

# Check security groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*db*" \
  --query 'SecurityGroups[*].[GroupId,IpPermissions]'
```

### Issue: Can't SSH to Bastion

```bash
# Check security group allows your IP
MY_IP=$(curl -s ifconfig.me)
echo "Your IP: $MY_IP"

# Update security group if needed
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*bastion*" \
  --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr $MY_IP/32
```

---

## Next Steps

### Production Deployment

1. **Create Production Environment**
   ```bash
   export ENVIRONMENT=prod
   ./scripts/deploy.sh deploy
   ```

2. **Enable Additional Features**
   - Set up custom domain with Route 53
   - Add SSL certificate with ACM
   - Enable WAF for security
   - Set up CloudFront CDN
   - Configure backup automation

3. **Security Hardening**
   - Restrict bastion access to specific IPs
   - Enable MFA for AWS console
   - Set up AWS Config for compliance
   - Enable GuardDuty for threat detection
   - Configure AWS Backup

### Multi-Environment Setup

```bash
# Development
terraform workspace new dev
terraform workspace select dev
terraform apply -var="environment=dev"

# Staging
terraform workspace new staging
terraform workspace select staging
terraform apply -var="environment=staging"

# Production
terraform workspace new prod
terraform workspace select prod
terraform apply -var="environment=prod"
```

### CI/CD Integration

GitHub Actions will automatically deploy on push to main branch.

Required GitHub Secrets:
- `AWS_ROLE_ARN`
- `TERRAFORM_STATE_BUCKET`
- `DB_PASSWORD`
- `SSH_KEY_NAME`
- `SSH_PRIVATE_KEY`

---

## Support

- **Documentation**: See `/docs` directory
- **Scripts**: See `/scripts` directory
- **Issues**: Open GitHub issue
- **AWS Support**: Check CloudWatch logs first

---

## Summary

✅ **Deployed**: Complete 3-tier architecture
✅ **Time**: ~30 minutes
✅ **Cost**: $80-134/month (dev)
✅ **Features**: Auto Scaling, Multi-AZ, Load Balancing, Monitoring

**What You Built**:
- VPC with public, private, and database subnets
- Application Load Balancer
- Auto Scaling Group (2-6 instances)
- Multi-AZ RDS MySQL database
- Bastion host for secure access
- CloudWatch monitoring and alarms

**Next**: Monitor your application, scale as needed, and deploy updates with Ansible!
