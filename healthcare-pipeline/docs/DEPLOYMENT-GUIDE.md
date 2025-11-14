# Healthcare Pipeline Deployment Guide

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Account Setup](#aws-account-setup)
3. [Initial Configuration](#initial-configuration)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Application Deployment](#application-deployment)
6. [Post-Deployment Verification](#post-deployment-verification)
7. [Monitoring Setup](#monitoring-setup)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

```bash
# Verify installations
aws --version          # AWS CLI v2.x
terraform --version    # Terraform v1.5+
docker --version       # Docker v20.x+
python3 --version      # Python 3.11+
git --version          # Git 2.x+
```

### AWS Permissions

Required AWS managed policies:
- `AdministratorAccess` (initial setup) OR
- Custom policy with permissions for:
  - EC2, VPC, S3, Lambda, ECS, IAM, KMS, CloudWatch, GuardDuty, Security Hub

### Credentials

```bash
# Configure AWS CLI
aws configure

# Verify access
aws sts get-caller-identity
```

---

## AWS Account Setup

### Step 1: Enable Required Services

```bash
# Enable GuardDuty
aws guardduty create-detector --enable --region us-east-1

# Enable Security Hub
aws securityhub enable-security-hub --region us-east-1

# Enable AWS Config
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=<config-role-arn> \
  --recording-group allSupported=true,includeGlobalResourceTypes=true

# Enable CloudTrail
aws cloudtrail create-trail \
  --name healthcare-pipeline-trail \
  --s3-bucket-name healthcare-pipeline-cloudtrail-logs
```

### Step 2: Create KMS Key for Terraform State

```bash
# Create KMS key
aws kms create-key \
  --description "Terraform state encryption key" \
  --region us-east-1

# Create alias
aws kms create-alias \
  --alias-name alias/terraform-state-key \
  --target-key-id <key-id>
```

### Step 3: Create Terraform Backend Resources

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket healthcare-pipeline-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket healthcare-pipeline-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket healthcare-pipeline-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms",
        "KMSMasterKeyID": "alias/terraform-state-key"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket healthcare-pipeline-terraform-state \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## Initial Configuration

### Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/healthcare-pipeline.git
cd healthcare-pipeline/healthcare-pipeline
```

### Step 2: Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your values
nano .env
```

Required variables:
```bash
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
ENVIRONMENT=prod
OWNER_EMAIL=devops@company.com
PROJECT_NAME=healthcare-pii-pipeline

# Optional: External integrations
DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_TOKEN=<your-token>
DATADOG_API_KEY=<your-api-key>
SPLUNK_HEC_ENDPOINT=https://splunk.company.com:8088
SPLUNK_HEC_TOKEN=<your-token>
```

### Step 3: Create Terraform Variables

```bash
# Create production tfvars
cat > terraform/environments/prod/terraform.tfvars <<EOF
project_name = "healthcare-pii-pipeline"
environment  = "prod"
owner_email  = "devops@company.com"

primary_region = "us-east-1"
dr_region      = "us-west-2"

vpc_cidr    = "10.0.0.0/16"
vpc_cidr_dr = "10.1.0.0/16"

availability_zones    = ["us-east-1a", "us-east-1b", "us-east-1c"]
availability_zones_dr = ["us-west-2a", "us-west-2b", "us-west-2c"]

# Security
enable_encryption_at_rest  = true
enable_encryption_in_transit = true
enable_mfa_delete = true

# Compliance
enable_hipaa_compliance = true
data_retention_days     = 2555  # 7 years
audit_log_retention_days = 2555

# Monitoring
enable_datadog = true
datadog_api_key = "<your-key>"  # Or use Secrets Manager

# Alerts
alert_email_addresses = [
  "oncall@company.com",
  "security@company.com"
]

EOF
```

### Step 4: Store Secrets in AWS Secrets Manager

```bash
# Databricks token
aws secretsmanager create-secret \
  --name healthcare/databricks/token \
  --secret-string '{"token":"dapi1234567890abcdef"}' \
  --region us-east-1

# Datadog API key
aws secretsmanager create-secret \
  --name healthcare/datadog/api-key \
  --secret-string '{"api_key":"dd_api_key_here"}' \
  --region us-east-1

# Splunk HEC token
aws secretsmanager create-secret \
  --name healthcare/splunk/hec-token \
  --secret-string '{"token":"splunk_hec_token_here"}' \
  --region us-east-1

# FHIR API key
aws secretsmanager create-secret \
  --name healthcare/fhir/api-key \
  --secret-string '{"api_key":"'$(openssl rand -base64 32)'"}' \
  --region us-east-1
```

---

## Infrastructure Deployment

### Step 1: Initialize Terraform

```bash
cd terraform

# Initialize
terraform init

# Validate configuration
terraform validate

# Format check
terraform fmt -check -recursive
```

### Step 2: Review Deployment Plan

```bash
# Generate plan
terraform plan \
  -var-file=environments/prod/terraform.tfvars \
  -out=tfplan

# Review plan output
# Verify all resources look correct
```

### Step 3: Deploy Infrastructure

```bash
# Apply plan
terraform apply tfplan

# This will create approximately 100+ resources:
# - VPC and networking (subnets, NAT, endpoints)
# - S3 buckets (raw, processed, quarantine, audit)
# - Lambda functions
# - ECS clusters and services
# - DynamoDB tables
# - CloudWatch alarms
# - Security services (GuardDuty, Security Hub)
# - And more...

# Deployment time: 15-20 minutes
```

### Step 4: Verify Infrastructure

```bash
# Check outputs
terraform output

# Verify VPC
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=healthcare-pii-pipeline-vpc"

# Verify S3 buckets
aws s3 ls | grep healthcare-pii-pipeline

# Verify Lambda functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `healthcare`)].FunctionName'

# Verify ECS services
aws ecs list-services --cluster healthcare-pii-pipeline-fhir-cluster
```

---

## Application Deployment

### Step 1: Build and Push Lambda Functions

```bash
cd ../lambda-functions/pii-detection

# Install dependencies
pip install -r requirements.txt -t package/

# Create deployment package
cd package && zip -r ../function.zip .
cd .. && zip -g function.zip lambda_function.py

# Upload to Lambda
aws lambda update-function-code \
  --function-name healthcare-pii-detection-prod \
  --zip-file fileb://function.zip

# Verify
aws lambda get-function --function-name healthcare-pii-detection-prod
```

### Step 2: Build and Push Docker Images

```bash
cd ../../microservices/fhir-gateway

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t fhir-gateway:latest .

# Tag image
docker tag fhir-gateway:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/healthcare-fhir-gateway:latest

# Push image
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/healthcare-fhir-gateway:latest

# Update ECS service
aws ecs update-service \
  --cluster healthcare-pii-pipeline-fhir-cluster \
  --service fhir-gateway \
  --force-new-deployment
```

---

## Post-Deployment Verification

### Step 1: Health Checks

```bash
# Check Lambda function health
aws lambda invoke \
  --function-name healthcare-pii-detection-prod \
  --payload '{"test": true}' \
  response.json

cat response.json

# Check FHIR API health
FHIR_ENDPOINT=$(terraform output -raw fhir_api_endpoint)
curl -X GET ${FHIR_ENDPOINT}/health

# Check Consent API health
CONSENT_ENDPOINT=$(terraform output -raw consent_api_endpoint)
curl -X GET ${CONSENT_ENDPOINT}/health
```

### Step 2: Test Data Processing Pipeline

```bash
# Upload sample data
aws s3 cp ../sample-data/clinical-note-sample-1.json \
  s3://$(terraform output -raw raw_data_bucket)/test/

# Monitor Lambda logs
aws logs tail /aws/lambda/healthcare-pii-detection-prod --follow

# Check processed data
aws s3 ls s3://$(terraform output -raw processed_data_bucket)/processed/ --recursive

# Check audit logs
aws dynamodb scan --table-name healthcare-audit-logs --max-items 10
```

### Step 3: Verify Security Controls

```bash
# Check GuardDuty findings
aws guardduty list-findings \
  --detector-id $(aws guardduty list-detectors --query 'DetectorIds[0]' --output text)

# Check Security Hub compliance
aws securityhub get-findings \
  --filters '{"ComplianceStatus":[{"Value":"FAILED","Comparison":"EQUALS"}]}'

# Check encryption on S3 buckets
aws s3api get-bucket-encryption \
  --bucket $(terraform output -raw raw_data_bucket)
```

---

## Monitoring Setup

### Step 1: Access Grafana

```bash
# Get Grafana URL
GRAFANA_URL=$(terraform output -raw grafana_dashboard_url)
echo "Grafana: ${GRAFANA_URL}"

# Default credentials (change immediately!)
# Username: admin
# Password: Retrieve from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id healthcare/grafana/admin-password \
  --query SecretString --output text
```

### Step 2: Configure Dashboards

1. Login to Grafana
2. Navigate to **Dashboards** > **Import**
3. Upload `monitoring/grafana/dashboard-pipeline-health.json`
4. Configure CloudWatch data source
5. Verify metrics are flowing

### Step 3: Configure Alerts

```bash
# Verify SNS topic subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw alerts_topic_arn)

# Test alert
aws sns publish \
  --topic-arn $(terraform output -raw alerts_topic_arn) \
  --subject "Test Alert" \
  --message "This is a test alert from the healthcare pipeline"
```

---

## Troubleshooting

### Common Issues

#### Issue: Terraform state lock error

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

#### Issue: Lambda function timeout

**Solution**:
```bash
# Increase timeout
aws lambda update-function-configuration \
  --function-name healthcare-pii-detection-prod \
  --timeout 900
```

#### Issue: ECS task failing health checks

**Solution**:
```bash
# Check ECS task logs
aws logs tail /ecs/healthcare-fhir-gateway --follow

# Describe task
aws ecs describe-tasks \
  --cluster healthcare-pii-pipeline-fhir-cluster \
  --tasks <task-id>
```

#### Issue: High costs

**Solution**:
```bash
# Check AWS Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Optimize:
# - Use S3 Intelligent-Tiering
# - Enable Lambda reserved concurrency
# - Use Spot instances for non-critical workloads
```

---

## Next Steps

1. **Configure Databricks**: Set up Databricks workspace and integrate with S3
2. **Enable Cross-Region DR**: Deploy to secondary region
3. **Configure Splunk**: Set up HEC endpoint and configure forwarders
4. **Run Load Tests**: Validate performance under load
5. **Security Hardening**: Review IAM policies, enable AWS WAF
6. **Compliance Audit**: Run compliance checks with Prowler or similar

---

## Support

For issues, contact:
- **DevOps Team**: devops@company.com
- **Security Team**: security@company.com
- **On-Call**: Use PagerDuty rotation

---

## Documentation

- [Architecture Overview](../README.md)
- [AWS Well-Architected Review](AWS-WELL-ARCHITECTED.md)
- [Runbooks](runbooks/)
- [Incident Response](INCIDENT-RESPONSE.md)
